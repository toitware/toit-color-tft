// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

// Tests for Label that the change box is smaller when we only
// change part of the text.

import font show *
import pixel-display show *
import pixel-display.element show *
import pixel-display.slider show *
import pixel-display.gradient show *
import pixel-display.style show *
import gpio
import spi
import .get-display

main args:
  display := get-display M5-STACK-24-BIT-LANDSCAPE-SETTINGS
  display.background = 0x808080
  WIDTH ::= display.width
  HEIGHT ::= display.height

  heat := GradientBackground --angle=0 --specifiers=[
      GradientSpecifier --color=0xc0c000 0,
      GradientSpecifier --color=0xff8000 100,
      ]

  cold := GradientBackground --angle=90 --specifiers=[
      GradientSpecifier --color=0xa0a0a0 0,
      GradientSpecifier --color=0x404040 10,
      GradientSpecifier --color=0x404040 90,
      GradientSpecifier --color=0xa0a0a0 100,
      ]

  sans10 := Font.get "sans10"

  style := Style
      --type-map={
          "slider": Style --w=20 --h=100 {
              "background-hi": heat,
              "background-lo": cold,
          },
          "label": Style --font=sans10 --color=0xffffff,
      }

  sliders := List 5:
      Slider --x=(30 + 40 * it) --y=50 --value=(10 + it * 20)
  labels := List 5:
      Label --x=(40 + 40 * it) --y=165 --text="$(%c 'A' + it)" --alignment=ALIGN-CENTER

  content := Div --x=0 --y=0 --w=WIDTH --h=HEIGHT --background=0x202020 (sliders + labels)

  display.add content

  content.set-styles [style]

  //Profiler.install false
  //Profiler.start
  start := Time.monotonic-us
  display.draw
  end := Time.monotonic-us
  print "Draw in $((end - start) / 1000)ms"
  //Profiler.stop
  //Profiler.report "slider"

  start = Time.monotonic-us
  500.repeat:
    slider := random 5
    sliders[slider].value = random 100

    display.draw
  end = Time.monotonic-us
  print "500 in $((end - start) / 1000)ms"
