package nl.edsoft.klaverjas.ble

import android.util.Log

/** Eén plek voor de bluetooth-logregels: `adb logcat -s KlaverjasBLE`. */
object BleLog {
    private const val TAG = "KlaverjasBLE"
    fun zeg(tekst: String) { Log.d(TAG, tekst) }
}
