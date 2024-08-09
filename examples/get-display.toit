// Copyright (C) 2022 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the EXAMPLES_LICENSE file.

import gpio
import spi
import color-tft show *
import pixel-display show *

                                              // MHz x    y    xoff yoff sda clock cs  dc  reset backlight invert
M5-STACK-16-BIT-LANDSCAPE-SETTINGS        ::= [  40, 320, 240, 0,   0,   23, 18,   14, 27, 33,   32,       false, COLOR-TFT-16-BIT-MODE ]
M5-STACK-24-BIT-LANDSCAPE-SETTINGS        ::= [  40, 320, 240, 0,   0,   23, 18,   14, 27, 33,   32,       false, 0]
// Note: For the M5Stack Core2 you also need the m5stack_core2 package to
// power up the display.
M5-STACK-CORE-2-16-BIT-LANDSCAPE-SETTINGS ::= [  40, 320, 240, 0,   0,   23, 18,   5,  15, null, null,     true,  COLOR-TFT-16-BIT-MODE ]
// ESP-WROVER-KIT v4.1
WROVER-16-BIT-LANDSCAPE-SETTINGS          ::= [  10, 320, 240, 0,   0,   23, 19,   22, 21, 18,   -5,       false, COLOR-TFT-16-BIT-MODE | COLOR-TFT-FLIP-XY ]
LILYGO-16-BIT-LANDSCAPE-SETTINGS          ::= [  20, 80,  160, 26,  1,   19, 18,   5 , 23, 26,   27,       true,  COLOR-TFT-16-BIT-MODE ]
// http://www.lilygo.cn/prod_view.aspx?Id=1126
LILYGO-TTGO-BIT-LANDSCAPE-SETTINGS        ::= [  20, 135, 240, 51, 40,   19, 18,   5 , 16, 23,    4,       true,  COLOR-TFT-16-BIT-MODE ]
FEATHERWING-16-BIT-SETTINGS               ::= [  20, 320, 240, 0,   0,   23, 22,   15, 33, null, null,     false, COLOR-TFT-16-BIT-MODE | COLOR-TFT-FLIP-XY ]
LILYGO-TTGO-T-16-BIT-LANDSCAPE-SETTINGS   ::= [  20, 135, 240, 51, 40,   19, 18,   5 , 16, 23,    4,       true,  COLOR-TFT-16-BIT-MODE | COLOR-TFT-REVERSE-R-B ]
LILYGO-TTGO-T-QT-PRO-SETTINGS             ::= [  20, 128, 128, 0,   0,   2,   3,   5 ,  6,  1,   15,       true,  COLOR-TFT-16-BIT-MODE ]

pin-for num/int? -> gpio.Pin?:
  if num == null: return null
  if num < 0:
    return gpio.InvertedPin (gpio.Pin -num)
  return gpio.Pin num

get-display setting/List -> PixelDisplay:
  hz            := 1_000_000 * setting[0]
  width         := setting[1]
  height        := setting[2]
  x-offset      := setting[3]
  y-offset      := setting[4]
  mosi          := pin-for setting[5]
  clock         := pin-for setting[6]
  cs            := pin-for setting[7]
  dc            := pin-for setting[8]
  reset         := pin-for setting[9]
  backlight     := pin-for setting[10]
  invert-colors := setting[11]
  flags         := setting[12]

  bus := spi.Bus
    --mosi=mosi
    --clock=clock

  device := bus.device
    --cs=cs
    --dc=dc
    --frequency=hz

  driver := ColorTft device width height
    --reset=reset
    --backlight=backlight
    --x-offset=x-offset
    --y-offset=y-offset
    --flags=flags
    --invert-colors=invert-colors

  tft := PixelDisplay.true-color driver

  return tft
