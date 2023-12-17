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

import binary
import font show *
import bitmap show *
import pixel_display.true_color show *
import pixel_display show *
import gpio

COLOR_TFT_FLIP_X ::= 0x40   // Flip across the X axis.
COLOR_TFT_FLIP_Y ::= 0x80   // Flip across the Y axis.
COLOR_TFT_FLIP_XY ::= 0x20  // Reverse the X and Y axes.
COLOR_TFT_REVERSE_R_B ::= 0x08  // Reverse the red and blue channels.
COLOR_TFT_MADCTL_MASK_ ::= 0xe8

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
  flags ::= FLAG_TRUE_COLOR | FLAG_PARTIAL_UPDATES
  width/int := ?
  height/int := ?
  x_offset_/int := ?
  y_offset_/int := ?

  x_rounding: return 1
  y_rounding: return 1

  // Pin numbers.
  device_ := ?
  reset_/gpio.Pin? := ?         // Active low reset line.
  backlight_/gpio.Pin? := ?
  // Config byte.
  madctl_/int := ?
  sixteen_bit_mode_/bool := ?
  invert_colors_/bool := ?

  cmd_buffer_/ByteArray ::= ByteArray 1
  buffer_/ByteArray ::= ?

  constructor .device_ .width .height --reset/gpio.Pin? --backlight/gpio.Pin?=null --x_offset/int=0 --y_offset/int=0 --invert_colors/bool=false --flags/int=0:
    x_offset_ = x_offset
    y_offset_ = y_offset
    invert_colors_ = invert_colors
    backlight_ = backlight
    reset_ = reset
    madctl_ = flags
    buffer_ = ByteArray 4096

    sixteen_bit_mode_ = (flags & COLOR_TFT_16_BIT_MODE) != 0

    if backlight_: backlight_.configure --output
    if reset_:
      reset_.configure --output
      reset_.set 0
    sleep --ms=10
    if reset_:
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

  static INVERT := ByteArray 0x100: 0xff - it

  draw_true_color left/int top/int right/int bottom/int red/ByteArray green/ByteArray blue/ByteArray -> none:
    patch_width := right - left
    patch_height := bottom - top
    set_range_ COLOR_TFT_CASET_ left+x_offset_ right+x_offset_
    set_range_ COLOR_TFT_RASET_ top+y_offset_ bottom+y_offset_
    send COLOR_TFT_RAMWR_  // Reset write pointer to caset and raset positions.

    table := invert_colors_ ? INVERT : null

    if sixteen_bit_mode_:
      // Using the mode where you pack 3 pixels in two bytes.  5 bits for red,
      // 6 for green, 5 for blue (the eye is more sensitive to green).  Since
      // we receive the data in three one-byte-per-pixel buffers we have to
      // shuffle the bytes.
      lines_per_chunk := buffer_.size / (patch_width * 2)
      if lines_per_chunk == 0: throw "Buffer too small for screen size"

      List.chunk_up 0 bottom - top lines_per_chunk: | from to height |
        blit blue[from * patch_width..]  buffer_      patch_width --destination_pixel_stride=2 --lookup_table=table --mask=0xf8
        blit green[from * patch_width..] buffer_      patch_width --destination_pixel_stride=2 --lookup_table=table --shift=5 --mask=0x7 --operation=OR
        blit green[from * patch_width..] buffer_[1..] patch_width --destination_pixel_stride=2 --lookup_table=table --shift=-3 --mask=0xe0
        blit red[from * patch_width..]   buffer_[1..] patch_width --destination_pixel_stride=2 --lookup_table=table --shift=3 --mask=0x1f
        device_.transfer buffer_ --dc=1 --to=patch_width * 2 * height
    else:
      // Using the mode where you pack 3 pixels in three bytes.  6 bits per
      // channel with 6 wasted bits per pixel.  Since we receive the data in
      // three one-byte-per-pixel buffers we have to shuffle the bytes.
      lines_per_chunk := buffer_.size / (patch_width * 3)
      if lines_per_chunk == 0: throw "Buffer too small for screen size"

      List.chunk_up 0 bottom - top lines_per_chunk: | from to height |
        blit blue[from * patch_width..]  buffer_      patch_width --destination_pixel_stride=3 --lookup_table=table
        blit green[from * patch_width..] buffer_[1..] patch_width --destination_pixel_stride=3 --lookup_table=table
        blit red[from * patch_width..]   buffer_[2..] patch_width --destination_pixel_stride=3 --lookup_table=table
        device_.transfer buffer_ --dc=1 --to=patch_width * 3 * height
    send COLOR_TFT_NOP_

  refresh left top right bottom:
