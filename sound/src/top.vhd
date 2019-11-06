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

  signal req : std_logic;

  signal snd_req    : std_logic;
  signal snd_data   : byte_t;
  signal snd_sample : signed(15 downto 0);

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

  -- generate a reset pulse after powering on, or when KEY0 is pressed
  reset_gen : entity work.reset_gen
  port map (
    clk  => sys_clk,
    rin  => not key(0),
    rout => reset
  );

  -- generate a request pulse after powering on, or when KEY1 is pressed
  req_gen : entity work.reset_gen
  port map (
    clk  => sys_clk,
    rin  => not key(1),
    rout => req
  );

  -- detect rising edges of the req signal
  req_edge_detector : entity work.edge_detector
  generic map (RISING => true)
  port map (
    clk  => sys_clk,
    data => req,
    q    => snd_req
  );

  sound : entity work.sound
  port map (
    reset  => reset,
    clk    => sys_clk,
    cen    => cen_4,
    req    => snd_req,
    data   => snd_data,
    sample => snd_sample
  );

  -- converts audio samples to an analog signal
  dac : entity work.sigma_delta_dac
  generic map (WIDTH => 16)
  port map (
    reset => reset,
    clk   => clk,
    data  => (not snd_sample(15)) & snd_sample(14 downto 0),
    q     => audio
  );

  snd_data <= x"32";

  audio_l <= audio;
  audio_r <= audio;
end arch;
