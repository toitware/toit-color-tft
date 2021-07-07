// Copyright (C) 2018 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

// Driver for the 18 bit TFT color displays. Intended to drive the ILI9341,
// ILI9488, ST7789V and ST7735 modules in 4-wire SPI mode.  Initially tested
// with the 240x320 ST7789V as seen on the ESP-WROVER-KIT v3.
// The 320x240 TFT on the M5Stack is an ILI9341 (or 9342 according to some docs).
// The display on the LillyGo T-Wristband is an ST7735.

// ESP-WROVER_KIT v3 has the following pins:
// SDA:  23  (aka mosi)
// MISO: 25
// SCK:  19  (clock)
// CS:   22  (chip select)
// DC:   21  (command/data)
// TCS:   0  (touch screen chip select)
// RST:  18  (reset)
// BKLIT: 5  (backlight, active low)
// MADCTL: 0x40

// M5Stack:
// SDA:   23  (aka mosi)
// SCK:   18  (clock)
// CS:    14  (chip select)
// DC:    27  (command/data)
// RST    33  (reset)
// LIGHT: 32  (backlight)
// MADCTL: 0x00

// Lilygo T-Wristband (LSM9DS1 version):
// MOSI aka SDA: IO 19
// SCLK aka SCK: IO 18
// CS:           IO 05
// DC:           IO 23
// RST:          IO 26
// BL aka BKLIT: IO 27

// Lilygo T-Wristband (non-LSM9DS1 version):
// MISO:         P013
// MOSI aka SDA: P014
// SCLK aka SCK: P012
// CS:           P02
// DC:           P03
// RST:          P04
// BL aka BKLIT: P07

import binary
import font show *
import bitmap show *
import true_color show *
import pixel_display show *
import gpio
import peripherals.rpc show *
import ..display_driver show *

COLOR_TFT_FLIP_X ::= 0x40   // Flip across the X axis.
COLOR_TFT_FLIP_Y ::= 0x80   // Flip across the Y axis.
COLOR_TFT_FLIP_XY ::= 0x20  // Reverse the X and Y axes.
COLOR_TFT_MADCTL_MASK_ ::= 0xe0

// If you pick this then the r and b channels are reduced from 6 bits to 5
// bits, and the display is updated faster.
COLOR_TFT_16_BIT_MODE ::= 1


