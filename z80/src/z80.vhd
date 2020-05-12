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

entity z80 is
  port (
    clk : in std_logic;
    key : in std_logic_vector(1 downto 0);
    led : out std_logic_vector(7 downto 0)
  );
end z80;

architecture arch of z80 is
  -- clock
  signal cpu_clk : std_logic;

  -- address bus
  signal cpu_addr	: std_logic_vector(15 downto 0);

  -- data bus
  signal cpu_di	: std_logic_vector(7 downto 0);
  signal cpu_do	: std_logic_vector(7 downto 0);

  -- i/o request: the address bus holds a valid address for an i/o read or
  -- write operation
  signal cpu_ioreq_n : std_logic;

  -- memory request: the address bus holds a valid address for a memory read or
  -- write operation
  signal cpu_mreq_n : std_logic;

  -- read: ready to read data from the data bus
  signal cpu_rd_n : std_logic;

  -- write: the data bus contains a byte to write somewhere
  signal cpu_wr_n : std_logic;
begin
  clock_divider : process(clk)
    variable n : unsigned(31 downto 0);
  begin
    if rising_edge(clk) then
      n := n + 1;
    end if;
    cpu_clk <= not n(18);
  end process;

  rom : entity work.single_port_rom
  generic map(ADDR_WIDTH => 16, DATA_WIDTH => 8)
  port map(
    clk => clk,
    addr => cpu_addr,
    data => cpu_di
  );

  cpu : entity work.T80s
  port map(
    RESET_n => '1',
    CLK_n   => cpu_clk,
    WAIT_n  => '1',
    INT_n   => '1',
    NMI_n   => '1',
    BUSRQ_n => '1',
    M1_n    => open,
    MREQ_n  => cpu_mreq_n,
    IORQ_n  => cpu_ioreq_n,
    RD_n    => cpu_rd_n,
    WR_n    => cpu_wr_n,
    RFSH_n  => open,
    HALT_n  => open,
    BUSAK_n => open,
    A       => cpu_addr,
    DI      => cpu_di,
    DO      => cpu_do
  );

  led <= cpu_addr(7 downto 0) when cpu_mreq_n = '0' and cpu_rd_n = '0';
end arch;
