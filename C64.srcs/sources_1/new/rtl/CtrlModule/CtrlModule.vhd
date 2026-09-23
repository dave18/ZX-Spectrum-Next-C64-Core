library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;

library work;
use work.zpupkg.ALL;

entity CtrlModule is
	generic (
		sysclk_frequency : integer := 315 -- 430 --215 --(21.477) -- 1000 -- 575 -- Sysclk frequency * 10 
	);
	port (
		clk 			: in std_logic;
		reset_n 	: in std_logic;

		-- signals for OSD		
		osd_din : out std_logic_vector (15 downto 0);
		osd_dout : in std_logic_vector (15 downto 0);
		osd_addr : out std_logic_vector (9 downto 0);
		osd_we : out std_logic;
		
		--Control bits
		osd_ctrl:in std_logic_vector (31 downto 0);
		osd_ctrl_out:out std_logic_vector (31 downto 0);

		-- PS/2 keyboard
		--ps2k_clk_in : in std_logic := '1';
		--ps2k_dat_in : in std_logic := '1';
		ps2_key:in std_logic_vector (20 downto 0);
		--joysticks:in std_logic_vector (9 downto 0);

		-- SD card interface
		spi_miso		: in std_logic := '1';
		spi_mosi		: out std_logic;
		spi_clk		: out std_logic;
		spi_cs 		: out std_logic;
		
		--IOCTL
		ioctl_download    : out std_logic:='0';
		ioctl_addr    : out std_logic_vector(20 downto 0);
		ioctl_index    : out std_logic_vector(7 downto 0);
		ioctl_wr    : out std_logic;
		ioctl_dout    : out std_logic_vector(7 downto 0);
		ioctl_wait    : in std_logic;
		
		--Status bits
		status    : out std_logic_vector(95 downto 0);
	--	cfg_debug    : in std_logic_vector(31 downto 0);
		

		-- DIP switches
		dipswitches : out std_logic_vector(15 downto 0);
		size : out std_logic_vector(31 downto 0);
		
		--joystick pins
		joy_pins : in std_logic_vector(6 downto 0);

		-- Host control signals
		host_divert_sdcard : out std_logic;
		host_divert_keyboard : out std_logic;
		host_reset_n : out std_logic;
		host_reset_loader : out std_logic;
		host_select : out std_logic;
		host_start : out std_logic;
		host_master_reset : out std_logic := '0';
		
		
		
		-- Boot upload signals
		host_bootdata : out std_logic_vector(31 downto 0);
		host_bootdata_req : out std_logic;
		host_bootdata_ack : in std_logic :='0'
	);
end entity;

architecture rtl of CtrlModule is

-- ZPU signals
constant maxAddrBit : integer := 20; -- Optional - defaults to 32 - but helps keep the logic element count down.
signal reset           : std_logic;
signal mem_busy           : std_logic;
signal mem_read             : std_logic_vector(wordSize-1 downto 0);
signal mem_write            : std_logic_vector(wordSize-1 downto 0);
signal mem_addr             : std_logic_vector(maxAddrBit downto 0);
signal mem_writeEnable      : std_logic; 
signal mem_readEnable       : std_logic;
signal mem_hEnable      : std_logic; 
signal mem_bEnable      : std_logic; 

signal zpu_to_rom : ZPU_ToROM;
signal zpu_from_rom : ZPU_FromROM;


-- OSD related signals


signal vblank : std_logic;


-- PS/2 related signals

signal ps2_int : std_logic;

signal kbdrecv : std_logic;
signal kbdrecvreg : std_logic;
signal kbdrecvbyte : std_logic_vector(10 downto 0);


-- Interrupt signals

constant int_max : integer := 2;
signal int_triggers : std_logic_vector(int_max downto 0);
signal int_status : std_logic_vector(int_max downto 0);
signal int_ack : std_logic;
signal int_req : std_logic;
signal int_enabled : std_logic :='0'; -- Disabled by default


-- SPI Clock counter
signal spi_tick : unsigned(6 downto 0);
signal spiclk_in : std_logic;
signal spi_fast : std_logic;

-- SPI signals
signal host_to_spi : std_logic_vector(7 downto 0);
signal spi_to_host : std_logic_vector(7 downto 0);
signal spi_trigger : std_logic;
signal spi_busy : std_logic;
signal spi_active : std_logic;



begin
reset <= not reset_n;
-- ROM

	myrom : entity work.CtrlROM_ROM
	generic map
	(
		maxAddrBitBRAM => 14
	)
	port map (
		clk => clk,
		from_zpu => zpu_to_rom,
		to_zpu => zpu_from_rom
	);

	