COLOR_TFT_NOP_ ::= 0x00        // No operation
COLOR_TFT_SWRESET_ ::= 0x01    // Software reset
COLOR_TFT_RDDID_ ::= 0x04      // Read display ID
COLOR_TFT_RDDST_ ::= 0x09      // Read display status
COLOR_TFT_RDDPM_ ::= 0x0a      // Read display power
COLOR_TFT_RDDMADCTL_ ::= 0x0b  // Read display
COLOR_TFT_RDDCOLMOD_ ::= 0x0c  // Read display pixel
COLOR_TFT_RDDIM_ ::= 0x0d      // Read display image
COLOR_TFT_RDDSM_ ::= 0x0e      // Read display signal
COLOR_TFT_RDDSDR_ ::= 0x0f     // Read display self-diagnostic result
COLOR_TFT_SLPIN_ ::= 0x10      // Sleep in
COLOR_TFT_SLPOUT_ ::= 0x11     // Sleep out
COLOR_TFT_PTLON_ ::= 0x12      // Partial mode on
COLOR_TFT_NORON_ ::= 0x13      // Partial off
COLOR_TFT_INVOFF_ ::= 0x20     // Display inversion off
COLOR_TFT_INVON_ ::= 0x21      // Display inversion on
COLOR_TFT_GAMSET_ ::= 0x26     //
COLOR_TFT_DISPOFF_ ::= 0x28    // Display off
COLOR_TFT_DISPON_ ::= 0x29     // Display on
COLOR_TFT_CASET_ ::= 0x2a      // Column address set
COLOR_TFT_RASET_ ::= 0x2b      // Row address set
COLOR_TFT_RAMWR_ ::= 0x2c      // Memory write
COLOR_TFT_RAMRD_ ::= 0x2e      // Memory read
COLOR_TFT_PTLAR_ ::= 0x30      // Partial start/end address set
COLOR_TFT_VSCRDEF_ ::= 0x33    // Vertical scrolling definition
COLOR_TFT_TEOFF_ ::= 0x34      // Tearing effect line off
COLOR_TFT_TEON_ ::= 0x35       // Tearing effect line on
COLOR_TFT_MADCTL_ ::= 0x36     // Memory data access control
COLOR_TFT_VSCRSADD_ ::= 0x37   // Vertical scrolling start address
COLOR_TFT_IDMOFF_ ::= 0x38     // Idle mode off
COLOR_TFT_IDMON_ ::= 0x39      // Idle mode on
COLOR_TFT_COLMOD_ ::= 0x3a     // Interface pixel format
COLOR_TFT_RAMWRC_ ::= 0x3c     // Memory write continue
COLOR_TFT_RAMRDC_ ::= 0x3e     // Memory read continue
COLOR_TFT_TESCAN_ ::= 0x44     // Set tear scanlines
COLOR_TFT_RDTESCAN_ ::= 0x45   // Get scanline
COLOR_TFT_WRDISBV_ ::= 0x51    // Write display brightness
COLOR_TFT_RDDISBV_ ::= 0x52    // Read display brightness
COLOR_TFT_WRCTRLD_ ::= 0x53    // Write CTRL display
COLOR_TFT_RDCTRLD_ ::= 0x54    // Read CTRL value display
COLOR_TFT_WRCACE_ ::= 0x55     // Write content adaptive brightness control and color enhancement
COLOR_TFT_RDCABC_ ::= 0x56     // Read content adaptive brightness control
COLOR_TFT_WRCABCMB_ ::= 0x5e   // Write CABC minimum brightness
COLOR_TFT_RDCABCMB_ ::= 0x5f   // Read CABC minimum brightness
COLOR_TFT_RDCABCSDR_ ::= 0x68  // Read automatic brightness control self-diagnostic result
COLOR_TFT_RDID1_ ::= 0xda      // Read ID1
COLOR_TFT_RDID2_ ::= 0xdb      // Read ID2
COLOR_TFT_RDID3_ ::= 0xdc      // Read ID3

COLOR_TFT_12_PIXEL_MODE_ ::= 3
COLOR_TFT_16_PIXEL_MODE_ ::= 5
COLOR_TFT_18_PIXEL_MODE_ ::= 6
COLOR_TFT_TRUNCATED_24_PIXEL_MODE_ ::= 7

class ColorTFT extends DisplayDriver:
  flags ::= RPC_DISPLAY_FLAG_TRUE_COLOR | RPC_DISPLAY_FLAG_PARTIAL_UPDATES
  width/int := ?
  height/int := ?
  x_offset_/int := ?
  y_offset_/int := ?

  // Pin numbers.
  device_ := ?
  reset_/gpio.Pin := ?         // Active low reset line.
  backlight_/gpio.Pin? := ?
  // Config byte.
  madctl_/int := ?
  sixteen_bit_mode_/bool := ?
  invert_colors_/bool := ?

  cmd_buffer_/ByteArray ::= ByteArray 1
  buffer_/ByteArray ::= ?

  constructor .device_ .width .height --reset/gpio.Pin --backlight/gpio.Pin?=null --x_offset/int=0 --y_offset/int=0 --invert_colors/bool=false --flags/int=0:
    x_offset_ = x_offset
    y_offset_ = y_offset
    invert_colors_ = invert_colors
    backlight_ = backlight
    reset_ = reset
    madctl_ = flags
    buffer_ = ByteArray 640

    sixteen_bit_mode_ = (flags & COLOR_TFT_16_BIT_MODE) != 0

    reset_.config --output
    if backlight_: backlight_.config --output

    reset_.set 0
    sleep --ms=10
    reset_.set 1

    // I see occasional glitches if this is less than 18.
    sleep --ms=18

    send COLOR_TFT_SWRESET_
    // According to documentation, a software reset takes 5ms.
    sleep --ms=5

    backlight_on

    send COLOR_TFT_SLPOUT_

    send COLOR_TFT_DISPON_

    send COLOR_TFT_IDMOFF_

    send COLOR_TFT_WRDISBV_ 0xff

    send COLOR_TFT_WRCTRLD_ 4

    if sixteen_bit_mode_:
      send COLOR_TFT_COLMOD_ COLOR_TFT_16_PIXEL_MODE_
    else:
      send COLOR_TFT_COLMOD_ COLOR_TFT_18_PIXEL_MODE_

    send COLOR_TFT_MADCTL_ (flags & COLOR_TFT_MADCTL_MASK_)

  backlight_on:
    if backlight_:
      backlight_.set 1

  backlight_off:
    if backlight_:
      backlight_.set 0

  set_range_ command from to:
    to--  // to is inclusive.
    send_ 0 command
    binary.BIG_ENDIAN.put_uint16 buffer_ 0 from
    binary.BIG_ENDIAN.put_uint16 buffer_ 2 to
    send_array command buffer_ --to=4

  send command:
    cmd_buffer_[0] = command
    device_.transfer cmd_buffer_ --dc=0

  send command data:
    buffer_[0] = data
    send_array command buffer_ --to=1

  send command data data2:
    buffer_[0] = data
    buffer_[1] = data2
    send_array command buffer_ --to=2

  send_array command array --to=array.size:
    cmd_buffer_[0] = command
    device_.transfer cmd_buffer_ --dc=0
    device_.transfer array --dc=1 --to=to

  send_ cd byte:
    cmd_buffer_[0] = byte
    device_.transfer cmd_buffer_ --dc=cd

  draw_true_color left/int top/int right/int bottom/int red/ByteArray green/ByteArray blue/ByteArray -> none:
    canvas_width := right - left
    canvas_height := bottom - top
    set_range_ COLOR_TFT_CASET_ left+x_offset_ right+x_offset_
    set_range_ COLOR_TFT_RASET_ top+y_offset_ bottom+y_offset_
    send COLOR_TFT_RAMWR_  // Reset write pointer to caset and raset positions.

    if sixteen_bit_mode_:
      // Using the mode where you pack 3 pixels in two bytes.  5 bits for red,
      // 6 for green, 5 for blue (the eye is more sensitive to green).  Since
      // we receive the data in three one-byte-per-pixel buffers we have to
      // shuffle the bytes.  Some duplication to keep the performance-critical
      // inner loop as simple as possible.
      idx := 0
      canvas_height.repeat: | y |
        if invert_colors_:
          canvas_width.repeat: | x |
            r := 0xff - red[idx]
            g := 0xff - green[idx]
            b := 0xff - blue[idx]
            buffer_[x * 2] = (b & 0xf8) | ((g & 0xe0) >> 5)
            buffer_[x * 2 + 1] = (r >> 3) | (g << 5)
            idx++
        else:
          canvas_width.repeat: | x |
            buffer_[x * 2] = (blue[idx] & 0xf8) | ((green[idx] & 0xe0) >> 5)
            buffer_[x * 2 + 1] = (red[idx] >> 3) | (green[idx] << 5)
            idx++
        device_.transfer buffer_ --dc=1 --to=canvas_width * 2
    else:
      // Using the mode where you pack 3 pixels in three bytes.  6 bits per
      // channel with 6 wasted bits per pixel.  Since we receive the data in
      // three one-byte-per-pixel buffers we have to shuffle the bytes.  Some
      // duplication to keep the performance-critical inner loop as simple as
      // possible.
      canvas_height.repeat: | y |
        idx := y * canvas_width
        i := 0
        if invert_colors_:
          canvas_width.repeat:
            j := idx + it
            buffer_[i++] = 0xff - blue[j]
            buffer_[i++] = 0xff - green[j]
            buffer_[i++] = 0xff - red[j]
        else:
          canvas_width.repeat:
            j := idx + it
            buffer_[i++] = blue[j]
            buffer_[i++] = green[j]
            buffer_[i++] = red[j]
        device_.transfer buffer_ --dc=1 --to=canvas_width*3
    send COLOR_TFT_NOP_

  refresh left top right bottom:
