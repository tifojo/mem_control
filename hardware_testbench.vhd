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
		
		flashCS_n : out STD_LOGIC;
		
--		read_out : out STD_LOGIC_VECTOR (15 downto 0)

		led_0 : out STD_LOGIC
	 
	 
	 );
end hardware_testbench;

architecture Behavioral of hardware_testbench is

	signal test_ready : STD_LOGIC;
	signal test_req_burst : STD_LOGIC := '0';
	signal test_is_read : STD_LOGIC := '0';
	signal test_increment_en : STD_LOGIC;
	
	signal test_address : STD_LOGIC_VECTOR (22 downto 0) := (others => '0');

	signal test_data_write : STD_LOGIC_VECTOR (15 downto 0) := (others => '0');
	signal test_data_read : STD_LOGIC_VECTOR (15 downto 0);
	
--	signal error : STD_LOGIC := '0';
	
	type test_state_type is (idle, read_test, write_test, test_done);
	signal test_state : test_state_type := idle;

begin

mem_control_inst : entity work.mem_control
	port map(
		clk => clk,
		
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
		
		flashCS_n => flashCS_n,
		
		ready => test_ready,
		req_burst_128 => test_req_burst,
		req_read => test_is_read,
		increment_en => test_increment_en,
		req_addr => test_address,
		req_data_write => test_data_write,
		req_data_read => test_data_read
	);


process(clk)
begin
	
	if rising_edge(clk) then
		case test_state is
			when idle =>
				test_data_write <= (others => '0');
				if test_is_read = '1' and test_ready = '1' then
					test_state <= read_test;
					test_req_burst <= '1';
				elsif test_is_read = '0' and test_ready ='1' then
					test_state <= write_test;
					test_req_burst <= '1';
					test_address <= std_logic_vector(unsigned(test_address) + 1);
				else
					test_state <= idle;
				end if;
			when write_test =>
				test_req_burst <= '0';
				if test_increment_en = '1' then
					test_data_write <= std_logic_vector(unsigned(test_data_write) + 1);
				elsif test_data_write = x"0080" then
					test_state <= idle;
					test_is_read <= '1';
				else
					null;
				end if;
			when read_test =>
				test_req_burst <= '0';
				if test_increment_en = '1' then
					test_data_write <= std_logic_vector(unsigned(test_data_write) + 1);
				elsif test_data_write = x"0080" then
					test_state <= idle;
					test_is_read <= '0';
				else
					null;
				end if;
			when others =>
				null;
			end case;
		end if;
end process;
		

led_0 <= '1' when (test_data_read = test_data_write) else	-- not the correct test
			'0';

-- read_out <= test_data_read;


--process(clk, ready)
--begin
--	if rising_edge(clk) then
--		if ready = '1' then
--			req_addr <= std_logic_vector(unsigned(req_addr) + 1);
--		end if;
--	end if;
--end process;
--
--req_burst_128 <= '1';
--req_read <= '0';

end Behavioral;

