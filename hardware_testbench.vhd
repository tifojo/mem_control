library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use IEEE.NUMERIC_STD.ALL;

library UNISIM;
use UNISIM.VComponents.all;

entity hardware_testbench is
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
		
		flashCS_n : out STD_LOGIC;
		

		led : out STD_LOGIC_VECTOR (7 downto 0)
		
--		bogus : out STD_LOGIC
	 
	 
	 );
end hardware_testbench;

architecture Behavioral of hardware_testbench is

	signal test_ready : STD_LOGIC;
	signal test_req_burst : STD_LOGIC := '0';
	signal test_is_read : STD_LOGIC := '0';
	signal test_read_valid : STD_LOGIC;
	signal test_increment_en : STD_LOGIC;
	
	signal test_address : STD_LOGIC_VECTOR (22 downto 0) := (others => '0');

	signal test_data_write : STD_LOGIC_VECTOR (15 downto 0) := (others => '0');
	signal data_write_out : STD_LOGIC_VECTOR (15 downto 0);
	signal test_data_read : STD_LOGIC_VECTOR (15 downto 0);
	
	signal done : STD_LOGIC;
	
	signal test_inverted : STD_LOGIC := '0';
	signal test_inverted_init : STD_LOGIC := '0';
	signal test_init : STD_LOGIC_VECTOR (15 downto 0) := x"0001";
	
	signal error : STD_LOGIC_VECTOR (6 downto 0) := (others => '0');
	
	type test_state_type is (idle, read_test, write_test, test_done);
	signal test_state : test_state_type := idle;
	
	signal clk_50 : STD_LOGIC;
	signal clk_25 : STD_LOGIC;
--	signal clk_fx : STD_LOGIC;

	signal clk_0 : STD_LOGIC;
	signal clk_90 : STD_LOGIC;
	signal clk_180 : STD_LOGIC;
	signal clk_270 : STD_LOGIC;
	
	signal clk_int : STD_LOGIC;
	
	signal dcm_locked : STD_LOGIC;
	
	signal debug_0 : STD_LOGIC_VECTOR (15 downto 0);
	signal debug_90 : STD_LOGIC_VECTOR (15 downto 0);
	signal debug_180 : STD_LOGIC_VECTOR (15 downto 0);
	signal debug_270 : STD_LOGIC_VECTOR (15 downto 0);
	signal debug_align : STD_LOGIC;
	signal debug_0_delay : STD_LOGIC;
--	signal debug_90_delay : STD_LOGIC;
--	signal debug_180_delay : STD_LOGIC;
--	signal debug_270_delay : STD_LOGIC;

	constant DEBUG_INDEX : natural := 0;
	
	signal data_valid_delay : STD_LOGIC_VECTOR (2 downto 0) := "000";

begin

clock_divider : entity work.clock_divider
	port map(
		CLKIN_IN => clk,
		CLKDV_OUT => clk_25,
		CLKFX_OUT => open,
		CLKIN_IBUFG_OUT => open,
		CLK0_OUT => clk_0,
		CLK90_OUT => clk_90,
		CLK180_OUT => clk_180,
		CLK270_OUT => clk_270,
		LOCKED_OUT => dcm_locked);

--cascade_dcm_inst : entity work.cascade_dcm
--	port map(
--		U1_CLKIN_IN        => clk,
--		U1_RST_IN          => '0', 
--		U1_CLKIN_IBUFG_OUT => open, 
--		U1_CLK0_OUT        => clk_50,
--		U1_CLK2X_OUT       => open, 
--		U1_STATUS_OUT      => open,
--		U2_CLK0_OUT        => clk_0,
--		U2_CLK90_OUT       => clk_90, 
--		U2_CLK180_OUT      => clk_180, 
--		U2_CLK270_OUT      => clk_270, 
--		U2_LOCKED_OUT      => dcm_locked, 
--		U2_STATUS_OUT      => open
--	);

clk_int <= clk_0;

