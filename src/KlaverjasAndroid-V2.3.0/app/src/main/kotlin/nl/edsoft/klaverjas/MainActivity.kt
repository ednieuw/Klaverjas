package nl.edsoft.klaverjas

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.lifecycle.viewmodel.compose.viewModel
import nl.edsoft.klaverjas.ui.SpelModel
import nl.edsoft.klaverjas.ui.SpelScherm

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            val model: SpelModel = viewModel()
            SpelScherm(model)
        }
    }
}
