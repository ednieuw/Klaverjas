pluginManagement {
    repositories {
        google {
            content {
                includeGroupByRegex("com\\.android.*")
                includeGroupByRegex("com\\.google.*")
                includeGroupByRegex("androidx.*")
            }
        }
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "Klaverjas"

// core: plain Kotlin/JVM, no Android dependencies - the engine ported from the
// Swift package KlaverjasKit, unit-testable without an emulator or phone.
// app:  the Android app (Compose UI; the BLE layer comes at M4).
include(":core", ":app")
