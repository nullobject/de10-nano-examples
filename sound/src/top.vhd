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

    audio_l : out std_logic;
    audio_r : out std_logic
  );
end top;

architecture arch of top is
  signal reset : std_logic;

  signal sys_clk : std_logic;
  signal cen_4   : std_logic;
  signal cen_384 : std_logic;

  signal snd : natural range 0 to 255 := 0;

  signal next_btn : std_logic;
  signal play_btn : std_logic;

  signal snd_data  : byte_t;
  signal snd_audio : audio_t;

  signal audio : std_logic;
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

  -- generate a 384KHz clock enable signal
  clock_divider_384 : entity work.clock_divider
  generic map (DIVISOR => 125)
  port map (clk => sys_clk, cen => cen_384);

  -- generate a reset pulse after powering on, or when KEY0 is pressed
  reset_gen : entity work.reset_gen
  port map (
    clk  => sys_clk,
    rin  => '0',
    rout => reset
  );

  -- detect when the NEXT button is pressed
  next_edge_detector : entity work.edge_detector
  generic map (FALLING => true)
  port map (
    clk  => sys_clk,
    data => key(0),
    q    => next_btn
  );

  -- detect when the PLAY button is pressed
  play_edge_detector : entity work.edge_detector
  generic map (FALLING => true)
  port map (
    clk  => sys_clk,
    data => key(1),
    q    => play_btn
  );

  sound : entity work.sound
  port map (
    reset   => reset,
    clk     => sys_clk,
    cen_4   => cen_4,
    cen_384 => cen_384,
    req     => play_btn,
    data    => snd_data,
    audio   => snd_audio
  );

  -- converts audio samples to an analog signal
  dac : entity work.sigma_delta_dac
  generic map (WIDTH => 16)
  port map (
    reset => reset,
    clk   => clk,
    data  => (not snd_audio(15)) & snd_audio(14 downto 0),
    q     => audio
  );

  process (clk)
  begin
    if rising_edge(clk) then
      if next_btn = '1' then
        snd <= snd + 1;
      end if;
    end if;
  end process;

  snd_data <= std_logic_vector(to_unsigned(snd, 8));

  led <= snd_data;

  audio_l <= audio;
  audio_r <= audio;
end arch;
