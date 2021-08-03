// Copyright (C) 2021 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the EXAMPLES_LICENSE file.

import color_tft show *
import font show *
import font.x11_100dpi.sans.sans_14_bold as sans_14
import gpio
import pixel_display show *
import pixel_display.texture show TEXT_TEXTURE_ALIGN_RIGHT TEXT_TEXTURE_ALIGN_CENTER
import pixel_display.true_color show BLACK WHITE get_rgb
// Roboto is a package installed with
// toit pkg install toit-font-google-100dpi-roboto
// If this import fails you need to run `toit pkg fetch` in this directory.
import roboto.bold_36 as roboto_36_bold
import spi

DAYS ::= ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
MONTHS ::= ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

// Write the time and date.
// The time is hh:mm followed by the seconds in a smaller font.
// In order to avoid burn-in, the display changes position randomly about
// once every 10 seconds.  The date is written either above or below the
// time, depending on where there is space.
main:
  tft := get_display
  tft.background = BLACK
  sans := Font [sans_14.ASCII]
  sans_big := Font [roboto_36_bold.ASCII]
  sans_big_context := tft.context --alignment=TEXT_TEXTURE_ALIGN_RIGHT --landscape --color=(get_rgb 50 255 50) --font=sans_big
  sans_context := tft.context --landscape --color=(get_rgb 230 230 50) --font=sans
  date_context := sans_context.with --alignment=TEXT_TEXTURE_ALIGN_CENTER

  x := 110
  y := 60
  // Although sans is not a fixed width font, the digits are all the same
  // width, so we can use zeros to measure the correct position of the blinking
  // colon.
  colon_offset := (sans_big.pixel_width "00")
  DATE_OFFSET := 33
  ABOVE := 33
  BELOW := 20

  date := tft.text date_context x - DATE_OFFSET y - ABOVE ""
  time := tft.text sans_big_context x y ""
  colon := tft.text sans_big_context x - colon_offset y ""
  seconds := tft.text sans_context x y ""
  blink := true
  while true:
    // About once every 10 seconds we move the display to avoid burn-in.
    if (random 10) < 1:
      x += (random 3) - 1
      y += (random 3) - 1
      x = max 90 (min 130 x)
      y = max 32 (min 80 y)
      time.move_to x y
      seconds.move_to x y
      colon.move_to x - colon_offset y
      if y < 60:
        date.move_to x - DATE_OFFSET y + BELOW
      else:
        date.move_to x - DATE_OFFSET y - ABOVE
    local := Time.now.local
    date.text = "$(DAYS[local.weekday % 7]) $(MONTHS[local.month - 1]) $(local.day)"
    time.text = "$(%02d local.h) $(%02d local.m)"
    colon.text = blink ? ":" : ""
    blink = not blink
    seconds.text = "$(%02d local.s)"
    tft.draw
    sleep --ms=1000

get_display -> TrueColorPixelDisplay:
                                         // MHz x    y    xoff yoff sda clock cs  dc  reset backlight invert
  M5_STACK_16_BIT_LANDSCAPE_SETTINGS ::= [  40, 320, 240, 0,   0,   23, 18,   14, 27, 33,   32,       false, COLOR_TFT_16_BIT_MODE ]
  WROVER_16_BIT_LANDSCAPE_SETTINGS   ::= [  40, 320, 240, 0,   0,   23, 19,   22, 21, 18,   -5,       false, COLOR_TFT_16_BIT_MODE | COLOR_TFT_FLIP_XY ]
  LILYGO_16_BIT_LANDSCAPE_SETTINGS   ::= [  20, 80,  160, 26,  1,   19, 18,   5 , 23, 26,   27,       true,  COLOR_TFT_16_BIT_MODE ]

  // Pick one of the above.
  s := LILYGO_16_BIT_LANDSCAPE_SETTINGS

  hz            := 1_000_000 * s[0]
  width         := s[1]
  height        := s[2]
  x_offset      := s[3]
  y_offset      := s[4]
  mosi          := gpio.Pin s[5]
  clock         := gpio.Pin s[6]
  cs            := gpio.Pin s[7]
  dc            := gpio.Pin s[8]
  reset         := gpio.Pin s[9]
  backlight     := s[10] >= 0 ? gpio.Pin s[10] : null
  invert_colors := s[11]
  flags         := s[12]

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
