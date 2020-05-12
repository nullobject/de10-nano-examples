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

entity sigma_delta_dac is
  generic (
    WIDTH : integer := 8
  );

  port (
    reset : in std_logic;

    clk : in std_logic;

    -- input data
    data : in signed(WIDTH-1 downto 0);

    -- output data
    q : out std_logic
  );
end sigma_delta_dac;

architecture rtl of sigma_delta_dac is
  signal delta_add   : unsigned(WIDTH+1 downto 0);
  signal sigma_add   : unsigned(WIDTH+1 downto 0);
  signal sigma_latch : unsigned(WIDTH+1 downto 0);
  signal delta_b     : unsigned(WIDTH+1 downto 0);
begin
  delta_b(WIDTH+1)          <= sigma_latch(WIDTH+1);
  delta_b(WIDTH)            <= sigma_latch(WIDTH+1);
  delta_b(WIDTH-1 downto 0) <= (others => '0');

  delta_add <= unsigned(data) + delta_b;
  sigma_add <= delta_add + sigma_latch;

  process (clk, reset)
  begin
    if reset = '1' then
      sigma_latch(WIDTH) <= '1';
      sigma_latch <= (others => '0');
      q <= '0';
    elsif rising_edge(clk) then
      sigma_latch <= sigma_add;
      q <= sigma_latch(WIDTH+1);
    end if;
  end process;
end rtl;
