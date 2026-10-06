package nl.edsoft.klaverjas.ble

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat

/**
 * Welke runtime-rechten bluetooth nodig heeft. Vanaf Android 12 zijn dat BLUETOOTH_SCAN (zoeken),
 * BLUETOOTH_ADVERTISE (openstellen) en BLUETOOTH_CONNECT (allebei). Op Android 11 en ouder is voor
 * zoeken het locatierecht nodig; openstellen vraagt niets.
 */
object BleRechten {
    fun nodig(alsGastheer: Boolean): Array<String> =
        if (Build.VERSION.SDK_INT >= 31) {
            if (alsGastheer) arrayOf(Manifest.permission.BLUETOOTH_ADVERTISE, Manifest.permission.BLUETOOTH_CONNECT)
            else arrayOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT)
        } else {
            if (alsGastheer) emptyArray() else arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
        }

    fun ontbrekend(context: Context, alsGastheer: Boolean): Array<String> =
        nodig(alsGastheer).filter {
            ContextCompat.checkSelfPermission(context, it) != PackageManager.PERMISSION_GRANTED
        }.toTypedArray()
}