-- Main CPU
-- We instantiate the CPU with the optional instructions enabled, which allows us to reduce
-- the size of the ROM by leaving out emulation code.
	zpu: zpu_core_flex
	generic map (
		IMPL_MULTIPLY => true,
		IMPL_COMPARISON_SUB => true,
		IMPL_EQBRANCH => true,
		IMPL_STOREBH => true,
		IMPL_LOADBH => true,
		IMPL_CALL => true,
		IMPL_SHIFT => true,
		IMPL_XOR => true,
		CACHE => true,	-- Modest speed-up when running from ROM
--		IMPL_EMULATION => minimal, -- Emulate only byte/halfword accesses, with alternateive emulation table
		REMAP_STACK => false, -- We're not using SDRAM so no need to remap the Boot ROM / Stack RAM
		EXECUTE_RAM => false, -- We don't need to execute code from external RAM.
		maxAddrBit => maxAddrBit,
		maxAddrBitBRAM => 14
	)
	port map (
		clk                 => clk,
		reset               => reset,
		in_mem_busy         => mem_busy,
		mem_read            => mem_read,
		mem_write           => mem_write,
		out_mem_addr        => mem_addr,
		out_mem_writeEnable => mem_writeEnable,
		out_mem_hEnable     => mem_hEnable,
		out_mem_bEnable     => mem_bEnable,
		out_mem_readEnable  => mem_readEnable,
		from_rom => zpu_from_rom,
		to_rom => zpu_to_rom,
		interrupt => int_req
	);



-- SPI Timer
process(clk)
begin
	if rising_edge(clk) then
		spiclk_in<='0';
		spi_tick<=spi_tick+1;
		if (spi_fast='1' and spi_tick=x"20") or spi_tick=x"4e" then
			spiclk_in<='1'; -- Momentary pulse for SPI host.
			spi_tick<='0'&'0'&'0'&X"0";
		end if;
	end if;
end process;


-- SD Card host

spi : entity work.spi_interface
	port map(
		sysclk => clk,
		reset => reset_n,

		-- Host interface
		spiclk_in => spiclk_in,
		host_to_spi => host_to_spi,
		spi_to_host => spi_to_host,
		trigger => spi_trigger,
		busy => spi_busy,

		-- Hardware interface
		miso => spi_miso,
		mosi => spi_mosi,
		spiclk_out => spi_clk
	);

		
-- Interrupt controller

intcontroller: entity work.interrupt_controller
generic map (
	max_int => int_max
)
port map (
	clk => clk,
	reset_n => reset_n,
	enable => int_enabled,
	trigger => int_triggers,
	ack => int_ack,
	int => int_req,
	status => int_status
);

int_triggers<=(0=>kbdrecv,
					1=>vblank,
					others => '0');
	
process(clk,reset_n)
begin
	if reset_n='0' then
		int_enabled<='0';
		kbdrecvreg <='0';
		host_reset_n <='0';
		host_reset_loader <='0';
		host_bootdata_req<='0';
		spi_active<='0';
		spi_cs<='1';
	elsif rising_edge(clk) then
		mem_busy<='1';		
		osd_we<='0';
		int_ack<='0';
		spi_trigger<='0';
		ioctl_wr<='0';

		-- Write from CPU?
		
		if mem_writeEnable='1' then
			case mem_addr(maxAddrBit)&mem_addr(10 downto 8) is
				when X"B" =>	-- OSD controller at 0xFFFFFB00
					osd_ctrl_out<=mem_write(31 downto 0);
					mem_busy<='0';
				when X"C" =>	-- OSD controller at 0xFFFFFC00 & 0xFFFFFC00
					osd_we<='1';
					osd_addr<=mem_write(25 downto 16);
					osd_din<=mem_write(15 downto 0);			
					mem_busy<='0';
				when X"D" =>	-- OSD controller at 0xFFFFFC00 & 0xFFFFFD00
					osd_addr<=mem_write(9 downto 0);
					mem_busy<='0';

				when X"F" =>	-- Peripherals at 0xFFFFFF00
					case mem_addr(7 downto 0) is

--						when X"B0" => -- Interrupts
--							int_enabled<=mem_write(0);
--							mem_busy<='0';

						when X"D0" => -- SPI CS
							spi_cs<=not mem_write(0);
							spi_fast<=mem_write(8);
							mem_busy<='0';

						when X"D4" => -- SPI Data (blocking)
							spi_trigger<='1';
							host_to_spi<=mem_write(7 downto 0);
							spi_active<='1';
                        --IOCTL
						when X"D8" => -- IOCTL DOWNLOAD
							ioctl_download<=mem_write(0);
							mem_busy<='0';
						when X"DC" => -- IOCTL ADDR
							ioctl_addr<=mem_write(20 downto 0);
							mem_busy<='0';
						when X"E0" => -- IOCTL INDEX
							ioctl_index<=mem_write(7 downto 0);
							mem_busy<='0';
						when X"E4" => -- IOCTL WR STROBE
							ioctl_wr<=mem_write(0);
							mem_busy<='0';
						when X"E8" => -- IOCTL DOUT
							ioctl_dout<=mem_write(7 downto 0);
							mem_busy<='0';

