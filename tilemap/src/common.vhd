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

use work.math.all;
use work.types.all;

package common is
  constant RAM_ADDR_WIDTH : natural := 9;
  constant RAM_DATA_WIDTH : natural := 16;
  -- constant ROM_ADDR_WIDTH : natural := 13;
  -- constant ROM_DATA_WIDTH : natural := 32;
  constant ROM_ADDR_WIDTH : natural := 16;
  constant ROM_DATA_WIDTH : natural := 32;

  constant DEFAULT_TILE_CONFIG : tile_config_t := (
    lo_code_lsb => 0,
    lo_code_msb => 7,
    hi_code_lsb => 8,
    hi_code_msb => 10,
    color_lsb   => 12,
    color_msb   => 15
  );

  -- decodes a tile from a 16-bit vector
  function decode_tile (config : tile_config_t; data : std_logic_vector(15 downto 0)) return tile_t;

  -- selects a pixel from a tile row at the given offset
  function select_pixel (row : row_t; offset : unsigned(2 downto 0)) return pixel_t;
end package common;

package body common is
  function decode_tile (config : tile_config_t; data : std_logic_vector(15 downto 0)) return tile_t is
    variable hi_code : std_logic_vector(2 downto 0);
    variable lo_code : byte_t;
  begin
    hi_code := mask_bits(data, config.hi_code_msb, config.hi_code_lsb, 3);
    lo_code := mask_bits(data, config.lo_code_msb, config.lo_code_lsb, 8);

    return (
      code  => unsigned(hi_code & lo_code),
      color => mask_bits(data, config.color_msb, config.color_lsb, 4)
    );
  end decode_tile;

  function select_pixel (row : row_t; offset : unsigned(2 downto 0)) return pixel_t is
  begin
    case offset is
      when "000" => return row(31 downto 28);
      when "001" => return row(27 downto 24);
      when "010" => return row(23 downto 20);
      when "011" => return row(19 downto 16);
      when "100" => return row(15 downto 12);
      when "101" => return row(11 downto 8);
      when "110" => return row(7 downto 4);
      when "111" => return row(3 downto 0);
    end case;
  end select_pixel;
end package body common;
