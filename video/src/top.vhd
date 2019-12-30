library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library pll;

use work.common.all;

entity top is
  port (
    clk : in std_logic;
    vga_hs, vga_vs : out std_logic;
    vga_r, vga_g, vga_b : out std_logic_vector(5 downto 0);
    vga_en : in std_logic
  );
end top;

architecture arch of top is
  signal clk_6 : std_logic;
  signal video : video_t;
begin
  my_pll : entity pll.pll
  port map (
    refclk   => clk,
    rst      => '0',
    outclk_0 => clk_6,
    locked   => open
  );

  video_gen : entity work.video_gen
  port map (
    clk   => clk_6,
    cen   => '1',
    video => video
  );

  vga_hs <= not (video.hsync xor video.vsync);
  vga_vs <= '1';
  vga_r <= "111111" when video.enable = '1' and ((video.pos.x(2 downto 0) = "000") or (video.pos.y(2 downto 0) = "000")) else "ZZZZZZ";
  vga_g <= "111111" when video.enable = '1' and video.pos.x(4) = '1' else "ZZZZZZ";
  vga_b <= "111111" when video.enable = '1' and video.pos.y(4) = '1' else "ZZZZZZ";
end arch;
