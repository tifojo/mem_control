library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use IEEE.NUMERIC_STD.ALL;

library UNISIM;
use UNISIM.VComponents.all;

entity mem_control is
    Port (  -- global system clock (50 MHz)
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
				
				-- flash memory chip select (should stay deasserted)
				flashCS_n : out  STD_LOGIC;

				-------------------------------
				-- control IO from FPGA logic
				-------------------------------
				
				-- host must be prepared to handle the full 128 word burst
				-- before activating transfer!

				ready : out STD_LOGIC;
				req_burst_128 : in STD_LOGIC; -- initiate 128-word access
				
				req_read : in STD_LOGIC; -- '1' to request read from mem
												 
				-- host should latch data or supply new write data
				-- on rising edge of clk whenever "increment_en" is high
				increment_en : out STD_LOGIC;
				
				-- requested address must be divisible by 128
				-- will be latched by RAM at start of read/write and auto-incremented
				req_addr : in STD_LOGIC_VECTOR (22 downto 0);
				
				-- read/write data are registered in the IO block
				req_data_write : in STD_LOGIC_VECTOR (15 downto 0);
				req_data_read : out STD_LOGIC_VECTOR (15 downto 0);
				
				-- test LEDs
				Led : out STD_LOGIC_VECTOR (7 downto 0)
				);
				
end mem_control;

architecture Behavioral of mem_control is

	signal my_reset, my_reset_sync : STD_LOGIC := '1';  -- local reset for state machine

	-- configuration opcode for PSRAM bus (select BCR, burst mode, 4 clk latency, 1/2 drive, continuous burst)
	constant CONFIG_WORD : STD_LOGIC_VECTOR (22 downto 0) := "00010000101110100011111";
	
	signal addr_reg : STD_LOGIC_VECTOR (22 downto 0) := CONFIG_WORD;
	signal addr_next : STD_LOGIC_VECTOR (22 downto 0);
	
	signal tri_reg : STD_LOGIC := '1'; -- tristate control register for data bus
	signal tri_next : STD_LOGIC;
	
	signal OE_reg, WE_reg, ADV_reg, CE_reg : STD_LOGIC := '1'; -- all external signals registered
	signal OE_next, WE_next, ADV_next, CE_next : STD_LOGIC;
	signal CRE_reg : STD_LOGIC := '0';
	signal CRE_next : STD_LOGIC;
	
	signal data_write_reg : STD_LOGIC_VECTOR (15 downto 0) := (others => '0'); -- FPGA to PSRAM data register
	signal data_write_next : STD_LOGIC_VECTOR (15 downto 0);
	
	signal data_read_reg : STD_LOGIC_VECTOR (15 downto 0) := (others => '0'); -- PSRAM to FPGA data register
--	signal data_read_next : STD_LOGIC_VECTOR (15 downto 0);
	signal data_read_en: STD_LOGIC;
	
	type state_type is (start, config_1, config_2, config_3, config_4, config_5, idle, test_1, test_done);
	signal state_reg : state_type := start;
	signal state_next : state_type;
	
	signal lat_counter_reg : INTEGER range 0 to 3 := 0;
	signal lat_counter_rst, lat_counter_en: STD_LOGIC;


begin

----------------------------
-- Tie off unused signals
----------------------------

micronLB_n <= '0';
micronUB_n <= '0';
flashCS_n <= '1';
micronClk <= '0';


------------------------------
-- Data bus tri-state buffer
------------------------------

micronData <= data_write_reg when tri_reg = '0' else (others => 'Z');

process(clk, data_read_en)
begin
	if rising_edge(clk) then
		if data_read_en = '1' then
			data_read_reg <= micronData;
		end if;
	end if;
end process;

process(clk)
begin
	if rising_edge(clk) then
		tri_reg <= tri_next;
	end if;
end process;

------------------
-- IO Registers
------------------

process(clk)
begin
	if rising_edge(clk) then
		OE_reg <= OE_next;
		WE_reg <= WE_next;
		ADV_reg <= ADV_next;
		CE_reg <= CE_next;
		CRE_reg <= CRE_next;
		addr_reg <= addr_next;
		data_write_reg <= data_write_next;
	end if;
end process;



----------------------------
-- Main loop state machine
----------------------------

-- generate synchronous reset signal
process(clk)
begin
	if rising_edge(clk) then
		my_reset_sync <= '0';
		my_reset <= my_reset_sync;
	end if;
end process;

-- state register
process(clk, my_reset)
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
process(clk, lat_counter_rst, lat_counter_en)
begin
	if rising_edge(clk) then
		if lat_counter_rst = '1' then
			lat_counter_reg <= 0;
		elsif lat_counter_en = '1' then
			lat_counter_reg <= lat_counter_reg + 1;
		end if;
	end if;
end process;

-- next state logic & unregistered outputs
process(state_reg, addr_reg, data_write_reg, lat_counter_reg)
begin

	-- defaults
	state_next <= state_reg;
	addr_next <= addr_reg;
	data_write_next <= data_write_reg;
	data_read_en <= '0';
	lat_counter_rst <= '0';
	lat_counter_en <= '0';
	ready <= '0';
	
	case state_reg is
	
		when start =>
			state_next <= config_1;
		when config_1 =>
			state_next <= config_2;
		when config_2 =>
			lat_counter_rst <= '1';
			state_next <= config_3;
		when config_3 =>
			lat_counter_en <= '1';
			if lat_counter_reg = 2 then
				state_next <= config_4;
			else
				state_next <= config_3;
			end if;			
		when config_4 =>
			lat_counter_rst <= '1';
			state_next <= config_5;
		when config_5 =>
			lat_counter_en <= '1';
			if lat_counter_reg = 3 then
				state_next <= idle;
			else
				state_next <= config_5;
			end if;
		when idle =>	
			lat_counter_rst <= '1';
			state_next <= test_1;
		when test_1 =>
			lat_counter_en <= '1';
			if lat_counter_reg = 3 then
				data_read_en <= '1';
				state_next <= test_done;
			else
				state_next <= test_1;
			end if;
		
		when test_done =>
			ready <= '1';
		
		when others =>
			null;
				
	end case;

end process;

-- look-ahead logic for registered outputs
process(state_next)
begin

	-- defaults
	OE_next <= '1';
	WE_next <= '1';
	ADV_next <= '1';
	CE_next <= '1';
	CRE_next <= '0';
	tri_next <= '1';
	
	case state_next is
		
		when config_1 =>
			CRE_next <= '1';
			ADV_next <= '0';
			CE_next <= '0';
		when config_2 =>
			CRE_next <= '1';
			ADV_next <= '1';
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
			ADV_next <= '0';
			CE_next <= '0';
			OE_next <= '0';
		when idle =>
			null;
		when test_1 =>
			CRE_next <= '1';
			ADV_next <= '0';
			CE_next <= '0';
			OE_next <= '0';
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
micronADV_n <= ADV_reg;
micronCE_n <= CE_reg;
micronCRE <= CRE_reg;

req_data_read <= data_read_reg;

Led <= data_read_reg(15 downto 8);

end Behavioral;

