library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use IEEE.NUMERIC_STD.ALL;

library UNISIM;
use UNISIM.VComponents.all;

entity mem_control is
    Port (  
				clk : in  STD_LOGIC;
				
				-- micron PSRAM external signals
				micronAddr : out  STD_LOGIC_VECTOR (22 downto 0);
				micronData : inout  STD_LOGIC_VECTOR (15 downto 0);
				micronOE_n : out  STD_LOGIC;
				micronWE_n : out  STD_LOGIC;
				micronADV_n : out  STD_LOGIC;
				micronCE_n : out  STD_LOGIC;
				micronLB_n : out  STD_LOGIC;
				micronUB_n : out  STD_LOGIC;
				micronCRE : out  STD_LOGIC;
				micronClk : out  STD_LOGIC;
				micronWait : in STD_LOGIC;
				
				-- flash memory chip select (should stay deasserted)
				flashCS_n : out  STD_LOGIC;


				---------------------------------------------------------------------
				-- control interface from FPGA logic --------------------------------
				---------------------------------------------------------------------
				
				-- host must be prepared to handle the full 32-word burst
				-- before activating transfer!

				ready : out STD_LOGIC; -- asserted in idle state
				req_burst : in STD_LOGIC; -- '1' to initiate 32-word burst access
				req_rw : in STD_LOGIC; -- '1' to indicate request is read, '0' for write
				
				-- host should latch read data on rising edge of clk when data_valid is high
				read_data_valid : out STD_LOGIC;
				
				-- host should supply new write data on rising edge of clk when increment_en is high
				write_increment_en : out STD_LOGIC;
				
				-- starting address for burst access
				-- requested address must be divisible by 32
				-- will be latched at start of read/write
				req_addr : in STD_LOGIC_VECTOR (22 downto 0);
				
				-- read/write data are registered in the IO block
				req_data_write : in STD_LOGIC_VECTOR (15 downto 0);
				req_data_read : out STD_LOGIC_VECTOR (15 downto 0);
				
				-- req_done asserts for one clock cycle at the end of each burst
				req_done : out STD_LOGIC;
				
				-----------
				-- debug --
				-----------
				
				data_debug : out STD_LOGIC_VECTOR (15 downto 0)
				
				);
				
end mem_control;

architecture Behavioral of mem_control is

	-- proper design practice is to generate a synchronous local reset
	-- for state machine, since the global set/reset signal is not guaranteed
	-- to de-assert synchronously
	signal my_reset, my_reset_sync : STD_LOGIC := '1';
	attribute shreg_extract : string;
	attribute shreg_extract of my_reset_sync : signal is "NO";
	attribute maxdelay : string;
	attribute maxdelay of my_reset_sync : signal is "1.5 ns";

	-- Micron datasheet p. 29
	constant LAT_CODE : integer := 4; -- 6 for 80 MHz operation, 4 for 50 MHz

	-- configuration opcode for PSRAM bus
	-- see Micron datasheet p. 24
	-- 32 word burst, fixed latency, wait active low
	constant CONFIG_WORD : STD_LOGIC_VECTOR (22 downto 0) := "000100001"&std_logic_vector(to_unsigned(LAT_CODE, 3))&"000"&"00"&"001"&"100";

	constant BURST_LENGTH : integer := 32;
	
	-- tristate control register for data bus
	signal tri_reg : STD_LOGIC := '1';
	signal tri_next : STD_LOGIC;
	
	-- force tri_reg into the IO block
	attribute iob : string;
	attribute iob of tri_reg : signal is "TRUE";
	
	-- registers for all external signals
	
	signal OE_reg, WE_reg, CE_reg : STD_LOGIC := '1';
	signal OE_next, WE_next, CE_next : STD_LOGIC;
	signal CRE_reg : STD_LOGIC := '0'; -- config register enable
	signal CRE_next : STD_LOGIC;
	signal ready_reg : STD_LOGIC := '0';
	signal ready_next : STD_LOGIC;
	signal increment_en_reg : STD_LOGIC := '0';
	signal increment_en_next : STD_LOGIC;
	signal read_data_valid_reg : STD_LOGIC := '0';
	signal read_data_valid_next : STD_LOGIC;

	signal addr_reg : STD_LOGIC_VECTOR (22 downto 0) := CONFIG_WORD; -- addr_reg will hold CONFIG_WORD on power-up
	signal addr_en : STD_LOGIC;
	
	signal data_write_reg : STD_LOGIC_VECTOR (15 downto 0) := (others => '0'); -- FPGA to RAM data register
	signal data_write_en : STD_LOGIC;
	
	signal data_read_reg : STD_LOGIC_VECTOR (15 downto 0) := (others => '0'); -- RAM to FPGA data register
	signal data_read_en: STD_LOGIC;
	signal data_read_int : STD_LOGIC_VECTOR (15 downto 0);
	
	-- ADV_n signal must be generated from a DDR register to permit half-cycle timing
	signal adv_d0, adv_d1 : STD_LOGIC; -- D0 and D1 inputs for micronADV_n DDR register	
	
	-- main state machine
	type state_type is (start, config_1, config_2, config_3, config_4, config_5, 
								idle_0, idle, read_lat, read_data, write_lat, write_data, done);
	signal state_reg : state_type := start;
	signal state_next : state_type;
	
	-- counter for managing latency states
	signal lat_counter_reg : INTEGER range 0 to LAT_CODE := 0;
	signal lat_counter_rst, lat_counter_en: STD_LOGIC;
	
	-- counter for managing burst length
	signal data_counter_reg : INTEGER range 0 to BURST_LENGTH := 0;
	signal data_counter_rst, data_counter_en : STD_LOGIC;

	-- micronClk is generated from a DDR output register (ODDR2 primitive)
	signal clk_n : STD_LOGIC;
	signal ddr_d0_reg : STD_LOGIC := '0'; -- registering DDR inputs helps meet timing, but not strictly necessary
	signal ddr_d1_reg : STD_LOGIC := '0'; -- D0:D1:EN = "101" for in-phase clock, "011" for inverted clock
	signal ddr_en_reg : STD_LOGIC := '0'; -- D0:D1:EN = "001" for 1 cycle to idle outputs low
	signal ddr_d0_next, ddr_d1_next, ddr_en_next : STD_LOGIC;
	signal ddr_out : STD_LOGIC;


begin

----------------------------
-- Tie off unused signals --
----------------------------

micronLB_n <= '0';
micronUB_n <= '0';
flashCS_n <= '1';


---------------------------------------------------------------------------------
-- Bidirectional data bus to RAM ------------------------------------------------
---------------------------------------------------------------------------------

--micronData <= data_write_reg when tri_reg = '0' else (others => 'Z');

data_iobuf_array :
for k in 15 downto 0 generate
	data_iobuf : IOBUF
	port map (
		O => data_read_int(k),
		IO => micronData(k),
		I => data_write_reg(k),
		T => tri_reg );
end generate data_iobuf_array;

process(clk)
begin
	if rising_edge(clk) then
		if data_read_en = '1' then
			data_read_reg <= data_read_int;
		end if;
		if data_write_en = '1' then
			data_write_reg <= req_data_write;
		end if;
		tri_reg <= tri_next;
	end if;
end process;

-----------
-- debug --
-----------

data_debug <= data_read_int;

---------------------------------------------------------------------------------
-- Address bus ------------------------------------------------------------------
---------------------------------------------------------------------------------

process(clk, addr_en)
begin
	if rising_edge(clk) then
		if addr_en = '1' then
			addr_reg <= req_addr;
		end if;
	end if;
end process;


---------------------------------------------------------------------------------
-- IO Registers -----------------------------------------------------------------
---------------------------------------------------------------------------------

process(clk)
begin
	if rising_edge(clk) then
		OE_reg <= OE_next;
		WE_reg <= WE_next;
		CE_reg <= CE_next;
		CRE_reg <= CRE_next;
		ready_reg <= ready_next;
		increment_en_reg <= increment_en_next;
		read_data_valid_reg <= read_data_valid_next;
	end if;
end process;

-- ADV must be generated from a DDR register to enable half-cycle timing
-- D0:D1 = "11" -> "00" -> "11" to generate out-of-phase pulse
-- D0:D1 = "11" -> "01" -> "10" -> "11" to generate in-phase pulse

