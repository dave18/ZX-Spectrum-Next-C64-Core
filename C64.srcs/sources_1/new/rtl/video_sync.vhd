---------------------------------------------------------------------------------
-- composite_sync by Dar (darfpga@aol.fr)
-- http://darfpga.blogspot.fr
--
-- Generate composite sync and blank for tv mode from h/v syncs
--
---------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;

entity video_sync is
port(
	clk32 : in std_logic;
	pause : in std_logic;
	hsync : in std_logic;
	vsync : in std_logic;
	ntsc  : in std_logic;
	wide  : in std_logic;
	hsync_out : out std_logic;
	vsync_out : out std_logic;
	hblank : out std_logic;
	vblank : out std_logic;
	csync : out std_logic;
	tv_disp : out std_logic
);
end;

architecture struct of video_sync is

	signal clk_cnt : std_logic_vector(1 downto 0);
	signal vsync_r : std_logic;
	signal hsync_r : std_logic;
	signal hsync_r0 : std_logic;
	signal state :std_logic_vector(1 downto 0); 

begin

process(clk32)
	variable  dot_count : integer range 0 to 1023 := 0;
	variable line_count : integer range 0 to 511 := 0;
	variable line_reset : std_logic := '0';
	begin
	if falling_edge(clk32) then
		hsync_r0 <= hsync;
		if hsync_r0 = '0' and hsync = '1' then
			clk_cnt <= "11";
		else
			clk_cnt <= clk_cnt + '1';
		end if;
	end if;

	if rising_edge(clk32) then
		if clk_cnt = "00" and pause = '0' then
			vsync_r <= vsync;
			hsync_r <= hsync;

			if hsync_r = '0' and hsync = '1' then
				dot_count := 0;
				if line_reset = '1' then
					line_count := 0;
					line_reset := '0';
					state<="00";
				else
					line_count := line_count + 1;
				end if;
			else
				dot_count := dot_count + 1;
			end if;

			if vsync_r = '0' and vsync = '1' then
				line_reset := '1';
			end if;
			
			
			
			if ntsc = '1' then
				if dot_count     = 054 then hsync_out <= '0'; end if;
				if dot_count     = 016 then hsync_out <= '1';
					if line_count = 000 then vsync_out <= '1'; end if;
					if line_count = 004 then vsync_out <= '0'; end if;
				end if;

				if line_count = 000 then vblank <= '1'; end if;
				if line_count = 013 then vblank <= '0'; end if;
				
				if line_count = 253+5 then state<="01"; end if;
				if line_count = 256+5 then state<="10"; end if;
				if line_count = 256+5 and dot_count=450 then state<="11"; end if;

				if wide = '0' then
					if dot_count  = 516 then hblank <= '1'; end if;
					if dot_count  = 112 then hblank <= '0'; end if;
				else
					if dot_count  = 496 then hblank <= '1'; end if;
					if dot_count  = 132 then hblank <= '0'; end if;
				end if;
			else --pal
				if dot_count     = 048 then hsync_out <= '0'; end if;
				if dot_count     = 010 then hsync_out <= '1';
					if line_count = 307 then vsync_out <= '1'; end if;
					if line_count = 311 then vsync_out <= '0'; end if;
				end if;

				if line_count = 298 then vblank <= '1'; end if;
				if line_count = 028 then vblank <= '0'; end if;
				if line_count = 303 then state<="01"; end if;
				if line_count = 306 then state<="10"; end if;
				if line_count = 306 and dot_count=450 then state<="11"; end if;

				if wide = '0' then
					if dot_count  = 489 then hblank <= '1'; end if;
					if dot_count  = 107 then hblank <= '0'; end if;
				else
					if dot_count  = 463 then hblank <= '1'; end if;
					if dot_count  = 133 then hblank <= '0'; end if;
				end if;
			end if;

		end if;
	end if;
	
	case state is
    when "00" =>
        if (dot_count<52 and ntsc='0') or (dot_count<68 and ntsc='1') then
        --if dot_count<32 then
            csync<='1';
        else
            csync<='0';
        end if;
        if ntsc='1' then
            if dot_count>=112 and dot_count<112+404 and line_count>=20 and line_count<20+272 then
                tv_disp<='1';
            else
                tv_disp<='0';
            end if;
        else
            if dot_count>=107 and dot_count<107+384 and line_count>=20 and line_count<20+272 then
                tv_disp<='1';
            else
                tv_disp<='0';
            end if;
        end if;

    when "01" =>
        if dot_count<16 or (dot_count>=236 and dot_count<252+28) then
            csync<='1';
        else
            csync<='0';
        end if;
        tv_disp<='0';
    when "10" =>
        if dot_count<236 or (dot_count>=252 and dot_count<252+236) then
            csync<='1';
        else
            csync<='0';
        end if;
        tv_disp<='0';        
    when others=>
        null;
    end case;
end process;


end architecture;