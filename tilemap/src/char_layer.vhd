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

use work.common.all;
use work.types.all;

-- The character layer is the part of the graphics pipeline that handles things
-- like the logo, score, playfield, and other static graphics.
--
-- It consists of a 32x32 grid of 8x8 tiles.
entity char_layer is
  generic (
    RAM_ADDR_WIDTH : natural;
    RAM_DATA_WIDTH : natural;
    ROM_ADDR_WIDTH : natural;
    ROM_DATA_WIDTH : natural
  );
  port (
    -- configuration
    config : in tile_config_t;

    -- clock signals
    clk : in std_logic;
    cen : in std_logic;

    -- char RAM
    ram_addr : out unsigned(RAM_ADDR_WIDTH-1 downto 0);
    ram_data : in std_logic_vector(RAM_DATA_WIDTH-1 downto 0);

    -- tile ROM
    rom_addr : out unsigned(ROM_ADDR_WIDTH-1 downto 0);
    rom_data : in std_logic_vector(ROM_DATA_WIDTH-1 downto 0);

    -- video signals
    video : in video_t;

    flip : in std_logic;

    -- graphics data
    data : out byte_t
  );
end char_layer;

architecture arch of char_layer is
  -- tile signals
  signal tile     : tile_t;
  signal color    : color_t;
  signal pixel    : pixel_t;
  signal tile_row : row_t;

  signal dir : integer;
  signal flip_x : unsigned(7 downto 0);
  signal flip_y : unsigned(7 downto 0);

  -- aliases to extract the components of the horizontal and vertical position
  alias col      : unsigned(4 downto 0) is flip_x(7 downto 3);
  alias row      : unsigned(4 downto 0) is flip_y(7 downto 3);
  alias offset_x : unsigned(2 downto 0) is flip_x(2 downto 0);
  alias offset_y : unsigned(2 downto 0) is flip_y(2 downto 0);
begin
  -- Load tile data from the character RAM.
  --
  -- While the current tile is being rendered, we need to fetch data for the
  -- next tile ahead, so that it is loaded in time to render it on the screen.
  --
  -- The 16-bit tile data words aren't stored contiguously in RAM, instead they
  -- are split into high and low bytes. The high bytes are stored in the
  -- upper-half of the RAM, while the low bytes are stored in the lower-half.
  --
  -- We latch the tile code well before the end of the row, to allow the GPU
  -- enough time to fetch pixel data from the tile ROM.
  tile_data_pipeline : process (clk)
  begin
    if rising_edge(clk) then
      if cen = '1' then
        case to_integer(video.pos.x(2 downto 0)) is
          when 0 =>
            -- load the next tile
            ram_addr <= row & (col+dir);

          when 1 =>
            -- latch tile
            tile <= decode_tile(config, ram_data);

          when 6 =>
            -- latch the row data
            tile_row <= rom_data;

            -- latch tile color
            color <= tile.color;

          when others => null;
        end case;
      end if;
    end if;
  end process;

  dir <= -1 when flip = '1' else 1;

  flip_x <= (not video.pos.x(7 downto 0)) when flip = '1' else video.pos.x(7 downto 0);
  flip_y <= (not video.pos.y(7 downto 0)) when flip = '1' else video.pos.y(7 downto 0);

  -- Set the tile ROM address.
  --
  -- This address points to a row of an 8x8 tile.
  rom_addr <= tile.code(9 downto 0) & offset_y(2 downto 0);

  -- select the next pixel from the tile row data
  pixel <= select_pixel(tile_row, offset_x+dir);

  -- set graphics data
  data <= color & pixel;
end architecture arch;