ADV_output : ODDR2
port map (
			Q => micronADV_n,
			C0 => clk,
			C1 => clk_n,
			CE => '1',
			D0 => adv_d0,
			D1 => adv_d1,
			R => '0',
			S => '0'
			);


---------------------------------------------------------------------------------
-- Clock output using DDR registers ---------------------------------------------
---------------------------------------------------------------------------------

clk_n <= not clk;

ODDR2_clockgen : ODDR2
port map (
			Q => ddr_out, -- clock output to PSRAM
			C0 => clk, -- global 50 MHz clock
			C1 => clk_n,
			CE => ddr_en_reg,
			D0 => ddr_d0_reg, -- 1-bit data input (associated with C0); D0='1' and D1='0' for normal clock output
			D1 => ddr_d1_reg, -- 1-bit data input (associated with C1); D0='0' and D1='1' for inverted clock
			R => '0', -- 1-bit reset input
			S => '0' -- 1-bit set input
			);

-- registering DDR inputs helps meet timing, but not strictly necessary

process(clk)
begin
	if rising_edge(clk) then
		ddr_d0_reg <= ddr_d0_next;
		ddr_d1_reg <= ddr_d1_next;
		ddr_en_reg <= ddr_en_next;
	end if;
end process;


micronClk <= ddr_out;


---------------------------------------------------------------------------------
-- Main state machine -----------------------------------------------------------
---------------------------------------------------------------------------------

-- generate synchronous reset signal
process(clk)
begin
	if rising_edge(clk) then
		my_reset_sync <= '0';
		my_reset <= my_reset_sync;
	end if;
end process;


-- state register
process(clk)
begin
	if rising_edge(clk) then
		if my_reset = '1' then
			state_reg <= start;
		else
			state_reg <= state_next;
		end if;
	end if;
end process;


-- counter registers
process(clk)
begin
	if rising_edge(clk) then
	
		-- latency counter
		if lat_counter_rst = '1' then
			lat_counter_reg <= 0;
		elsif lat_counter_en = '1' then
			lat_counter_reg <= lat_counter_reg + 1;
		end if;
		
		-- burst length counter
		if data_counter_rst = '1' then
			data_counter_reg <= 0;
		elsif data_counter_en = '1' then
			data_counter_reg <= data_counter_reg + 1;
		end if;
		
	end if;
end process;


-- next state logic & unregistered state machine outputs
process(state_reg, lat_counter_reg, data_counter_reg, req_burst, req_rw, micronWait)
begin

	-- defaults
	state_next <= state_reg;
	data_read_en <= '0';
	data_write_en <= '0';
	addr_en <= '0';
	lat_counter_rst <= '0';
	lat_counter_en <= '0';
	data_counter_rst <= '0';
	data_counter_en <= '0';
	adv_d0 <= '1';
	adv_d1 <= '1';
	req_done <= '0'; -- this will actually be a registered output if FSM encoding is one-hot
	read_data_valid_next <= '0'; -- another registered output has snuck in here somehow!
	
	case state_reg is
	
		when start =>
			state_next <= config_1;
		when config_1 =>
			state_next <= config_2;
			adv_d0 <= '0';
			adv_d1 <= '0';
		when config_2 =>
			lat_counter_rst <= '1';
			state_next <= config_3;
		when config_3 =>
			lat_counter_en <= '1';
			if lat_counter_reg = LAT_CODE - 1 then
				state_next <= config_4;
			else
				state_next <= config_3;
			end if;			
		when config_4 =>
			lat_counter_rst <= '1';
			state_next <= config_5;
		when config_5 =>
			lat_counter_en <= '1';
			adv_d0 <= '0';
			adv_d1 <= '0';
			if lat_counter_reg = LAT_CODE then
				state_next <= idle_0;
			else
				state_next <= config_5;
			end if;
		when idle_0 =>
			state_next <= idle;
		when idle =>
			lat_counter_rst <= '1';
			data_counter_rst <= '1';			
			if req_burst = '1' and req_rw = '1' then
				state_next <= read_lat;
				addr_en <= '1'; -- latch req_addr onto the external address bus
			elsif req_burst = '1' and req_rw = '0' then
				state_next <= write_lat;
				addr_en <= '1'; -- latch req_addr onto the external address bus
				adv_d0 <= '0';
			else
				state_next <= idle;
			end if;

		when read_lat =>
			lat_counter_en <= '1';
			if lat_counter_reg = 0 then -- use DDR register to generate ADV strobe
				adv_d0 <= '0';
				adv_d1 <= '0';
			elsif lat_counter_reg = LAT_CODE then
				data_counter_en <= '1';
				state_next <= read_data;
			else
				state_next <= read_lat;
			end if;
		when read_data =>
			data_read_en <= '1';
			data_counter_en <= '1';
			read_data_valid_next <= micronWait;
			if data_counter_reg = BURST_LENGTH then
				state_next <= done;
			else
				state_next <= read_data;
			end if;
		when done =>
			state_next <= idle_0;
			req_done <= '1';

		when write_lat =>
			lat_counter_en <= '1';
			if lat_counter_reg = 0 then
				adv_d0 <= '1';
				adv_d1 <= '0';
			elsif lat_counter_reg = LAT_CODE then
				data_counter_en <= '1';
				data_write_en <= '1'; -- latch req_write_data onto external data bus
				state_next <= write_data;
			else
				state_next <= write_lat;
			end if;
		when write_data =>
			data_counter_en <= '1';
			data_write_en <= '1'; -- latch req_write_data onto external data bus
			if data_counter_reg = BURST_LENGTH then
				state_next <= done;
			else
				state_next <= write_data;
			end if;

		when others =>
			null;
				
	end case;

