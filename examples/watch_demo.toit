// Copyright (C) 2021 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the EXAMPLES_LICENSE file.

import color_tft show *
import font show *
import font_x11_adobe.sans_14_bold as sans_14
import gpio
import pixel_display show *
import pixel_display.texture show TEXT_TEXTURE_ALIGN_RIGHT TEXT_TEXTURE_ALIGN_CENTER
import pixel_display.true_color show BLACK WHITE get_rgb
// Roboto is a package installed with
// toit pkg install toit-font-google-100dpi-roboto
// If this import fails you need to run `toit pkg fetch` in this directory.
import roboto.bold_36 as roboto_36_bold
import spi
import ntp
import esp32
import .get_display

DAYS ::= ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
MONTHS ::= ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

// Write the time and date.
// The time is hh:mm followed by the seconds in a smaller font.
// In order to avoid burn-in, the display changes position randomly about
// once every 10 seconds.  The date is written either above or below the
// time, depending on where there is space.
main:
  set_time_from_net
  tft := get_display LILYGO_TTGO_T_16_BIT_LANDSCAPE_SETTINGS
  tft.background = BLACK
  sans := Font [sans_14.ASCII]
  sans_big := Font [roboto_36_bold.ASCII]
  sans_big_context := tft.context --alignment=TEXT_TEXTURE_ALIGN_RIGHT --landscape --color=(get_rgb 50 255 50) --font=sans_big
  sans_context := tft.context --landscape --color=(get_rgb 230 230 50) --font=sans
  date_context := sans_context.with --alignment=TEXT_TEXTURE_ALIGN_CENTER

  extent := sans_big.text_extent "00 00"
  tft_width := max tft.width_ tft.height_
  tft_height := min tft.width_ tft.height_
  MIN_X ::= extent[0] + 1
  MAX_X ::= tft_width - (sans.pixel_width "00")
  MIN_Y ::= extent[1]
  MAX_Y ::= tft_height

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
      x = max MIN_X (min MAX_X x)
      y = max MIN_Y (min MAX_Y y)
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

set_time_from_net:
  set_timezone "CET-1CEST,M3.5.0,M10.5.0/3"  // Daylight savings rules in the EU as of 2022.
  now := Time.now.utc
  if now.year < 1981:
    result ::= ntp.synchronize
    if result:
      esp32.adjust_real_time_clock result.adjustment
      print "Set time to $Time.now by adjusting $result.adjustment"
    else:
      print "ntp: synchronization request failed"
