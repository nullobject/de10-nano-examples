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

library pll;

use work.types.all;

entity top is
  port (
    -- 50MHz reference clock
    clk : in std_logic;

    -- VGA signals
    vga_r, vga_g, vga_b : out std_logic_vector(5 downto 0);
    vga_csync           : out std_logic
  );
end top;

architecture arch of top is
  -- clock signals
  signal sys_clk : std_logic;
  signal cen_6   : std_logic;

  -- video signals
  signal video : video_t;

  -- tilemap data
  signal tilemap_data : byte_t;

  -- pixel data
  signal pixel : nibble_t;
begin
  -- generate a 12MHz clock signal
  my_pll : entity pll.pll
  port map (
    refclk   => clk,
    rst      => '0',
    outclk_0 => sys_clk,
    outclk_1 => open,
    locked   => open
  );

  -- generate a 6MHz clock enable signal
  clock_divider_6 : entity work.clock_divider
  generic map (DIVISOR => 8)
  port map (clk => sys_clk, cen => cen_6);

  -- video timing generator
  sync_gen : entity work.sync_gen
  port map (
    clk   => sys_clk,
    cen_6 => cen_6,
    video => video
  );

  -- tilemap layer
  tilemap_layer : entity work.tilemap
  port map (
    clk   => sys_clk,
    video => video,
    data  => tilemap_data
  );

  -- latch pixel data from the palette RAM
  latch_pixel_data : process (sys_clk)
  begin
    if rising_edge(sys_clk) then
        if cen_6 = '1' then
        if video.enable = '1' then
          vga_r <= pixel & pixel(3 downto 2);
          vga_g <= pixel & pixel(3 downto 2);
          vga_b <= pixel & pixel(3 downto 2);
        else
          vga_r <= (others => '0');
          vga_g <= (others => '0');
          vga_b <= (others => '0');
        end if;
      end if;
    end if;
  end process;

  -- set the pixel data
  pixel <= tilemap_data(3 downto 0);

  -- composite sync
  vga_csync <= not (video.hsync xor video.vsync);
end arch;
