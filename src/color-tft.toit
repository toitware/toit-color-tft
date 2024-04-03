// Copyright (C) 2021 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

/**
Driver for 18 bit TFT color displays.
Intended to drive the ILI9341, ILI9488, ST7789V and ST7735 modules in 4-wire
  SPI mode.  Initially tested with the 240x320 ST7789V as seen on the
  ESP-WROVER-KIT v3.
The 320x240 TFT on the M5Stack is an ILI9341 (or 9342 according to some docs).
The display on the LillyGo T-Wristband is an ST7735.
*/

import font show *
import bitmap show *
import pixel-display.true-color show *
import pixel-display show *
import gpio
import io

COLOR-TFT-FLIP-X ::= 0x40   // Flip across the X axis.
COLOR-TFT-FLIP-Y ::= 0x80   // Flip across the Y axis.
COLOR-TFT-FLIP-XY ::= 0x20  // Reverse the X and Y axes.
COLOR-TFT-REVERSE-R-B ::= 0x08  // Reverse the red and blue channels.
COLOR-TFT-MADCTL-MASK_ ::= 0xe8

// If you pick this then the r and b channels are reduced from 6 bits to 5
// bits, and the display is updated faster.
COLOR-TFT-16-BIT-MODE ::= 1


COLOR-TFT-NOP_ ::= 0x00        // No operation
COLOR-TFT-SWRESET_ ::= 0x01    // Software reset
COLOR-TFT-RDDID_ ::= 0x04      // Read display ID
COLOR-TFT-RDDST_ ::= 0x09      // Read display status
COLOR-TFT-RDDPM_ ::= 0x0a      // Read display power
COLOR-TFT-RDDMADCTL_ ::= 0x0b  // Read display
COLOR-TFT-RDDCOLMOD_ ::= 0x0c  // Read display pixel
COLOR-TFT-RDDIM_ ::= 0x0d      // Read display image
COLOR-TFT-RDDSM_ ::= 0x0e      // Read display signal
COLOR-TFT-RDDSDR_ ::= 0x0f     // Read display self-diagnostic result
COLOR-TFT-SLPIN_ ::= 0x10      // Sleep in
COLOR-TFT-SLPOUT_ ::= 0x11     // Sleep out
COLOR-TFT-PTLON_ ::= 0x12      // Partial mode on
COLOR-TFT-NORON_ ::= 0x13      // Partial off
COLOR-TFT-INVOFF_ ::= 0x20     // Display inversion off
COLOR-TFT-INVON_ ::= 0x21      // Display inversion on
COLOR-TFT-GAMSET_ ::= 0x26     //
COLOR-TFT-DISPOFF_ ::= 0x28    // Display off
COLOR-TFT-DISPON_ ::= 0x29     // Display on
COLOR-TFT-CASET_ ::= 0x2a      // Column address set
COLOR-TFT-RASET_ ::= 0x2b      // Row address set
COLOR-TFT-RAMWR_ ::= 0x2c      // Memory write
COLOR-TFT-RAMRD_ ::= 0x2e      // Memory read
COLOR-TFT-PTLAR_ ::= 0x30      // Partial start/end address set
COLOR-TFT-VSCRDEF_ ::= 0x33    // Vertical scrolling definition
COLOR-TFT-TEOFF_ ::= 0x34      // Tearing effect line off
COLOR-TFT-TEON_ ::= 0x35       // Tearing effect line on
COLOR-TFT-MADCTL_ ::= 0x36     // Memory data access control
COLOR-TFT-VSCRSADD_ ::= 0x37   // Vertical scrolling start address
COLOR-TFT-IDMOFF_ ::= 0x38     // Idle mode off
COLOR-TFT-IDMON_ ::= 0x39      // Idle mode on
COLOR-TFT-COLMOD_ ::= 0x3a     // Interface pixel format
COLOR-TFT-RAMWRC_ ::= 0x3c     // Memory write continue
COLOR-TFT-RAMRDC_ ::= 0x3e     // Memory read continue
COLOR-TFT-TESCAN_ ::= 0x44     // Set tear scanlines
COLOR-TFT-RDTESCAN_ ::= 0x45   // Get scanline
COLOR-TFT-WRDISBV_ ::= 0x51    // Write display brightness
COLOR-TFT-RDDISBV_ ::= 0x52    // Read display brightness
COLOR-TFT-WRCTRLD_ ::= 0x53    // Write CTRL display
COLOR-TFT-RDCTRLD_ ::= 0x54    // Read CTRL value display
COLOR-TFT-WRCACE_ ::= 0x55     // Write content adaptive brightness control and color enhancement
COLOR-TFT-RDCABC_ ::= 0x56     // Read content adaptive brightness control
COLOR-TFT-WRCABCMB_ ::= 0x5e   // Write CABC minimum brightness
COLOR-TFT-RDCABCMB_ ::= 0x5f   // Read CABC minimum brightness
COLOR-TFT-RDCABCSDR_ ::= 0x68  // Read automatic brightness control self-diagnostic result
COLOR-TFT-RDID1_ ::= 0xda      // Read ID1
COLOR-TFT-RDID2_ ::= 0xdb      // Read ID2
COLOR-TFT-RDID3_ ::= 0xdc      // Read ID3

COLOR-TFT-12-PIXEL-MODE_ ::= 3
COLOR-TFT-16-PIXEL-MODE_ ::= 5
COLOR-TFT-18-PIXEL-MODE_ ::= 6
COLOR-TFT-TRUNCATED-24-PIXEL-MODE_ ::= 7

/**
TrueColor Driver intended to be used with the Pixel-Display package
  at https://pkg.toit.io/package/pixel_display&url=github.com%2Ftoitware%2Ftoit-pixel-display&index=latest
See https://docs.toit.io/language/sdk/display

ESP-WROVER_KIT v3 has the following pins:
SDA:  23  (aka mosi)
MISO: 25
SCK:  19  (clock)
CS:   22  (chip select)
DC:   21  (command/data)
TCS:   0  (touch screen chip select)
RST:  18  (reset)
BKLIT: 5  (backlight, active low)
MADCTL: 0x40

M5Stack:
SDA:   23  (aka mosi)
SCK:   18  (clock)
CS:    14  (chip select)
DC:    27  (command/data)
RST    33  (reset)
LIGHT: 32  (backlight)
MADCTL: 0x00

Lilygo T-Wristband (LSM9DS1 version):
MOSI IO 19 (aka SDA)
SCLK IO 18 (aka SCK)
CS:  IO 05
DC:  IO 23
RST: IO 26
BL:  IO 27 (aka BKLIT)

Lilygo T-Wristband (non-LSM9DS1 version):
MISO: P013
MOSI: P014 (aka SDA)
SCLK: P012 (aka SCK)
CS:   P02
DC:   P03
RST:  P04
BL:   P07  (aka BKLIT)
*/
class ColorTft extends AbstractDriver:
  flags ::= FLAG-TRUE-COLOR | FLAG-PARTIAL-UPDATES
  width/int := ?
  height/int := ?
  x-offset_/int := ?
  y-offset_/int := ?

  x-rounding: return 1
  y-rounding: return 1

  // Pin numbers.
  device_ := ?
  reset_/gpio.Pin? := ?         // Active low reset line.
  backlight_/gpio.Pin? := ?
  // Config byte.
  madctl_/int := ?
  sixteen-bit-mode_/bool := ?
  invert-colors_/bool := ?

  cmd-buffer_/ByteArray ::= ByteArray 1
  buffer_/ByteArray ::= ?

  constructor .device_ .width .height --reset/gpio.Pin? --backlight/gpio.Pin?=null --x-offset/int=0 --y-offset/int=0 --invert-colors/bool=false --flags/int=0:
    x-offset_ = x-offset
    y-offset_ = y-offset
    invert-colors_ = invert-colors
    backlight_ = backlight
    reset_ = reset
    madctl_ = flags
    buffer_ = ByteArray 4096

    sixteen-bit-mode_ = (flags & COLOR-TFT-16-BIT-MODE) != 0

    if backlight_: backlight_.configure --output
    if reset_:
      reset_.configure --output
      reset_.set 0
    sleep --ms=10
    if reset_:
      reset_.set 1

    // I see occasional glitches if this is less than 18.
    sleep --ms=18

    send COLOR-TFT-SWRESET_
    // According to documentation, a software reset takes 5ms.
    sleep --ms=5

    backlight-on

    send COLOR-TFT-SLPOUT_

    send COLOR-TFT-DISPON_

    send COLOR-TFT-IDMOFF_

    send COLOR-TFT-WRDISBV_ 0xff

    send COLOR-TFT-WRCTRLD_ 4

    if sixteen-bit-mode_:
      send COLOR-TFT-COLMOD_ COLOR-TFT-16-PIXEL-MODE_
    else:
      send COLOR-TFT-COLMOD_ COLOR-TFT-18-PIXEL-MODE_

    send COLOR-TFT-MADCTL_ (flags & COLOR-TFT-MADCTL-MASK_)

  backlight-on:
    if backlight_:
      backlight_.set 1

  backlight-off:
    if backlight_:
      backlight_.set 0

  set-range_ command from to:
    to--  // to is inclusive.
    send_ 0 command
    io.BIG-ENDIAN.put-uint16 buffer_ 0 from
    io.BIG-ENDIAN.put-uint16 buffer_ 2 to
    send-array command buffer_ --to=4

  send command:
    cmd-buffer_[0] = command
    device_.transfer cmd-buffer_ --dc=0

  send command data:
    buffer_[0] = data
    send-array command buffer_ --to=1

  send command data data2:
    buffer_[0] = data
    buffer_[1] = data2
    send-array command buffer_ --to=2

  send-array command array --to=array.size:
    cmd-buffer_[0] = command
    device_.transfer cmd-buffer_ --dc=0
    device_.transfer array --dc=1 --to=to

  send_ cd byte:
    cmd-buffer_[0] = byte
    device_.transfer cmd-buffer_ --dc=cd

  static INVERT := ByteArray 0x100: 0xff - it

  draw-true-color left/int top/int right/int bottom/int red/ByteArray green/ByteArray blue/ByteArray -> none:
    patch-width := right - left
    patch-height := bottom - top
    set-range_ COLOR-TFT-CASET_ left+x-offset_ right+x-offset_
    set-range_ COLOR-TFT-RASET_ top+y-offset_ bottom+y-offset_
    send COLOR-TFT-RAMWR_  // Reset write pointer to caset and raset positions.

    table := invert-colors_ ? INVERT : null

    if sixteen-bit-mode_:
      // Using the mode where you pack 3 pixels in two bytes.  5 bits for red,
      // 6 for green, 5 for blue (the eye is more sensitive to green).  Since
      // we receive the data in three one-byte-per-pixel buffers we have to
      // shuffle the bytes.
      lines-per-chunk := buffer_.size / (patch-width * 2)
      if lines-per-chunk == 0: throw "Buffer too small for screen size"

      List.chunk-up 0 bottom - top lines-per-chunk: | from to height |
        blit blue[from * patch-width..]  buffer_      patch-width --destination-pixel-stride=2 --lookup-table=table --mask=0xf8
        blit green[from * patch-width..] buffer_      patch-width --destination-pixel-stride=2 --lookup-table=table --shift=5 --mask=0x7 --operation=OR
        blit green[from * patch-width..] buffer_[1..] patch-width --destination-pixel-stride=2 --lookup-table=table --shift=-3 --mask=0xe0
        blit red[from * patch-width..]   buffer_[1..] patch-width --destination-pixel-stride=2 --lookup-table=table --shift=3 --mask=0x1f
        device_.transfer buffer_ --dc=1 --to=patch-width * 2 * height
    else:
      // Using the mode where you pack 3 pixels in three bytes.  6 bits per
      // channel with 6 wasted bits per pixel.  Since we receive the data in
      // three one-byte-per-pixel buffers we have to shuffle the bytes.
      lines-per-chunk := buffer_.size / (patch-width * 3)
      if lines-per-chunk == 0: throw "Buffer too small for screen size"

      List.chunk-up 0 bottom - top lines-per-chunk: | from to height |
        blit blue[from * patch-width..]  buffer_      patch-width --destination-pixel-stride=3 --lookup-table=table
        blit green[from * patch-width..] buffer_[1..] patch-width --destination-pixel-stride=3 --lookup-table=table
        blit red[from * patch-width..]   buffer_[2..] patch-width --destination-pixel-stride=3 --lookup-table=table
        device_.transfer buffer_ --dc=1 --to=patch-width * 3 * height
    send COLOR-TFT-NOP_

  refresh left top right bottom:
