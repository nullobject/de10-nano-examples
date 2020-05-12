--   __   __     __  __     __         __
--  /\ "-.\ \   /\ \/\ \   /\ \       /\ \
--  \ \ \-.  \  \ \ \_\ \  \ \ \____  \ \ \____
--   \ \_\\"\_\  \ \_____\  \ \_____\  \ \_____\
--    \/_/ \/_/   \/_____/   \/_____/   \/_____/
--   ______     ______       __     ______     ______     ______
--  /\  __ \   /\  == \     /\ \   /\  ___\   /\  ___\   /\__  _\
--  \ \ \/\ \  \ \  __<    _\_\ \  \ \  __\   \ \ \____  \/_/\ \/
--   \ \_____\  \ \_____\ /\_____\  \ \_____\  \ \_____\    \ \_\
--    \/_____/   \/_____/ \/_____/   \/_____/   \/_____/     \/_/
--
-- https://joshbassett.info
-- https://twitter.com/nullobject
-- https://github.com/nullobject
--
-- Copyright (c) 2020 Josh Bassett
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package types is
  constant RAM_ADDR_WIDTH : natural := 6;
  constant ROM_ADDR_WIDTH : natural := 15;
  constant ROM_DATA_WIDTH : natural := 32;

  -- each 8x8 tile is composed of four layers of pixel data (bitplanes)
  constant TILE_BPP : natural := 4;

  subtype byte_t is std_logic_vector(7 downto 0);
  subtype nibble_t is std_logic_vector(3 downto 0);

  -- represents a row of pixels in a 8x8 tile
  subtype tile_row_t is std_logic_vector(TILE_BPP*8-1 downto 0);

  -- represents a pixel in a 8x8 tile
  subtype tile_pixel_t is std_logic_vector(TILE_BPP-1 downto 0);

  -- represents the colour of a tile
  subtype tile_color_t is std_logic_vector(3 downto 0);

  -- represents the index of a tile in a tilemap
  subtype tile_code_t is unsigned(9 downto 0);

  -- represents a position
  type pos_t is record
    x : unsigned(8 downto 0);
    y : unsigned(8 downto 0);
  end record pos_t;

  -- represents the video signals
  type video_t is record
    -- position
    pos : pos_t;

    -- sync signals
    hsync : std_logic;
    vsync : std_logic;

    -- blank signals
    hblank : std_logic;
    vblank : std_logic;

    -- enable video output
    enable : std_logic;
  end record video_t;
end package types;
