package com.example.skeleton.screenshots

import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onRoot
import com.example.skeleton.MainActivity
import com.github.takahirom.roborazzi.captureRoboImage
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(qualifiers = "w411dp-h891dp-xxhdpi")
class MainScreenshotTest {
    @get:Rule
    val composeRule = createAndroidComposeRule<MainActivity>()

    @Test
    fun mainLight() = composeRule.onRoot().captureRoboImage("src/test/screenshots/main_light.png")

    @Test
    @Config(qualifiers = "w411dp-h891dp-night-xxhdpi")
    fun mainDark() = composeRule.onRoot().captureRoboImage("src/test/screenshots/main_dark.png")
}
