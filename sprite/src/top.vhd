-- Copyright (c) 2019 Josh Bassett
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

use work.common.all;

entity top is
  port (
    -- 50MHz reference clock
    clk : in std_logic;

    -- VGA signals
    vga_r     : out std_logic_vector(5 downto 0);
    vga_g     : out std_logic_vector(5 downto 0);
    vga_b     : out std_logic_vector(5 downto 0);
    vga_csync : out std_logic;

    -- buttons
    key : in std_logic_vector(1 downto 0)
  );
end top;

architecture arch of top is
  -- clock signals
  signal sys_clk : std_logic;
  signal cen_6   : std_logic;
  signal reset   : std_logic;

  -- ROM signals
  signal sprite_rom_addr : unsigned(SPRITE_ROM_ADDR_WIDTH-1 downto 0);
  signal sprite_rom_data : std_logic_vector(SPRITE_ROM_DATA_WIDTH-1 downto 0);

  -- video signals
  signal video : video_t;

  -- sprite data
  signal sprite_data : byte_t;

  -- RGB data
  signal rgb : nibble_t;
begin
  -- generate the clock signals
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

  tile_rom : entity work.single_port_rom
  generic map (
    ADDR_WIDTH => SPRITE_ROM_ADDR_WIDTH,
    DATA_WIDTH => SPRITE_ROM_DATA_WIDTH,
    INIT_FILE  => "rom/vid_6g.mif"
  )
  port map (
    clk  => sys_clk,
    addr => sprite_rom_addr,
    dout => sprite_rom_data
  );

  -- video timing generator
  sync_gen : entity work.sync_gen
  port map (
    clk   => sys_clk,
    cen_6 => cen_6,
    video => video
  );

  -- sprite layer
  sprite_layer : entity work.sprite
  port map (
    clk      => sys_clk,
    cen_6    => cen_6,
    video    => video,
    rom_addr => sprite_rom_addr,
    rom_data => sprite_rom_data,
    priority => open,
    data     => sprite_data
  );

  -- latch RGB data from the palette RAM
  latch_pixel_data : process (sys_clk)
  begin
    if rising_edge(sys_clk) then
      if cen_6 = '1' then
        if video.enable = '1' then
          vga_r <= rgb & rgb(3 downto 2);
          vga_g <= rgb & rgb(3 downto 2);
          vga_b <= rgb & rgb(3 downto 2);
        else
          vga_r <= (others => '0');
          vga_g <= (others => '0');
          vga_b <= (others => '0');
        end if;
      end if;
    end if;
  end process;

  reset <= not key(0);

  -- set the RGB data
  rgb <= sprite_data(3 downto 0);

  -- composite sync
  vga_csync <= not (video.hsync xor video.vsync);
end arch;
