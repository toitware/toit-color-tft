// Copyright (C) 2022 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the EXAMPLES_LICENSE file.

import gpio
import spi
import color_tft show *
import pixel_display show *

                                              // MHz x    y    xoff yoff sda clock cs  dc  reset backlight invert
M5_STACK_16_BIT_LANDSCAPE_SETTINGS        ::= [  40, 320, 240, 0,   0,   23, 18,   14, 27, 33,   32,       false, COLOR_TFT_16_BIT_MODE ]
M5_STACK_24_BIT_LANDSCAPE_SETTINGS        ::= [  40, 320, 240, 0,   0,   23, 18,   14, 27, 33,   32,       false, 0]
// Note: For the M5Stack Core2 you also need the m5stack_core2 package to
// power up the display.
M5_STACK_CORE_2_16_BIT_LANDSCAPE_SETTINGS ::= [  40, 320, 240, 0,   0,   23, 18,   5,  15, null, null,     true,  COLOR_TFT_16_BIT_MODE ]
// ESP-WROVER-KIT v4.1
WROVER_16_BIT_LANDSCAPE_SETTINGS          ::= [  10, 320, 240, 0,   0,   23, 19,   22, 21, 18,   -5,       false, COLOR_TFT_16_BIT_MODE | COLOR_TFT_FLIP_XY ]
LILYGO_16_BIT_LANDSCAPE_SETTINGS          ::= [  20, 80,  160, 26,  1,   19, 18,   5 , 23, 26,   27,       true,  COLOR_TFT_16_BIT_MODE ]
// http://www.lilygo.cn/prod_view.aspx?Id=1126
LILYGO_TTGO_BIT_LANDSCAPE_SETTINGS        ::= [  20, 135, 240, 51, 40,   19, 18,   5 , 16, 23,    4,       true,  COLOR_TFT_16_BIT_MODE ]
FEATHERWING_16_BIT_SETTINGS               ::= [  20, 320, 240, 0,   0,   23, 22,   15, 33, null, null,     false, COLOR_TFT_16_BIT_MODE | COLOR_TFT_FLIP_XY ]
LILYGO_TTGO_T_16_BIT_LANDSCAPE_SETTINGS   ::= [  20, 135, 240, 51, 40,   19, 18,   5 , 16, 23,    4,       true,  COLOR_TFT_16_BIT_MODE | COLOR_TFT_REVERSE_R_B ]

pin_for num/int? -> gpio.Pin?:
  if num == null: return null
  if num < 0:
    return gpio.InvertedPin (gpio.Pin -num)
  return gpio.Pin num

get_display setting/List -> TrueColorPixelDisplay:

  hz            := 1_000_000 * setting[0]
  width         := setting[1]
  height        := setting[2]
  x_offset      := setting[3]
  y_offset      := setting[4]
  mosi          := pin_for setting[5]
  clock         := pin_for setting[6]
  cs            := pin_for setting[7]
  dc            := pin_for setting[8]
  reset         := pin_for setting[9]
  backlight     := pin_for setting[10]
  invert_colors := setting[11]
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
    --x_offset=x_offset
    --y_offset=y_offset
    --flags=flags
    --invert_colors=invert_colors

  tft := TrueColorPixelDisplay driver

  return tft

