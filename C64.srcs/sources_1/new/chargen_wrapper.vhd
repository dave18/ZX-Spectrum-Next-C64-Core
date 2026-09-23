----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 07.09.2026 18:23:27
-- Design Name: 
-- Module Name: chargen_wrapper - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity chargen_wrapper is
  Port (
    clk: in std_logic;
    address: in std_logic_vector(11 downto 0);
    dout: out std_logic_vector(7 downto 0)
   );
end chargen_wrapper;

architecture Behavioral of chargen_wrapper is

begin

	chargen: entity work.dprom
	--generic map ("rtl/roms/chargen.mif", 12)
	generic map ("D:/Source/FPGA/SpecNext_Issue_4/C64/C64.srcs/sources_1/new/rtl/roms/chargen.hex",12)
	port map
	(
		wrclock => clk,
		rdclock => clk,

		rdaddress => address,
		q => dout
	);

end Behavioral;
