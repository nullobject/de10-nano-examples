library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sigma_delta_dac is
  generic (
    WIDTH : integer := 8
  );

  port (
    reset : in std_logic;
    clk   : in std_logic;
    data  : in signed(WIDTH-1 downto 0);
    q     : out std_logic
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