end process;

-- look-ahead logic for registered outputs
process(state_next, lat_counter_reg, data_counter_reg)
begin

	-- defaults
	OE_next <= '1';
	WE_next <= '1';
	CE_next <= '1';
	CRE_next <= '0';
	tri_next <= '1';
	ready_next <= '0';
	increment_en_next <= '0';
	ddr_d0_next <= '0';
	ddr_d1_next <= '0';
	ddr_en_next <= '0';
	
	case state_next is
		
		when config_1 =>
			CRE_next <= '1';
			CE_next <= '0';
		when config_2 =>
			CRE_next <= '1';
			CE_next <= '0';
		when config_3 =>
			CRE_next <= '1';
			CE_next <= '0';
			WE_next <= '0';
		when config_4 =>
			CRE_next <= '0';
			CE_next <= '1';
			WE_next <= '1';
		when config_5 =>
			CE_next <= '0';
			OE_next <= '0';
		when idle_0 =>
			ready_next <= '1';
		when idle =>
			ready_next <= '1';

		when read_lat =>
			ddr_d0_next <= '1';
			ddr_d1_next <= '0';
			ddr_en_next <= '1';
			CE_next <= '0';
			OE_next <= '0';
		when read_data =>
			ddr_d0_next <= '1';
			ddr_d1_next <= '0';
			ddr_en_next <= '1';
			CE_next <= '0';
			OE_next <= '0';
		when done =>
			ddr_d0_next <= '0';
			ddr_d1_next <= '0';
			ddr_en_next <= '1';
			CE_next <= '0';
		
		when write_lat =>
			ddr_d0_next <= '0';
			ddr_d1_next <= '1';
			ddr_en_next <= '1';
			CE_next <= '0';
			WE_next <= '0';
			tri_next <= '0';
			if lat_counter_reg = LAT_CODE - 1 then
				increment_en_next <= '1';
			else
				increment_en_next <= '0';
			end if;
		when write_data =>
			ddr_d0_next <= '0';
			ddr_d1_next <= '1';
			ddr_en_next <= '1';
			CE_next <= '0';
			WE_next <= '0';
			tri_next <= '0';
			if data_counter_reg = BURST_LENGTH - 1 then
				increment_en_next <= '0';
			else
				increment_en_next <= '1';
			end if;
		
		when others =>
			null;
			
	end case;
	
end process;

---------------------
-- Port connections
---------------------

micronAddr <= addr_reg;
micronOE_n <= OE_reg;
micronWE_n <= WE_reg;
micronCE_n <= CE_reg;
micronCRE <= CRE_reg;

ready <= ready_reg;
req_data_read <= data_read_reg;
write_increment_en <= increment_en_reg;
read_data_valid <= read_data_valid_reg;

end Behavioral;

