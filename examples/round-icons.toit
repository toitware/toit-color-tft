// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

import bitmap show *
import font show Font
import gpio
import icons show Icon
import spi

import pictogrammers-icons.size-40 show *
import pixel-display show *
import pixel-display.element show *
import pixel-display.gradient show *
import pixel-display.style show *

import .get-display

main args:
  display := get-display M5-STACK-24-BIT-LANDSCAPE-SETTINGS

  background-gradient := GradientBackground --angle=150
      --specifiers=[
          GradientSpecifier --color=0xc0ffdd 10,
          GradientSpecifier --color=0xc0ddff 90,
      ]

  background-gradient-element := Div --x=0 --y=0 --w=320 --h=240 --background=0x123456
  display.add background-gradient-element

  i := 0
  buttons := []
  [KANGAROO, DOG, CAT, FISH].do: | icon/Icon |
    button := Div.clipping --id="outer-$i" --classes=["button-outer"] --x=(8 + i * 74) [
        Div.clipping --id="inner-$i" --classes=["button-inner"] [
            Label --icon=icon
        ]
    ]
    i++
    buttons.add button
    display.add button

  rounded-35 := RoundedCornerBorder --radius=35
  rounded-30 := RoundedCornerBorder --radius=30
  outer-background := GradientBackground --angle=150
      --specifiers=[
          GradientSpecifier --color=0xe0e0e0 0,
          GradientSpecifier --color=0xe0e0e0 45,
          GradientSpecifier --color=0xb0b0b0 55,
          GradientSpecifier --color=0xb0b0b0 100,
      ]
  inner-background-off := 0x202020
  inner-background-on := 0x602020

  // Also includes the initial style parameters.
  off-style := Style
      --type-map={
          "label": Style --x=30 --y=47 --color=0xc0c0c0 {"alignment": ALIGN-CENTER},
      }
      --class-map={
          "button-outer": Style --y=20 --w=70 --h=70      --border=rounded-35 --background=outer-background,
          "button-inner": Style --y=5 --x=5 --w=60 --h=60 --border=rounded-30 --background=inner-background-off,
      }

  // Only includes those things that are different in the on state.
  on-style := Style
      --type-map={ "label": Style --color=0xff4040 }
      --class-map={ "button-inner": Style --background=inner-background-on, }

  display.set-styles [off-style]

  display.draw

  sleep --ms=500

  while true:
    4.repeat: | on |
      4.repeat: | i |
        if i == on:
          buttons[i].set-styles [on-style]
        else:
          buttons[i].set-styles [off-style]
      display.draw
      sleep --ms=1000
