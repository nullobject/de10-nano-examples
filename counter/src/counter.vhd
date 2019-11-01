library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity counter is
  port (
    clk : in std_logic;
    led : out std_logic_vector(7 downto 0)
  );
end counter;

architecture arch of counter is
begin
  counter : process(clk)
    variable n : unsigned(31 downto 0);
  begin
    if (rising_edge(clk)) then
      n := n + 1;
      led <= std_logic_vector(n(31 downto 24));
    end if;
  end process;
end arch;
