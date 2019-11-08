--	(c) 2012 d18c7db(a)hotmail
--
--	This program is free software; you can redistribute it and/or modify it under
--	the terms of the GNU General Public License version 3 or, at your option,
--	any later version as published by the Free Software Foundation.
--
--	This program is distributed in the hope that it will be useful,
--	but WITHOUT ANY WARRANTY; without even the implied warranty of
--	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
--
-- For full details, see the GNU General Public License at www.gnu.org/licenses
--------------------------------------------------------------------------------
-- OKI Semiconductor MSM5205 - ADPCM SPEECH SYNTHESIS LSI
--
--	The MSM5205 is a speech synthesis integrated circuit which accepts
--	Adaptive Differential Pulse Code Modulation (ADPCM) data.
--
--	The circuit consists of synthesis stage which expands the 3- or 4-bit
--	ADPCM data to 12-bit Pulse Code Modulation (PCM) data and a D/A stage
--	which reproduces analog signals from the PCM data.
--
--			+---------+
--	S1    | 1  U 18 |  VDD
--	S2    | 2    17 | /XT
--	4B/3B | 3    16 |  XT
--	D0    | 4    15 |  RESET
--	D1    | 5    14 | /VCK
--	D1    | 6    13 |  T2
--	D3    | 7    12 |  T1
--	NC    | 8    11 |  NC
--	VSS   | 9    10 |  DAOUT
--			+---------+
--------------------------------------------------------------------------------
-- Only 4 bit mode implemented, 3 bit mode remains to be done (by you)
--
-- Unlike real MSM5205, this code implements internal limiting to prevent
-- over/under flow distortion so it's more like a MSM6585 in that respect
--
-- No internal DAC, the 12 bit data is sent out for the user to deal with
-- This way it can be fed to an external DAC or summed with other channels

library ieee;
	use ieee.std_logic_1164.ALL;
	use ieee.numeric_std.ALL;

entity MSM5205 is
	generic (signed_data : boolean := true);			-- true  : outputs signed data in range -2048/2047
																	-- false : outputs unsigned data in range 0..4095
	port (
		reset : in  std_logic;								-- pin 15        active high reset
		xt    : in  std_logic;								-- pin 16,17     fosc clock input = 384Khz or 768Khz, (pin 17 clock complement not used)
		s4b3b : in  std_logic;								-- pin 3         ADPCM data format, H = 4 bit, L = 3 bit (only 4 bit implemented here!)
		s1s2  : in  std_logic_vector( 1 downto 0);	-- pin 1,2       sampling freq: LL=fosc/96, LH=fosc/64, HL=fosc/48, HH=prohibited
		di    : in  std_logic_vector( 3 downto 0);	-- pin 7,6,5,4   ADPCM input data, for 3-bit ADPCM data D0 input is not used and should be connected to ground
		do    : out std_logic_vector(11 downto 0);	-- pin 10        output data, 12 bit PCM
		vck   : out std_logic								-- pin 14        sampling clk out as selected by s1s2
																	-- pin 13, 12    test pins T2, T1 not used
	);
end MSM5205;

architecture RTL of MSM5205 is
	signal vck_int   : std_logic := '0';
	signal vck_ena   : std_logic := '0';
	signal final_val : signed(15 downto 0) := (others=>'0');
	signal out_val   : signed(15 downto 0) := (others=>'0');
	signal sum_val   : signed(12 downto 0) := (others=>'0');
	signal sign_val  : signed(12 downto 0) := (others=>'0');
	signal ctr       : unsigned( 6 downto 0) := (others=>'0');
	signal step      : unsigned( 5 downto 0) := (others=>'0');
	signal divctr    : unsigned( 3 downto 0) := (others=>'0');

	signal stepval   : signed(11 downto 0) := (others=>'0');
	signal stepval1, stepval2, stepval4, stepval8
		: signed(12 downto 0) := (others=>'0');
	
	--	Dialogic ADPCM Algorithm, table 2
	type STEPVAL_ARRAY is array(0 to 48) of signed(11 downto 0);
	constant STEP_VAL_TABLE : STEPVAL_ARRAY := (
		x"010",x"011",x"013",x"015",x"017",x"019",x"01C",x"01F",
		x"022",x"025",x"029",x"02D",x"032",x"037",x"03C",x"042",
		x"049",x"050",x"058",x"061",x"06B",x"076",x"082",x"08F",
		x"09D",x"0AD",x"0BE",x"0D1",x"0E6",x"0FD",x"117",x"133",
		x"151",x"173",x"198",x"1C1",x"1EE",x"220",x"256",x"292",
		x"2D4",x"31C",x"36C",x"3C3",x"424",x"48E",x"502",x"583",
		x"610"
	);

