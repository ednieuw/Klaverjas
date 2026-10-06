package nl.edsoft.klaverjas.ui

import android.graphics.Bitmap
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import nl.edsoft.klaverjas.Teken
import nl.edsoft.klaverjas.kaarten.Afbeelding
import nl.edsoft.klaverjas.kaarten.Kaartenset
import nl.edsoft.klaverjas.kaarten.OrigineleKaarten

/**
 * De kaarten als ImageBitmap op één vergroting, eenmaal opgebouwd. De kaarten zijn per
 * pixel getekend en worden alleen op hele veelvouden vergroot en met Scale2x/Scale3x
 * gladgestreken; wat hier uitkomt gaat 1 op 1 naar het scherm.
 */
class Kaartbeelden(val schaal: Int) {
    private val beelden: List<ImageBitmap> = Kaartenset(schaal).alle.map { zetOm(it) }

    fun voor(naam: Teken, kleur: Int): ImageBitmap? {
        val rang = OrigineleKaarten.RANG_ROEM.indexOf(naam)
        if (rang < 0 || kleur !in 0..3) return null
        return beelden[kleur * 8 + rang]
    }

    val achterkant: ImageBitmap get() = beelden[32]

    private fun zetOm(a: Afbeelding): ImageBitmap =
        Bitmap.createBitmap(a.pixels, a.breedte, a.hoogte, Bitmap.Config.ARGB_8888).asImageBitmap()
}
