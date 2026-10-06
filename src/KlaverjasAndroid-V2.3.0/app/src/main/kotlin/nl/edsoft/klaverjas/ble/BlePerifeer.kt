package nl.edsoft.klaverjas.ble

import android.annotation.SuppressLint
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothGattServer
import android.bluetooth.BluetoothGattServerCallback
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.BluetoothStatusCodes
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
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
 * De kant die zich openstelt (de gastheer): adverteert [UartDienst.dienst] en wacht tot de andere
 * kant verbindt en notificaties aanzet. Ontvangt via een schrijfactie op `naarPerifeer`, verstuurt
 * via een notificatie op `naarCentraal`. Komt overeen met `BlePerifeer` in de Swift-app.
 *
 * De rechten (BLUETOOTH_ADVERTISE en BLUETOOTH_CONNECT vanaf Android 12) moeten al verleend zijn;
 * zie [BleRechten]. Een ontbrekend recht komt als `Mislukt` terug, niet als crash.
 */
@SuppressLint("MissingPermission")
class BlePerifeer(context: Context) : DuoRadio {
    private val context = context.applicationContext
    private val manager = this.context.getSystemService(BluetoothManager::class.java)

    private var server: BluetoothGattServer? = null
    private var adverteerder: BluetoothLeAdvertiser? = null
    private var naarCentraal: BluetoothGattCharacteristic? = null
    @Volatile private var abonnee: BluetoothDevice? = null
    @Volatile private var gestopt = false

    /** Hoeveel bytes er in één notificatie passen: MTU min drie; tot de MTU bekend is de veilige 20. */
    @Volatile private var maxPakket = 20

    private val leesBuffer = RegelBuffer()
    private val inkomend = Channel<DuoBericht>(Channel.UNLIMITED)
    private val zendKlaar = Channel<Unit>(Channel.CONFLATED)
    private val zendSlot = Mutex()
    private val status = MutableSharedFlow<DuoStatus>(replay = 1, extraBufferCapacity = 16, onBufferOverflow = BufferOverflow.DROP_OLDEST)

    override fun statusStroom(): Flow<DuoStatus> = status

    private fun meld(s: DuoStatus) { status.tryEmit(s) }

    override suspend fun start() {
        if (server != null) return
        BleLog.zeg("BlePerifeer: start()")
        meld(DuoStatus.Bezig("Openstellen…"))
        val adapter = manager?.adapter
        if (adapter == null || !adapter.isEnabled) { meld(DuoStatus.Mislukt("Bluetooth staat uit")); return }
        try {
            val srv = manager.openGattServer(context, serverCallback)
            if (srv == null) { meld(DuoStatus.Mislukt("Bluetooth niet beschikbaar")); return }
            server = srv

            val schrijf = BluetoothGattCharacteristic(
                UartDienst.naarPerifeer,
                BluetoothGattCharacteristic.PROPERTY_WRITE or BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE,
                BluetoothGattCharacteristic.PERMISSION_WRITE)
            val meldt = BluetoothGattCharacteristic(
                UartDienst.naarCentraal, BluetoothGattCharacteristic.PROPERTY_NOTIFY, 0)
            meldt.addDescriptor(BluetoothGattDescriptor(
                UartDienst.cccd, BluetoothGattDescriptor.PERMISSION_READ or BluetoothGattDescriptor.PERMISSION_WRITE))
            naarCentraal = meldt

            val dienst = BluetoothGattService(UartDienst.dienst, BluetoothGattService.SERVICE_TYPE_PRIMARY)
            dienst.addCharacteristic(schrijf)
            dienst.addCharacteristic(meldt)
            // Adverteren begint pas als de dienst er echt is: onServiceAdded.
            if (!srv.addService(dienst)) meld(DuoStatus.Mislukt("dienst toevoegen mislukt"))
        } catch (e: SecurityException) {
            meld(DuoStatus.Mislukt("geen toestemming voor Bluetooth"))
        }
    }

    override suspend fun stop() {
        gestopt = true
        try {
            adverteerder?.stopAdvertising(adverteerCallback)
            server?.close()
        } catch (_: Exception) {}
        adverteerder = null; server = null; naarCentraal = null; abonnee = null
    }

