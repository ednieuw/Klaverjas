package nl.edsoft.klaverjas.ble

import android.annotation.SuppressLint
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.BluetoothStatusCodes
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.os.Build
import android.os.ParcelUuid
import kotlinx.coroutines.channels.BufferOverflow
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withTimeoutOrNull
import nl.edsoft.klaverjas.DuoBericht
import nl.edsoft.klaverjas.DuoRadio
import nl.edsoft.klaverjas.DuoStatus
import nl.edsoft.klaverjas.RegelBuffer
import nl.edsoft.klaverjas.RegelPakketten

/**
 * De kant die zoekt (de gast): scant naar [UartDienst.dienst], verbindt met de eerste die hij vindt,
 * zoekt de twee karakteristieken op en zet notificaties aan. Schrijft naar `naarPerifeer`, luistert op
 * `naarCentraal`. Komt overeen met `BleCentraal` in de Swift-app.
 */
@SuppressLint("MissingPermission")
class BleCentraal(context: Context) : DuoRadio {
    private val context = context.applicationContext
    private val manager = this.context.getSystemService(BluetoothManager::class.java)

    private var gatt: BluetoothGatt? = null
    private var schrijfKarakteristiek: BluetoothGattCharacteristic? = null
    @Volatile private var gevonden = false
    @Volatile private var verbonden = false
    @Volatile private var gestopt = false
    @Volatile private var maxPakket = 20

    private val leesBuffer = RegelBuffer()
    private val inkomend = Channel<DuoBericht>(Channel.UNLIMITED)
    private val zendKlaar = Channel<Boolean>(Channel.CONFLATED)
    private val zendSlot = Mutex()
    private val status = MutableSharedFlow<DuoStatus>(replay = 1, extraBufferCapacity = 16, onBufferOverflow = BufferOverflow.DROP_OLDEST)

    override fun statusStroom(): Flow<DuoStatus> = status

    private fun meld(s: DuoStatus) { status.tryEmit(s) }