mem_control_inst : entity work.mem_control
	port map(
		clk => clk_int,
		
		micronAddr => micronAddr,
		micronData => micronData,
		micronOE_n => micronOE_n,
		micronWE_n => micronWE_n,
		micronADV_n => micronADV_n,
		micronCE_n => micronCE_n,
		micronLB_n => micronLB_n,
		micronUB_n => micronUB_n,
		micronCRE => micronCRE,
		micronClk => micronClk,
		micronWait => micronWait,
		
		flashCS_n => flashCS_n,
		
		ready => test_ready,
		req_burst_128 => test_req_burst,
		req_read => test_is_read,
		read_data_valid => test_read_valid,
		write_increment_en => test_increment_en,
		req_addr => test_address,
		req_data_write => data_write_out,
		req_data_read => test_data_read,
		req_done => done,
		
		-- debug
		clk_0 => clk_0,
		clk_90 => clk_90,
		clk_180 => clk_180,
		clk_270 => clk_270,
		
		debug_0_out => debug_0,
		debug_90_out => debug_90,
		debug_180_out => debug_180,
		debug_270_out => debug_270,
		debug_align => debug_align
	);


process(clk_int)
begin
	
	if rising_edge(clk_int) then
		case test_state is
			when idle =>
				test_data_write <= test_init;
				test_address <= (others => '0');
				test_inverted <= test_inverted_init;
				if test_is_read = '1' and test_ready = '1' then
					test_state <= read_test;
					test_req_burst <= '1';
				elsif test_is_read = '0' and test_ready ='1' then
					test_state <= write_test;
					test_req_burst <= '1';
				else
					test_state <= idle;
				end if;
			when write_test =>
				test_req_burst <= '0';
				if test_increment_en = '1' then
--					test_data_write <= (test_data_write(14 downto 0))&(test_data_write(15) xor test_data_write(13) xor test_data_write(12) xor test_data_write(10));
					test_inverted <= not test_inverted;
					if test_inverted = '1' then
						if test_data_write = x"FFFE" then
							test_data_write <= (others => '0');
						else
							test_data_write <= std_logic_vector(unsigned(test_data_write) + 1);
						end if;
					end if;
				end if;
				if done = '1' then
					if test_address(22 downto 7) = x"FFFF" then
						test_state <= idle;
						test_is_read <= '1';
					else
						test_req_burst <= '1';
						test_address <= std_logic_vector(unsigned(test_address) + 128);
					end if;
				end if;
			when read_test =>
				test_req_burst <= '0';
				if test_read_valid = '1' then
--					test_data_write <= (test_data_write(14 downto 0))&(test_data_write(15) xor test_data_write(13) xor test_data_write(12) xor test_data_write(10));
					test_inverted <= not test_inverted;
					if test_inverted = '1' then
						if test_data_write = x"FFFE" then
							test_data_write <= (others => '0');
						else
							test_data_write <= std_logic_vector(unsigned(test_data_write) + 1);
						end if;
					end if;
					if data_write_out /= test_data_read then
						error <= std_logic_vector(unsigned(error) + 1);
					end if;
				end if;
				if done = '1' then
					if test_address(22 downto 7) = x"FFFF" then
						test_state <= idle;
						test_is_read <= '0';
						test_init <= std_logic_vector(unsigned(test_init) + 1);
						test_inverted_init <= not test_inverted_init;
					else
						test_req_burst <= '1';
						test_address <= std_logic_vector(unsigned(test_address) + 128);
					end if;
				end if;
			when others =>
				null;
			end case;
		end if;
end process;
		
data_write_out <= x"0001" when test_inverted = '0' else
						x"0000";


led(0) <= dcm_locked;
led(1) <= error(6);

led(3 downto 2) <= "00";

--bogus <= '0' when (debug_0 and debug_90 and debug_180 and debug_270) = (debug_0'range => '0') and debug_align = '0' else
--			'1';

process(clk_int)
begin
	if rising_edge(clk_int) then
		debug_0_delay <= debug_0(DEBUG_INDEX);
		data_valid_delay <= data_valid_delay (1 downto 0) & test_read_valid;
--		debug_90_delay <= debug_90(15);
--		debug_180_delay <= debug_180(15);
--		debug_270_delay <= debug_270(15);
	end if;
end process;

led(7) <= data_valid_delay(2) and (debug_0(DEBUG_INDEX) xor debug_90(DEBUG_INDEX));
led(6) <= data_valid_delay(2) and (debug_90(DEBUG_INDEX) xor debug_180(DEBUG_INDEX));
led(5) <= data_valid_delay(2) and (debug_180(DEBUG_INDEX) xor debug_270(DEBUG_INDEX));
led(4) <= data_valid_delay(2) and (debug_270(DEBUG_INDEX) xor debug_0_delay);


end Behavioral;