--						when X"EC" => -- Host control
--							mem_busy<='0';
--							host_reset_n<=not mem_write(0);
--							host_divert_keyboard<=mem_write(1);
--							host_divert_sdcard<=mem_write(2);
--							host_select<=mem_write(3);
--							host_start<=mem_write(4);
--							host_reset_loader <=mem_write(5);
--							host_master_reset <=mem_write(6);

                        when X"F0" => -- Status 0
							status(31 downto 0)<=mem_write;
							mem_busy<='0';
							
						when X"F4" => -- Status 1
							status(63 downto 32)<=mem_write;
							mem_busy<='0';
							
						when X"F8" => -- Status 2
							status(95 downto 64)<=mem_write;
							mem_busy<='0';
							
----						when X"F4" => -- Scale Green
----							mem_busy<='0';
----							scalegreen<=unsigned(mem_write(4 downto 0));
							
--						when X"F8" => -- ROM Size
--							mem_busy<='0';
--							size<=mem_write(31 downto 0);
							
--						when X"FC" => -- Host SW
--							mem_busy<='0';
--							dipswitches<=mem_write(15 downto 0);

						when others =>
							mem_busy<='0';
							null;
					end case;
				when others =>
					mem_busy<='0';
			end case;

		-- Read from CPU?
		elsif mem_readEnable='1' then
			case mem_addr(maxAddrBit)&mem_addr(10 downto 8) is
				when X"B" =>	-- OSD registers
					--mem_read(31 downto 16)<=(others => '0');
					mem_read<=osd_ctrl;
					mem_busy<='0';
				when X"C" =>	-- OSD char buffer at 0xFFFFFC00
					mem_read(31 downto 16)<=(others => '0'); 					
					mem_read(15 downto 0)<=osd_dout;
					mem_busy<='0';			
				when X"E" =>	-- Read from PS/2 regs
					--mem_read<=(others =>'X');
					mem_read(31 downto 21)<=(others => '0');
					mem_read(20 downto 0)<=ps2_key;					
--					kbdrecvreg<='0';
					mem_busy<='0';	
				when X"F" =>	-- Peripherals
					case mem_addr(7 downto 0) is
	
--						when X"90" => -- Joysticks
--							mem_read<=(others=>'X');
--							mem_read(15 downto 0)<=joysticks;
--							mem_busy<='0';
	
					
--						when X"B0" => -- Read from Interrupt status register
----							mem_read<=(others=>'X');
----							mem_read(int_max downto 0)<=int_status;
----							int_ack<='1';
--                            mem_read<=cfg_debug;
--							mem_busy<='0';

						when X"D0" => -- SPI Status
							mem_read<=(others=>'X');
							mem_read(15)<=spi_busy;
							mem_busy<='0';

						when X"D4" => -- SPI read (blocking)
							spi_active<='1';
							
						--IOCTL
						when X"D8" => -- IOCTL UPLOAD Request
							mem_read<=(others =>'X');
							--mem_read(0)<=ioctl_upload_req;
							mem_busy<='0';
							
						when X"DC" => -- IOCTL Data In
							mem_read<=(others =>'X');
							--mem_read(7 downto 0)<=ioctl_din;
							mem_busy<='0';
							
						when X"E0" => -- IOCTL Wait
						    mem_read<=(others =>'X');
							mem_read(0)<=ioctl_wait;
							mem_busy<='0';																				

						when others =>
							mem_busy<='0';
							null;
					end case;

				when others => -- SDRAM
					mem_busy<='0';
			end case;
		end if;

		-- Boot data termination - allow CPU to proceed once boot data is acknowleged:
--		if host_bootdata_ack='1' then
--			mem_busy<='0';
--			host_bootdata_req<='0';
--		end if;

		
		-- SPI cycle termination
		if spi_active='1' and spi_busy='0' then
			mem_read(7 downto 0)<=spi_to_host;
			mem_read(31 downto 8)<=(others => '0');
			spi_active<='0';
			mem_busy<='0';
		end if;
		

--		if kbdrecv='1' then
--			kbdrecvreg <= '1'; -- remains high until cleared by a read
--		end if;
		
	end if; -- rising-edge(clk)

end process;
	
end architecture;
