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

use work.common.all;

-- A segment provides a read-only interface to a contiguous block of ROM data,
-- located at some offset in the SDRAM.
entity segment is
  generic (
    -- the width of the ROM address bus
    ROM_ADDR_WIDTH : natural;

    -- the width of the ROM data bus
    ROM_DATA_WIDTH : natural;

    -- the offset of the ROM data in the SDRAM
    ROM_OFFSET : natural := 0
  );
  port (
    -- clock
    clk : in std_logic;

    -- chip select
    cs : in std_logic := '1';

    -- ROM interface
    rom_addr : in unsigned(ROM_ADDR_WIDTH-1 downto 0);
    rom_data : out std_logic_vector(ROM_DATA_WIDTH-1 downto 0);

    -- SDRAM interface
    sdram_addr  : buffer unsigned(SDRAM_CTRL_ADDR_WIDTH-1 downto 0);
    sdram_data  : in std_logic_vector(SDRAM_CTRL_DATA_WIDTH-1 downto 0);
    sdram_req   : out std_logic;
    sdram_valid : in std_logic
  );
end segment;

architecture arch of segment is
  -- the number of ROM words in a SDRAM word
  constant ROM_WORDS : natural := SDRAM_CTRL_DATA_WIDTH / ROM_DATA_WIDTH;

  -- the number of LSBs that need to be maked in the ROM address
  constant MASK_WIDTH : natural := ilog2(ROM_WORDS);

  -- cache signals
  signal cache_addr : unsigned(SDRAM_CTRL_ADDR_WIDTH-1 downto 0);
  signal cache_data : std_logic_vector(SDRAM_CTRL_DATA_WIDTH-1 downto 0);
  signal offset     : natural range 0 to ROM_WORDS-1;
  signal hit        : std_logic;
begin
  -- cache data received from the SDRAM
  cache_sdram_data : process (clk)
  begin
    if rising_edge(clk) then
      if sdram_valid = '1' then
        cache_addr <= sdram_addr;
        cache_data <= sdram_data;
      end if;
    end if;
  end process;

  -- assert the hit signal when the SDRAM address is already in the cache
  hit <= '1' when sdram_addr = cache_addr else '0';

  -- calculate the offset of the ROM address in the cache
  offset <= to_integer(rom_addr(MASK_WIDTH-1 downto 0)) when MASK_WIDTH > 0 else 0;

  -- extract the word at the rquested offset in the cache
  rom_data <= cache_data((ROM_WORDS-offset)*ROM_DATA_WIDTH-1 downto (ROM_WORDS-offset-1)*ROM_DATA_WIDTH) when cs = '1' else (others => '0');

  -- We need to mask the LSBs of the address, because we're converting from
  -- a ROM address to a 32-bit SDRAM address.
  --
  -- For example, converting an 8-bit address to a 32-bit address requires
  -- masking the two LSBs.
  sdram_addr <= resize(mask_lsb(rom_addr, MASK_WIDTH), sdram_addr'length) + ROM_OFFSET;

  -- request data from the SDRAM if we have a cache miss
  sdram_req <= cs and not hit;
end architecture arch;
