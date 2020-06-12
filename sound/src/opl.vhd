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

-- FM sound is handled by the YM3812 (OPL2)
entity opl is
  generic (
    -- clock frequency (in MHz)
    CLK_FREQ : real
  );
  port (
    reset : in std_logic;
    clk   : in std_logic;

    din  : in std_logic_vector(7 downto 0);
    dout : out std_logic_vector(7 downto 0);

    cs : in std_logic;
    we : in std_logic;
    a0 : in std_logic;

    irq_n : out std_logic;

    sample : out signed(15 downto 0)
  );
end entity opl;

architecture arch of opl is
  component opl2 is
    generic (CLK_FREQ : real);
    port (
      rst : in std_logic;
      clk : in std_logic;

      dout : out std_logic_vector(7 downto 0);
      din  : in std_logic_vector(7 downto 0);

      cs_n : in std_logic;
      wr_n : in std_logic;
      a0   : in std_logic;

      irq_n : out std_logic;

      sample : out signed(15 downto 0)
    );
  end component opl2;
begin
  opl2_inst : component opl2
  generic map (CLK_FREQ => CLK_FREQ)
  port map (
    rst => reset,
    clk => clk,

    din  => din,
    dout => dout,

    cs_n => not cs,
    wr_n => not we,
    a0   => a0,

    irq_n => irq_n,

    sample => sample
  );
end architecture arch;