    override suspend fun start() {
        if (gevonden || gatt != null) return
        BleLog.zeg("BleCentraal: start()")
        meld(DuoStatus.Bezig("Zoeken…"))
        val adapter = manager?.adapter
        if (adapter == null || !adapter.isEnabled) { meld(DuoStatus.Mislukt("Bluetooth staat uit")); return }
        val scanner = adapter.bluetoothLeScanner
        if (scanner == null) { meld(DuoStatus.Mislukt("Bluetooth niet beschikbaar")); return }
        try {
            val filter = ScanFilter.Builder().setServiceUuid(ParcelUuid(UartDienst.dienst)).build()
            val instellingen = ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY).build()
            scanner.startScan(listOf(filter), instellingen, scanCallback)
        } catch (e: SecurityException) {
            meld(DuoStatus.Mislukt("geen toestemming voor Bluetooth"))
        }
    }

    override suspend fun stop() {
        gestopt = true
        try {
            manager?.adapter?.bluetoothLeScanner?.stopScan(scanCallback)
            gatt?.disconnect()
            gatt?.close()
        } catch (_: Exception) {}
        gatt = null; schrijfKarakteristiek = null; verbonden = false
    }

    /** Elke schrijfactie wacht op [BluetoothGattCallback.onCharacteristicWrite] voordat de volgende mag. */
    override suspend fun stuur(bericht: DuoBericht) = zendSlot.withLock {
        val g = gatt; val ch = schrijfKarakteristiek
        if (g == null || ch == null || !verbonden) {
            BleLog.zeg("kon niet versturen (geen verbinding): ${bericht.regel.take(40)}")
            return@withLock
        }
        for (pakket in RegelPakketten.verdeel(bericht.regel, maxPakket)) {
            zendKlaar.tryReceive()
            var verstuurd = false
            for (poging in 0 until 100) {
                if (try { schrijf(g, ch, pakket) } catch (e: RuntimeException) { BleLog.zeg("versturen mislukte: $e"); false }) {
                    verstuurd = withTimeoutOrNull(5000) { zendKlaar.receive() } ?: false
                    break
                }
                delay(20)
            }
            if (!verstuurd) {
                BleLog.zeg("verzenden opgegeven: ${bericht.regel.take(40)}")
                return@withLock
            }
        }
        BleLog.zeg("verstuurd: ${bericht.regel.take(60)}")
    }

    @Suppress("DEPRECATION")
    private fun schrijf(g: BluetoothGatt, ch: BluetoothGattCharacteristic, data: ByteArray): Boolean =
        if (Build.VERSION.SDK_INT >= 33) {
            g.writeCharacteristic(ch, data, BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE) == BluetoothStatusCodes.SUCCESS
        } else {
            ch.writeType = BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
            ch.value = data
            g.writeCharacteristic(ch)
        }

    override suspend fun ontvang(): DuoBericht = inkomend.receive()

    // ------------------------------------------------------------- callbacks (op een binder-thread)

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            // De eerste die gevonden wordt, telt: er wordt met precies twee toestellen gespeeld.
            if (gevonden || gestopt) return
            gevonden = true
            BleLog.zeg("gevonden: ${result.device.address}, verbinden…")
            meld(DuoStatus.Bezig("Gevonden, verbinden…"))
            try {
                manager?.adapter?.bluetoothLeScanner?.stopScan(this)
                gatt = result.device.connectGatt(context, false, gattCallback, BluetoothDevice.TRANSPORT_LE)
            } catch (e: SecurityException) {
                meld(DuoStatus.Mislukt("geen toestemming voor Bluetooth"))
            }
        }

        override fun onScanFailed(errorCode: Int) {
            BleLog.zeg("scannen mislukt: $errorCode")
            meld(DuoStatus.Mislukt("scannen mislukt ($errorCode)"))
        }
    }

    private val gattCallback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(g: BluetoothGatt, s: Int, nieuweStaat: Int) {
            BleLog.zeg("verbinding: staat $nieuweStaat (status $s)")
            if (nieuweStaat == BluetoothProfile.STATE_CONNECTED) {
                // Een grotere MTU maakt de pakketten groter en de stand sneller; daarna pas de diensten opzoeken.
                if (!g.requestMtu(185)) g.discoverServices()
            } else if (nieuweStaat == BluetoothProfile.STATE_DISCONNECTED && !gestopt) {
                verbonden = false
                schrijfKarakteristiek = null
                try { g.close() } catch (_: Exception) {}
                meld(DuoStatus.Mislukt(if (s == BluetoothGatt.GATT_SUCCESS) "verbinding verloren" else "verbinden mislukt ($s)"))
            }
        }

        override fun onMtuChanged(g: BluetoothGatt, mtu: Int, s: Int) {
            BleLog.zeg("MTU $mtu (status $s)")
            if (s == BluetoothGatt.GATT_SUCCESS) maxPakket = (mtu - 3).coerceIn(20, 512)
            g.discoverServices()
        }

        override fun onServicesDiscovered(g: BluetoothGatt, s: Int) {
            val dienst = g.getService(UartDienst.dienst)
            val schrijf = dienst?.getCharacteristic(UartDienst.naarPerifeer)
            val meldt = dienst?.getCharacteristic(UartDienst.naarCentraal)
            if (s != BluetoothGatt.GATT_SUCCESS || schrijf == null || meldt == null) {
                BleLog.zeg("dienst of karakteristieken niet gevonden (status $s)")
                meld(DuoStatus.Mislukt("de andere kant spreekt een andere dienst"))
                return
            }
            schrijfKarakteristiek = schrijf
            g.setCharacteristicNotification(meldt, true)
            val cccd = meldt.getDescriptor(UartDienst.cccd)
            if (cccd == null) { meld(DuoStatus.Mislukt("notificaties niet te zetten")); return }
            @Suppress("DEPRECATION")
            if (Build.VERSION.SDK_INT >= 33) {
                g.writeDescriptor(cccd, BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE)
            } else {
                cccd.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                g.writeDescriptor(cccd)
            }
        }

        override fun onDescriptorWrite(g: BluetoothGatt, d: BluetoothGattDescriptor, s: Int) {
            if (d.uuid != UartDienst.cccd) return
            if (s == BluetoothGatt.GATT_SUCCESS) {
                BleLog.zeg("notificaties aan, verbonden (pakketgrootte $maxPakket)")
                verbonden = true
                meld(DuoStatus.Verbonden)
            } else {
                meld(DuoStatus.Mislukt("notificaties aanzetten mislukt ($s)"))
            }
        }

        override fun onCharacteristicWrite(g: BluetoothGatt, c: BluetoothGattCharacteristic, s: Int) {
            zendKlaar.trySend(s == BluetoothGatt.GATT_SUCCESS)
        }

        override fun onCharacteristicChanged(g: BluetoothGatt, c: BluetoothGattCharacteristic, value: ByteArray) {
            ontvangenNotificatie(c, value)
        }

        @Deprecated("Voor Android 12 en ouder")
        override fun onCharacteristicChanged(g: BluetoothGatt, c: BluetoothGattCharacteristic) {
            @Suppress("DEPRECATION")
            val v = c.value ?: return
            ontvangenNotificatie(c, v)
        }
    }

    private fun ontvangenNotificatie(c: BluetoothGattCharacteristic, data: ByteArray) {
        if (c.uuid != UartDienst.naarCentraal) return
        val regels = synchronized(leesBuffer) { leesBuffer.neem(data) }
        for (regel in regels) {
            val bericht = DuoBericht.uitRegel(regel)
            if (bericht == null) { BleLog.zeg("onherkenbare regel binnengekregen: \"${regel.take(40)}\""); continue }
            BleLog.zeg("ontvangen: ${bericht.regel.take(60)}")
            inkomend.trySend(bericht)
        }
    }
}
