package nl.edsoft.klaverjas.ui

import androidx.compose.ui.graphics.Color
import nl.edsoft.klaverjas.kaarten.OrigineleKaarten

/** De kleuren van het speelscherm; dezelfde als op de iPhone. */
object Kleuren {
    val achtergrond = Color(18, 73, 46)
    val veld = Color(0x66, 0xCE, 0x33)
    val veldRand = Color(58, 122, 30)
    val geel = Color(250, 230, 160)
    val paneel = Color(12, 54, 34)
    val kaartWit = Color.White

    /** De kleur waarin dit symbool op de kaart getekend is (klaver zwart, schoppen donkergrijs, ruiten rood, harten lichtrood). */
    fun kaartKleur(kleur: Int): Color = Color(OrigineleKaarten.symboolKleurVoor(kleur))
}
