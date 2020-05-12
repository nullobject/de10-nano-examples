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

use work.types.all;

entity tilemap is
  port (
    -- clock
    clk : in std_logic;

    -- video signals
    video : in video_t;

    -- graphics data
    data : out byte_t
  );
end tilemap;

architecture arch of tilemap is
  -- RAM signals
  signal ram_addr : std_logic_vector(RAM_ADDR_WIDTH-1 downto 0);
  signal ram_dout : byte_t;

  -- ROM signals
  signal rom_addr : std_logic_vector(ROM_ADDR_WIDTH-1 downto 0);
  signal rom_dout : std_logic_vector(ROM_DATA_WIDTH-1 downto 0);

  -- tile signals
  signal tile_data  : byte_t;
  signal tile_code  : tile_code_t;
  signal tile_color : tile_color_t;
  signal tile_pixel : tile_pixel_t;
  signal tile_row   : tile_row_t;

  -- extract the components of the video position vectors
  alias col      : unsigned(4 downto 0) is video.pos.x(8 downto 4);
  alias row      : unsigned(3 downto 0) is video.pos.y(7 downto 4);
  alias offset_x : unsigned(3 downto 0) is video.pos.x(3 downto 0);
  alias offset_y : unsigned(3 downto 0) is video.pos.y(3 downto 0);
begin
  tile_ram : entity work.single_port_rom
  generic map (
    ADDR_WIDTH => RAM_ADDR_WIDTH,
    INIT_FILE  => "rom/tiles.mif",

    -- XXX: for debugging
    ENABLE_RUNTIME_MOD => "YES"
  )
  port map (
    clk  => clk,
    addr => ram_addr,
    dout => ram_dout
  );

  tile_rom : entity work.single_port_rom
  generic map (
    ADDR_WIDTH => ROM_ADDR_WIDTH,
    DATA_WIDTH => ROM_DATA_WIDTH,
    INIT_FILE  => "rom/fg.mif"
  )
  port map (
    clk  => clk,
    addr => rom_addr,
    dout => rom_dout
  );

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
      case to_integer(offset_x) is
        when 8 =>
          -- load high byte
          ram_addr <= std_logic_vector('1' & (col+1));

        when 9 =>
          -- latch high byte
          tile_data <= ram_dout;

          -- load low byte
          ram_addr <= std_logic_vector('0' & (col+1));

        when 10 =>
          -- latch tile code
          tile_code <= unsigned(tile_data(1 downto 0) & ram_dout);

        when 15 =>
          -- latch colour
          tile_color <= tile_data(7 downto 4);

        when others => null;
      end case;
    end if;
  end process;

  -- latch the next row from the tile ROM when rendering the last pixel in
  -- every row
  latch_tile_row : process (clk)
  begin
    if rising_edge(clk) then
      if video.pos.x(2 downto 0) = 7 then
        tile_row <= rom_dout;
      end if;
    end if;
  end process;

  -- Set the tile ROM address.
  --
  -- This address points to a row of an 8x8 tile.
  rom_addr <= std_logic_vector(tile_code & offset_y(3) & (not offset_x(3)) & offset_y(2 downto 0));

  -- decode the pixel from the tile row data
  with to_integer(video.pos.x(2 downto 0)) select
    tile_pixel <= tile_row(31 downto 28) when 0,
                  tile_row(27 downto 24) when 1,
                  tile_row(23 downto 20) when 2,
                  tile_row(19 downto 16) when 3,
                  tile_row(15 downto 12) when 4,
                  tile_row(11 downto 8)  when 5,
                  tile_row(7 downto 4)   when 6,
                  tile_row(3 downto 0)   when 7,
                  (others => '0')        when others;

  -- set graphics data
  data <= tile_color & tile_pixel;
end arch;
