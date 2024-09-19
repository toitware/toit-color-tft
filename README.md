# Color TFT
Driver for the 18 bit TFT color displays.

Intended to drive the ILI9341, ILI9488, ST7789V, ST7735, and GC9107 modules
in 4-wire SPI mode.  Initially tested
with the 240x320 ST7789V as seen on the ESP-WROVER-KIT v3.

The 320x240 TFT on the M5Stack is an ILI9341 (or 9342 according to some docs).

The display on the LilyGo T-Wristband is an ST7735. The one on the T-QT Pro is
a GC9107.

See the [get-display.toit](examples/get-display.toit) example file for
configurations of some common devices.