    /**
     * Een notificatie wacht op [BluetoothGattServerCallback.onNotificationSent] voordat de volgende mag;
     * zonder die wacht gaat de tweede stilzwijgend verloren. Na een paar seconden zonder bevestiging geven
     * we op in plaats van de hele speelloop te laten hangen.
     */
    override suspend fun stuur(bericht: DuoBericht) = zendSlot.withLock {
        val srv = server; val dev = abonnee; val ch = naarCentraal
        if (srv == null || dev == null || ch == null) {
            BleLog.zeg("kon niet versturen (geen verbinding): ${bericht.regel.take(40)}")
            return@withLock
        }
        for (pakket in RegelPakketten.verdeel(bericht.regel, maxPakket)) {
            zendKlaar.tryReceive()
            var verstuurd = false
            for (poging in 0 until 100) {
                if (try { notificeer(srv, dev, ch, pakket) } catch (e: RuntimeException) { BleLog.zeg("versturen mislukte: $e"); false }) {
                    verstuurd = withTimeoutOrNull(5000) { zendKlaar.receive(); true } ?: false
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
    private fun notificeer(srv: BluetoothGattServer, dev: BluetoothDevice, ch: BluetoothGattCharacteristic, data: ByteArray): Boolean =
        if (Build.VERSION.SDK_INT >= 33) {
            srv.notifyCharacteristicChanged(dev, ch, false, data) == BluetoothStatusCodes.SUCCESS
        } else {
            ch.value = data
            srv.notifyCharacteristicChanged(dev, ch, false)
        }

    override suspend fun ontvang(): DuoBericht = inkomend.receive()

    // ------------------------------------------------------------- callbacks (op een binder-thread)

    private val adverteerCallback = object : AdvertiseCallback() {
        override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) { BleLog.zeg("adverteren gestart") }
        override fun onStartFailure(errorCode: Int) {
            BleLog.zeg("adverteren mislukt: $errorCode")
            meld(DuoStatus.Mislukt("adverteren mislukt ($errorCode)"))
        }
    }

    private fun beginAdverteren() {
        val adapter = manager?.adapter ?: return
        val adv = adapter.bluetoothLeAdvertiser
        if (adv == null) { meld(DuoStatus.Mislukt("deze telefoon kan niet adverteren")); return }
        adverteerder = adv
        val instellingen = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
            .setConnectable(true)
            .build()
        val data = AdvertiseData.Builder()
            .setIncludeDeviceName(false)
            .addServiceUuid(ParcelUuid(UartDienst.dienst))
            .build()
        try { adv.startAdvertising(instellingen, data, adverteerCallback) }
        catch (e: SecurityException) { meld(DuoStatus.Mislukt("geen toestemming voor Bluetooth")) }
    }

    private fun ontvangenSchrijven(data: ByteArray) {
        val regels = synchronized(leesBuffer) { leesBuffer.neem(data) }
        for (regel in regels) {
            val bericht = DuoBericht.uitRegel(regel)
            if (bericht == null) { BleLog.zeg("onherkenbare regel binnengekregen: \"${regel.take(40)}\""); continue }
            BleLog.zeg("ontvangen: ${bericht.regel.take(60)}")
            inkomend.trySend(bericht)
        }
    }

    private val serverCallback = object : BluetoothGattServerCallback() {
        override fun onServiceAdded(s: Int, service: BluetoothGattService?) {
            if (s == BluetoothGatt.GATT_SUCCESS) { BleLog.zeg("dienst toegevoegd"); beginAdverteren() }
            else meld(DuoStatus.Mislukt("dienst toevoegen mislukt ($s)"))
        }

        override fun onConnectionStateChange(device: BluetoothDevice, s: Int, nieuweStaat: Int) {
            BleLog.zeg("verbinding ${device.address}: staat $nieuweStaat (status $s)")
            if (nieuweStaat == BluetoothProfile.STATE_DISCONNECTED && device == abonnee) abonneeVerloren()
            // Eén partner is genoeg; de rest van de omgeving hoeft de dienst niet meer te zien.
            if (nieuweStaat == BluetoothProfile.STATE_CONNECTED) {
                try { adverteerder?.stopAdvertising(adverteerCallback) } catch (_: Exception) {}
            }
        }

        override fun onMtuChanged(device: BluetoothDevice, mtu: Int) {
            BleLog.zeg("MTU $mtu")
            maxPakket = (mtu - 3).coerceIn(20, 512)
        }

        override fun onDescriptorWriteRequest(
            device: BluetoothDevice, requestId: Int, descriptor: BluetoothGattDescriptor, preparedWrite: Boolean,
            responseNeeded: Boolean, offset: Int, value: ByteArray?,
        ) {
            if (responseNeeded) {
                try { server?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, value) } catch (_: Exception) {}
            }
            if (descriptor.uuid != UartDienst.cccd || value == null) return
            if (value.contentEquals(BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE)) {
                BleLog.zeg("de andere kant zette notificaties aan (pakketgrootte $maxPakket)")
                abonnee = device
                meld(DuoStatus.Verbonden)
            } else if (device == abonnee) {
                abonneeVerloren()
            }
        }

        override fun onCharacteristicWriteRequest(
            device: BluetoothDevice, requestId: Int, characteristic: BluetoothGattCharacteristic, preparedWrite: Boolean,
            responseNeeded: Boolean, offset: Int, value: ByteArray?,
        ) {
            if (responseNeeded) {
                try { server?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, value) } catch (_: Exception) {}
            }
            if (characteristic.uuid == UartDienst.naarPerifeer && value != null) ontvangenSchrijven(value)
        }

        override fun onNotificationSent(device: BluetoothDevice, s: Int) { zendKlaar.trySend(Unit) }
    }

    private fun abonneeVerloren() {
        if (gestopt) return
        BleLog.zeg("de andere kant liet de verbinding los")
        abonnee = null
        meld(DuoStatus.Mislukt("verbinding verloren"))
    }
}
