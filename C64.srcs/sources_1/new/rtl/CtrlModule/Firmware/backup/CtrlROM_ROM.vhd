-- ZPU
--
-- Copyright 2004-2008 oharboe - �yvind Harboe - oyvind.harboe@zylin.com
-- Modified by Alastair M. Robinson for the ZPUFlex project.
--
-- The FreeBSD license
-- 
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions
-- are met:
-- 
-- 1. Redistributions of source code must retain the above copyright
--    notice, this list of conditions and the following disclaimer.
-- 2. Redistributions in binary form must reproduce the above
--    copyright notice, this list of conditions and the following
--    disclaimer in the documentation and/or other materials
--    provided with the distribution.
-- 
-- THIS SOFTWARE IS PROVIDED BY THE ZPU PROJECT ``AS IS'' AND ANY
-- EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
-- THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
-- PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
-- ZPU PROJECT OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
-- INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
-- (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
-- OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
-- HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
-- STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
-- ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
-- 
-- The views and conclusions contained in the software and documentation
-- are those of the authors and should not be interpreted as representing
-- official policies, either expressed or implied, of the ZPU Project.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


library work;
use work.zpupkg.all;

entity CtrlROM_ROM is
generic
	(
		maxAddrBitBRAM : integer := maxAddrBitBRAMLimit -- Specify your actual ROM size to save LEs and unnecessary block RAM usage.
	);
port (
	clk : in std_logic;
	areset : in std_logic := '0';
	from_zpu : in ZPU_ToROM;
	to_zpu : out ZPU_FromROM
);
end CtrlROM_ROM;

architecture arch of CtrlROM_ROM is

type ram_type is array(natural range 0 to ((2**(maxAddrBitBRAM+1))/4)-1) of std_logic_vector(wordSize-1 downto 0);

shared variable ram : ram_type :=
(
     0 => x"0b0b0b0b",
     1 => x"8c0b0b0b",
     2 => x"0b80e004",
     3 => x"0b0b0b0b",
     4 => x"8c04ff0d",
     5 => x"80040400",
     6 => x"00000016",
     7 => x"00000000",
     8 => x"0b0b0b85",
     9 => x"9c080b0b",
    10 => x"0b85a008",
    11 => x"0b0b0b85",
    12 => x"a4080b0b",
    13 => x"0b0b9808",
    14 => x"2d0b0b0b",
    15 => x"85a40c0b",
    16 => x"0b0b85a0",
    17 => x"0c0b0b0b",
    18 => x"859c0c04",
    19 => x"00000000",
    20 => x"00000000",
    21 => x"00000000",
    22 => x"00000000",
    23 => x"00000000",
    24 => x"859c7080",
    25 => x"c5ac278e",
    26 => x"38807170",
    27 => x"8405530c",
    28 => x"0b0b0b80",
    29 => x"e2048c51",
    30 => x"84ef04f6",
    31 => x"8408859c",
    32 => x"0c048598",
    33 => x"08859c0c",
    34 => x"0402fc05",
    35 => x"0d807085",
    36 => x"980c70f6",
    37 => x"800c859c",
    38 => x"0c028405",
    39 => x"0d0402f4",
    40 => x"050d7453",
    41 => x"81822d85",
    42 => x"9c08810a",
    43 => x"07707407",
    44 => x"52527588",
    45 => x"38720970",
    46 => x"73065151",
    47 => x"7085980c",
    48 => x"70f6800c",
    49 => x"028c050d",
    50 => x"0402f805",
    51 => x"0d028e05",
    52 => x"22518182",
    53 => x"2d859c08",
    54 => x"f4808006",
    55 => x"710770f6",
    56 => x"800c7088",
    57 => x"80800770",
    58 => x"85980cf6",
    59 => x"800c5280",
    60 => x"fb2d800b",
    61 => x"859c0824",
    62 => x"a238859c",
    63 => x"08912a70",
    64 => x"81065151",
    65 => x"70802ee7",
    66 => x"38718598",
    67 => x"0c71f680",
    68 => x"0c80fb2d",
    69 => x"859c0880",
    70 => x"25863880",
    71 => x"5182b504",
    72 => x"859c0891",
    73 => x"2a708106",
    74 => x"515170e5",
    75 => x"38859c08",
    76 => x"83ffff06",
    77 => x"5170859c",
    78 => x"0c028805",
    79 => x"0d0402ec",
    80 => x"050d8594",
    81 => x"08830653",
    82 => x"72863883",
    83 => x"0b85940c",
    84 => x"80f08080",
    85 => x"0b859408",
    86 => x"70810655",
    87 => x"55557280",
    88 => x"2e8538b0",
    89 => x"800a5573",
    90 => x"812a7081",
    91 => x"06515372",
    92 => x"802e8738",
    93 => x"74efff0a",
    94 => x"06558152",
    95 => x"7451819e",
    96 => x"2d029405",
    97 => x"0d0402f8",
    98 => x"050d8052",
    99 => x"80f08080",
   100 => x"51819e2d",
   101 => x"0288050d",
   102 => x"0402f805",
   103 => x"0d028f05",
   104 => x"335282be",
   105 => x"2d715181",
   106 => x"c92d0288",
   107 => x"050d0402",
   108 => x"fc050d02",
   109 => x"8b053351",
   110 => x"83992d83",
   111 => x"862d0284",
   112 => x"050d0402",
   113 => x"f0050d75",
   114 => x"77535377",
   115 => x"802eb038",
   116 => x"7272812a",
   117 => x"ff055454",
   118 => x"72ff2e91",
   119 => x"38737082",
   120 => x"05552251",
   121 => x"81c92dff",
   122 => x"135383d8",
   123 => x"04718106",
   124 => x"5271802e",
   125 => x"9f387333",
   126 => x"5181c92d",
   127 => x"849404ff",
   128 => x"125271ff",
   129 => x"2e8e3872",
   130 => x"70810554",
   131 => x"335181c9",
   132 => x"2d83ff04",
   133 => x"0290050d",
   134 => x"0402e405",
   135 => x"0d859008",
   136 => x"57805574",
   137 => x"7725bb38",
   138 => x"85ac560b",
   139 => x"0b0b858c",
   140 => x"08752c70",
   141 => x"81065154",
   142 => x"73802e9a",
   143 => x"3874a007",
   144 => x"7081ff06",
   145 => x"52548399",
   146 => x"2d805382",
   147 => x"80527551",
   148 => x"83c32d83",
   149 => x"862d8115",
   150 => x"82801757",
   151 => x"55767524",
   152 => x"ca38800b",
   153 => x"0b0b0b85",
   154 => x"8c0c029c",
   155 => x"050d0402",
   156 => x"fc050d81",
   157 => x"892d80c1",
   158 => x"5183af2d",
   159 => x"ff0b0b0b",
   160 => x"0b858c0c",
   161 => x"84992d85",
   162 => x"84040000",
   163 => x"00000000",
   164 => x"00000008",
   165 => x"00000003",
   166 => x"00000000",
	others => x"00000000"
);

begin

process (clk)
begin
	if (clk'event and clk = '1') then
		if (from_zpu.memAWriteEnable = '1') and (from_zpu.memBWriteEnable = '1') and (from_zpu.memAAddr=from_zpu.memBAddr) and (from_zpu.memAWrite/=from_zpu.memBWrite) then
			report "write collision" severity failure;
		end if;
	
		if (from_zpu.memAWriteEnable = '1') then
			ram(to_integer(unsigned(from_zpu.memAAddr(maxAddrBitBRAM downto 2)))) := from_zpu.memAWrite;
			to_zpu.memARead <= from_zpu.memAWrite;
		else
			to_zpu.memARead <= ram(to_integer(unsigned(from_zpu.memAAddr(maxAddrBitBRAM downto 2))));
		end if;
	end if;
end process;

process (clk)
begin
	if (clk'event and clk = '1') then
		if (from_zpu.memBWriteEnable = '1') then
			ram(to_integer(unsigned(from_zpu.memBAddr(maxAddrBitBRAM downto 2)))) := from_zpu.memBWrite;
			to_zpu.memBRead <= from_zpu.memBWrite;
		else
			to_zpu.memBRead <= ram(to_integer(unsigned(from_zpu.memBAddr(maxAddrBitBRAM downto 2))));
		end if;
	end if;
end process;


end arch;

