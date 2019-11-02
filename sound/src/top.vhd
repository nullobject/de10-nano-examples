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
    clk : in std_logic;
    key : in std_logic_vector(1 downto 0);
    led : out std_logic_vector(7 downto 0);
    audio : out std_logic
  );
end top;

architecture arch of top is
  -- clock signals
  signal sys_clk : std_logic;
  signal cen_4   : std_logic;
  signal reset   : std_logic;

  signal snd_req  : byte_t;
  signal snd_data : signed(15 downto 0);

  signal cen_1000 : std_logic;
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

  -- generate a 4MHz clock enable signal
  clock_divider_4 : entity work.clock_divider
  generic map (DIVISOR => 12)
  port map (clk => sys_clk, cen => cen_4);

  clock_divider_1000 : entity work.clock_divider
  generic map (DIVISOR => 48000)
  port map (clk => sys_clk, cen => cen_1000);

  sound : entity work.sound
  port map (
    reset => reset,
    clk   => sys_clk,
    cen   => cen_4,
    req   => snd_req,
    q     => open
  );

  dac : entity work.sigma_delta_dac
  generic map (WIDTH => 16)
  port map (
    reset => reset,
    clk   => sys_clk,
    data  => snd_data,
    q     => audio
  );

  process (clk)
  begin
    if rising_edge(clk) then
      if cen_1000 = '1' then
        if snd_data = "1111111111111111" then
          snd_data <= "0111111111111111";
        else
          snd_data <= "1111111111111111";
        end if;
      end if;
    end if;
  end process;

  snd_req <= "00100000";

  reset <= not key(0);
end arch;
