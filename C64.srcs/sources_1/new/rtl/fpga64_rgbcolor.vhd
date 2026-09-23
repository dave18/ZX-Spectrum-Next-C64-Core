-- -----------------------------------------------------------------------
--
--                                 FPGA 64
--
--     A fully functional commodore 64 implementation in a single FPGA
--
-- -----------------------------------------------------------------------
-- Copyright 2005-2008 by Peter Wendrich (pwsoft@syntiac.com)
-- http://www.syntiac.com/fpga64.html
-- -----------------------------------------------------------------------
--
-- C64 palette index to 24 bit RGB color
-- 
-- -----------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

-- -----------------------------------------------------------------------

entity fpga64_rgbcolor is
	port (
		palette: in unsigned(2 downto 0);
		index: in unsigned(3 downto 0);
		r: out unsigned(7 downto 0);
		g: out unsigned(7 downto 0);
		b: out unsigned(7 downto 0)
	);
end fpga64_rgbcolor;

-- -----------------------------------------------------------------------

architecture Behavioral of fpga64_rgbcolor is
begin
	process(index, palette)
	begin
		case palette is
		when "000" =>
			case index is
            when X"0" => r <= X"00"; g <= X"00"; b <= X"00";
            when X"1" => r <= X"77"; g <= X"77"; b <= X"77";
            when X"2" => r <= X"44"; g <= X"11"; b <= X"22";
            when X"3" => r <= X"33"; g <= X"66"; b <= X"55";
            when X"4" => r <= X"44"; g <= X"22"; b <= X"44";
            when X"5" => r <= X"22"; g <= X"55"; b <= X"22";
            when X"6" => r <= X"11"; g <= X"11"; b <= X"44";
            when X"7" => r <= X"77"; g <= X"77"; b <= X"33";
            when X"8" => r <= X"44"; g <= X"22"; b <= X"11";
            when X"9" => r <= X"22"; g <= X"22"; b <= X"00";
            when X"A" => r <= X"55"; g <= X"33"; b <= X"33";
            when X"B" => r <= X"22"; g <= X"22"; b <= X"22";
            when X"C" => r <= X"33"; g <= X"33"; b <= X"33";
            when X"D" => r <= X"55"; g <= X"77"; b <= X"44";
            when X"E" => r <= X"33"; g <= X"33"; b <= X"66";
            when X"F" => r <= X"55"; g <= X"55"; b <= X"55";
			end case;
		when "001" =>
			case index is
            when X"0" => r <= X"00"; g <= X"00"; b <= X"00";
            when X"1" => r <= X"77"; g <= X"77"; b <= X"77";
            when X"2" => r <= X"44"; g <= X"11"; b <= X"11";
            when X"3" => r <= X"33"; g <= X"66"; b <= X"66";
            when X"4" => r <= X"44"; g <= X"11"; b <= X"55";
            when X"5" => r <= X"22"; g <= X"55"; b <= X"22";
            when X"6" => r <= X"11"; g <= X"11"; b <= X"55";
            when X"7" => r <= X"77"; g <= X"77"; b <= X"33";
            when X"8" => r <= X"44"; g <= X"22"; b <= X"11";
            when X"9" => r <= X"22"; g <= X"22"; b <= X"00";
            when X"A" => r <= X"66"; g <= X"33"; b <= X"33";
            when X"B" => r <= X"22"; g <= X"22"; b <= X"22";
            when X"C" => r <= X"33"; g <= X"33"; b <= X"33";
            when X"D" => r <= X"44"; g <= X"77"; b <= X"44";
            when X"E" => r <= X"33"; g <= X"33"; b <= X"77";
            when X"F" => r <= X"55"; g <= X"55"; b <= X"55";
			end case;
		when "010" =>
			case index is
            when X"0" => r <= X"00"; g <= X"00"; b <= X"00";
            when X"1" => r <= X"77"; g <= X"77"; b <= X"77";
            when X"2" => r <= X"33"; g <= X"22"; b <= X"11";
            when X"3" => r <= X"33"; g <= X"55"; b <= X"55";
            when X"4" => r <= X"33"; g <= X"22"; b <= X"44";
            when X"5" => r <= X"22"; g <= X"44"; b <= X"22";
            when X"6" => r <= X"11"; g <= X"11"; b <= X"33";
            when X"7" => r <= X"55"; g <= X"55"; b <= X"33";
            when X"8" => r <= X"33"; g <= X"22"; b <= X"11";
            when X"9" => r <= X"22"; g <= X"22"; b <= X"00";
            when X"A" => r <= X"44"; g <= X"33"; b <= X"22";
            when X"B" => r <= X"22"; g <= X"22"; b <= X"22";
            when X"C" => r <= X"33"; g <= X"33"; b <= X"33";
            when X"D" => r <= X"44"; g <= X"66"; b <= X"44";
            when X"E" => r <= X"33"; g <= X"33"; b <= X"55";
            when X"F" => r <= X"44"; g <= X"44"; b <= X"44";
			end case;
		when "011" =>
			case index is
            when X"0" => r <= X"00"; g <= X"00"; b <= X"00";
            when X"1" => r <= X"66"; g <= X"66"; b <= X"66";
            when X"2" => r <= X"33"; g <= X"11"; b <= X"11";
            when X"3" => r <= X"33"; g <= X"44"; b <= X"55";
            when X"4" => r <= X"33"; g <= X"22"; b <= X"44";
            when X"5" => r <= X"22"; g <= X"44"; b <= X"11";
            when X"6" => r <= X"11"; g <= X"11"; b <= X"33";
            when X"7" => r <= X"55"; g <= X"55"; b <= X"33";
            when X"8" => r <= X"33"; g <= X"22"; b <= X"11";
            when X"9" => r <= X"22"; g <= X"22"; b <= X"00";
            when X"A" => r <= X"44"; g <= X"33"; b <= X"22";
            when X"B" => r <= X"22"; g <= X"22"; b <= X"22";
            when X"C" => r <= X"33"; g <= X"33"; b <= X"33";
            when X"D" => r <= X"44"; g <= X"55"; b <= X"33";
            when X"E" => r <= X"33"; g <= X"33"; b <= X"55";
            when X"F" => r <= X"44"; g <= X"44"; b <= X"44";
			end case;
		when "100" =>
			case index is
            when X"0" => r <= X"00"; g <= X"00"; b <= X"00";
            when X"1" => r <= X"77"; g <= X"77"; b <= X"77";
            when X"2" => r <= X"33"; g <= X"11"; b <= X"11";
            when X"3" => r <= X"44"; g <= X"66"; b <= X"66";
            when X"4" => r <= X"55"; g <= X"22"; b <= X"55";
            when X"5" => r <= X"22"; g <= X"55"; b <= X"22";
            when X"6" => r <= X"22"; g <= X"11"; b <= X"55";
            when X"7" => r <= X"55"; g <= X"66"; b <= X"22";
            when X"8" => r <= X"55"; g <= X"33"; b <= X"22";
            when X"9" => r <= X"22"; g <= X"22"; b <= X"00";
            when X"A" => r <= X"55"; g <= X"33"; b <= X"33";
            when X"B" => r <= X"22"; g <= X"22"; b <= X"22";
            when X"C" => r <= X"44"; g <= X"44"; b <= X"44";
            when X"D" => r <= X"44"; g <= X"66"; b <= X"44";
            when X"E" => r <= X"33"; g <= X"33"; b <= X"77";
            when X"F" => r <= X"55"; g <= X"55"; b <= X"55";
			end case;
		when "101" =>
			case index is
            when X"0" => r <= X"00"; g <= X"00"; b <= X"00";
            when X"1" => r <= X"77"; g <= X"77"; b <= X"77";
            when X"2" => r <= X"44"; g <= X"11"; b <= X"22";
            when X"3" => r <= X"33"; g <= X"55"; b <= X"55";
            when X"4" => r <= X"44"; g <= X"11"; b <= X"44";
            when X"5" => r <= X"22"; g <= X"55"; b <= X"22";
            when X"6" => r <= X"22"; g <= X"11"; b <= X"55";
            when X"7" => r <= X"55"; g <= X"66"; b <= X"22";
            when X"8" => r <= X"44"; g <= X"22"; b <= X"11";
            when X"9" => r <= X"22"; g <= X"22"; b <= X"00";
            when X"A" => r <= X"55"; g <= X"33"; b <= X"33";
            when X"B" => r <= X"22"; g <= X"22"; b <= X"22";
            when X"C" => r <= X"33"; g <= X"33"; b <= X"33";
            when X"D" => r <= X"44"; g <= X"66"; b <= X"44";
            when X"E" => r <= X"33"; g <= X"33"; b <= X"66";
            when X"F" => r <= X"44"; g <= X"44"; b <= X"44";
			end case;
		when "110" =>
			case index is
            when X"0" => r <= X"00"; g <= X"00"; b <= X"00";
            when X"1" => r <= X"77"; g <= X"77"; b <= X"77";
            when X"2" => r <= X"44"; g <= X"11"; b <= X"11";
            when X"3" => r <= X"33"; g <= X"55"; b <= X"55";
            when X"4" => r <= X"44"; g <= X"11"; b <= X"44";
            when X"5" => r <= X"22"; g <= X"55"; b <= X"22";
            when X"6" => r <= X"11"; g <= X"11"; b <= X"55";
            when X"7" => r <= X"66"; g <= X"66"; b <= X"22";
            when X"8" => r <= X"44"; g <= X"22"; b <= X"11";
            when X"9" => r <= X"22"; g <= X"22"; b <= X"00";
            when X"A" => r <= X"55"; g <= X"33"; b <= X"33";
            when X"B" => r <= X"22"; g <= X"22"; b <= X"22";
            when X"C" => r <= X"33"; g <= X"33"; b <= X"33";
            when X"D" => r <= X"44"; g <= X"66"; b <= X"44";
            when X"E" => r <= X"33"; g <= X"33"; b <= X"66";
            when X"F" => r <= X"44"; g <= X"44"; b <= X"44";
			end case;
		when "111" =>
			case index is
            when X"0" => r <= X"00"; g <= X"00"; b <= X"00";
            when X"1" => r <= X"77"; g <= X"77"; b <= X"77";
            when X"2" => r <= X"44"; g <= X"22"; b <= X"22";
            when X"3" => r <= X"33"; g <= X"66"; b <= X"66";
            when X"4" => r <= X"44"; g <= X"22"; b <= X"44";
            when X"5" => r <= X"33"; g <= X"55"; b <= X"22";
            when X"6" => r <= X"22"; g <= X"22"; b <= X"55";
            when X"7" => r <= X"66"; g <= X"66"; b <= X"33";
            when X"8" => r <= X"44"; g <= X"22"; b <= X"11";
            when X"9" => r <= X"22"; g <= X"22"; b <= X"00";
            when X"A" => r <= X"66"; g <= X"33"; b <= X"33";
            when X"B" => r <= X"22"; g <= X"22"; b <= X"22";
            when X"C" => r <= X"44"; g <= X"44"; b <= X"44";
            when X"D" => r <= X"55"; g <= X"77"; b <= X"55";
            when X"E" => r <= X"33"; g <= X"33"; b <= X"77";
            when X"F" => r <= X"55"; g <= X"55"; b <= X"55";
			end case;
	    when others => 
	        case index is
            when X"0" => r <= X"00"; g <= X"00"; b <= X"00";
            when X"1" => r <= X"77"; g <= X"77"; b <= X"77";
            when X"2" => r <= X"44"; g <= X"22"; b <= X"22";
            when X"3" => r <= X"33"; g <= X"66"; b <= X"66";
            when X"4" => r <= X"44"; g <= X"22"; b <= X"44";
            when X"5" => r <= X"33"; g <= X"55"; b <= X"22";
            when X"6" => r <= X"22"; g <= X"22"; b <= X"55";
            when X"7" => r <= X"66"; g <= X"66"; b <= X"33";
            when X"8" => r <= X"44"; g <= X"22"; b <= X"11";
            when X"9" => r <= X"22"; g <= X"22"; b <= X"00";
            when X"A" => r <= X"66"; g <= X"33"; b <= X"33";
            when X"B" => r <= X"22"; g <= X"22"; b <= X"22";
            when X"C" => r <= X"44"; g <= X"44"; b <= X"44";
            when X"D" => r <= X"55"; g <= X"77"; b <= X"55";
            when X"E" => r <= X"33"; g <= X"33"; b <= X"77";
            when X"F" => r <= X"55"; g <= X"55"; b <= X"55";
			end case;
		end case;
	end process;
end Behavioral;