begin
	do  <= std_logic_vector(out_val(11 downto 0));
	vck <= vck_int;

	p_vck : process
	begin
		wait until rising_edge(xt);
		if vck_ena = '1' then
			-- or with s1s2 stops clock on prohibited value
			vck_int <= (not vck_int) or (s1s2(0) and s1s2(1));
		end if;
	end process;

	--	Sample Clock Selector
	p_clk_sel : process
	begin
		wait until rising_edge(xt);
		case s1s2 is                      -- S1 S2  Sampling freq
			when "00"   => divctr <= x"6"; -- L  L   fosc/96
			when "01"   => divctr <= x"4"; -- L  H   fosc/64
			when "10"   => divctr <= x"3"; -- H  L   fosc/48
			when others => divctr <= x"0"; -- H  H   prohibited
		end case;
	end process;

	-- divide main clock by a selectable divisor
	p_div : process
		begin
		wait until rising_edge(xt);
		if ctr(6 downto 3) = divctr then
			ctr <= "0000001";
			vck_ena <= '1';
		else
			ctr <= ctr + 1;
			vck_ena <= '0';
		end if;
	end process;

	--	Dialogic ADPCM Algorithm, table 1
	-- adjust step value based on current ADPCM sample
	-- keep it within 0-48 limits
	process
	begin
		wait until rising_edge(xt);
		if vck_ena = '1' and vck_int = '1' then
			if reset = '1' then
				step <= to_unsigned( 1, 6);
			else
				case di(2 downto 0) is
					when "111"  => if step < 41 then step <= step + 8; else step <= to_unsigned(48, 6); end if;
					when "110"  => if step < 43 then step <= step + 6; else step <= to_unsigned(48, 6); end if;
					when "101"  => if step < 45 then step <= step + 4; else step <= to_unsigned(48, 6); end if;
					when "100"  => if step < 47 then step <= step + 2; else step <= to_unsigned(48, 6); end if;
					when others => if step > 0  then step <= step - 1; else step <= to_unsigned( 0, 6); end if;
				end case;
			end if;
--			unclear from datasheet how 3bit is handled. ffmpeg/libavcodec/adpcm.c uses this table
--			stepval calculation below would also be affected in 3 bit mode, not sure how yet
--			case di(2 downto 1) is
--				when "11"   => if step < 45 then step <= step + 4; else step <= to_unsigned(48, 6); end if;
--				when "10"   => if step < 47 then step <= step + 2; else step <= to_unsigned(48, 6); end if;
--				when others => if step > 0  then step <= step - 1; else step <= to_unsigned( 0, 6); end if;
--			end case;
		end if;
	end process;

	-- table lookup only has positive values
	stepval  <= STEP_VAL_TABLE(to_integer(step)); 			                         -- value
	-- so we can afford to just shift in zeroes from the left without sign extension
	stepval1 <=    "0" & stepval(11 downto 0) when di(2) = '1' else (others=>'0'); -- value/1
	stepval2 <=   "00" & stepval(11 downto 1) when di(1) = '1' else (others=>'0'); -- value/2
	stepval4 <=  "000" & stepval(11 downto 2) when di(0) = '1' else (others=>'0'); -- value/4
	stepval8 <= "0000" & stepval(11 downto 3);                                     -- value/8
	sum_val  <= ( (stepval1 + stepval2) + (stepval4 + stepval8) );

	sign_val <= sum_val when di(3) = '0' else -sum_val; -- di(3) determines if we return sum or -sum

	process
	begin
		wait until rising_edge(xt);
		if vck_ena = '1' and vck_int = '1' then
			if reset = '1' then
				final_val <= to_signed( 0, 16);
			else
				-- hard limit math results to 12 bit values
				if (final_val + sign_val < -2048) then
					final_val <= to_signed(-2048, 16); -- underflow, stay on max negative value
				elsif (final_val + sign_val > 2047) then
					final_val <= to_signed( 2047, 16); -- overflow,  stay on max positive value
				else
					final_val <= final_val + sign_val;
				end if;
			end if;
		end if;
	end process;

		out_val <= final_val when signed_data else -- signed
			-- turn signed 12 bit value to unsigned by adding offset
			to_signed( 2048, 16) + final_val(11 downto 0); -- unsigned
end RTL;
