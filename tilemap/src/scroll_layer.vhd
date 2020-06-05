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
use work.math.all;
use work.types.all;

-- The scroll module handles the scrolling foreground and background layers in
-- the graphics pipeline.
--
-- It consists of a 32x16 grid of 16x16 tiles. Each 16x16 tile is made up of
-- four separate 8x8 tiles, stored in a left-to-right, top-to-bottom order.
--
-- Each tile in the tilemap is represented by two bytes in the scroll RAM,
-- a high byte and a low byte, which contains the tile colour and code.
--
-- Because a scrolling layer is twice the width of the screen, it can never be
-- entirely visible on the screen at once. The horizontal and vertical scroll
-- positions are used to set the position of the visible area.
entity scroll_layer is
  generic (
    RAM_ADDR_WIDTH : natural;
    RAM_DATA_WIDTH : natural;
    ROM_ADDR_WIDTH : natural;
    ROM_DATA_WIDTH : natural
  );
  port (
    -- clock signals
    clk : in std_logic;
    cen : in std_logic;

    -- configuration
    config : in tile_config_t;

    -- flip screen
    flip : in std_logic;

    -- scroll RAM
    ram_addr : out unsigned(RAM_ADDR_WIDTH-1 downto 0);
    ram_data : in std_logic_vector(RAM_DATA_WIDTH-1 downto 0);

    -- tile ROM
    rom_addr : out unsigned(ROM_ADDR_WIDTH-1 downto 0);
    rom_data : in std_logic_vector(ROM_DATA_WIDTH-1 downto 0);

    -- video signals
    video : in video_t;

    -- scroll position
    scroll_pos : in pos_t;

    -- graphics data
    data : out byte_t
  );
end scroll_layer;

architecture arch of scroll_layer is
  constant LINE_BUFFER_ADDR_WIDTH : natural := 8;
  constant LINE_BUFFER_DATA_WIDTH : natural := 8;

  -- tile signals
  signal tile     : tile_t;
  signal color    : color_t;
  signal pixel    : pixel_t;
  signal tile_row : row_t;

  -- line buffer
  signal line_buffer_swap   : std_logic;
  signal line_buffer_addr_a : unsigned(LINE_BUFFER_ADDR_WIDTH-1 downto 0);
  signal line_buffer_din_a  : std_logic_vector(LINE_BUFFER_DATA_WIDTH-1 downto 0);
  signal line_buffer_we_a   : std_logic;
  signal line_buffer_addr_b : unsigned(LINE_BUFFER_ADDR_WIDTH-1 downto 0);
  signal line_buffer_dout_b : std_logic_vector(LINE_BUFFER_DATA_WIDTH-1 downto 0);

  -- destination position
  signal dest_pos : pos_t;

  signal flip_y : unsigned(7 downto 0);

  -- aliases to extract the components of the horizontal and vertical position
  alias col      : unsigned(4 downto 0) is dest_pos.x(8 downto 4);
  alias row      : unsigned(3 downto 0) is dest_pos.y(7 downto 4);
  alias offset_x : unsigned(3 downto 0) is dest_pos.x(3 downto 0);
  alias offset_y : unsigned(3 downto 0) is dest_pos.y(3 downto 0);
begin
  line_buffer : entity work.line_buffer
  generic map (
    ADDR_WIDTH => LINE_BUFFER_ADDR_WIDTH,
    DATA_WIDTH => LINE_BUFFER_DATA_WIDTH
  )
  port map (
    clk   => clk,

    swap => line_buffer_swap,

    -- port A (write)
    addr_a => line_buffer_addr_a,
    din_a  => line_buffer_din_a,
    we_a   => line_buffer_we_a,

    -- port B (read)
    addr_b => line_buffer_addr_b,
    dout_b => line_buffer_dout_b
  );

  -- update position counter
  update_pos_counter : process (clk)
  begin
    if rising_edge(clk) then
      if cen = '1' then
        if video.hsync = '1' then
          dest_pos.x <= scroll_pos.x;
        else
          dest_pos.x <= dest_pos.x+1;
        end if;
      end if;
    end if;
  end process;

  -- Load tile data from the scroll RAM.
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
        case to_integer(offset_x) is
          when 7 =>
            -- latch row data
            tile_row <= rom_data;

          when 8 =>
            -- load next tile
            ram_addr <= row & (col+1);

          when 9 =>
            -- latch tile
            tile <= decode_tile(config, ram_data);

          when 15 =>
            -- latch row data
            tile_row <= rom_data;

            -- latch tile color
            color <= tile.color;

          when others => null;
        end case;
      end if;
    end if;
  end process;

  -- set flipped vertical position one line ahead/behind
  flip_y <= (not video.pos.y(7 downto 0))-1 when flip = '1' else
            video.pos.y(7 downto 0)+1;

  -- set vertical position
  dest_pos.y <= resize(scroll_pos.y+flip_y, dest_pos.y'length);

  -- set tile ROM address
  rom_addr <= tile.code & offset_y(3) & (not offset_x(3)) & offset_y(2 downto 0);

  -- select pixel from the tile row data
  pixel <= select_pixel(tile_row, offset_x(2 downto 0));

  -- swap line buffer on alternating rows
  line_buffer_swap <= video.pos.y(0);

  -- write line buffer
  line_buffer_addr_a <= not video.pos.x(7 downto 0) when flip = '1' else video.pos.x(7 downto 0);
  line_buffer_din_a  <= color & pixel;
  line_buffer_we_a   <= not video.hblank;

  -- read line buffer one pixel ahead
  line_buffer_addr_b <= video.pos.x(7 downto 0)+1;

  -- set graphics data
  data <= line_buffer_dout_b;
end architecture arch;
