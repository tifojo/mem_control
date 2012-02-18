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
	 
	 );
end hardware_testbench;

architecture Behavioral of hardware_testbench is

	constant BURST_LENGTH : unsigned (22 downto 0) := to_unsigned(32,23);

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
	
	signal test_init : STD_LOGIC_VECTOR (15 downto 0) := x"0001";
	
	signal error : STD_LOGIC_VECTOR (6 downto 0) := (others => '0');
	
	type test_state_type is (idle, read_test, write_test, test_done);
	signal test_state : test_state_type := idle;
	
	signal clk_25 : STD_LOGIC;
	signal clk_fx : STD_LOGIC;

	signal clk_0 : STD_LOGIC;
	signal clk_90 : STD_LOGIC;
	signal clk_180 : STD_LOGIC;
	signal clk_270 : STD_LOGIC;
	
	signal clk_int : STD_LOGIC;
	
	signal dcm_locked : STD_LOGIC;
	
	-----------
	-- debug --
	-----------
	
	signal data_debug : STD_LOGIC_VECTOR (15 downto 0);
	
	signal debug_0 : STD_LOGIC_VECTOR (15 downto 0);
	signal debug_90 : STD_LOGIC_VECTOR (15 downto 0);
	signal debug_180 : STD_LOGIC_VECTOR (15 downto 0);
	signal debug_270 : STD_LOGIC_VECTOR (15 downto 0);
	
	attribute keep : string;
	attribute keep of debug_0, debug_90, debug_180, debug_270 : signal is "TRUE";
	
	signal data_valid_delay : STD_LOGIC_VECTOR (2 downto 0) := "000";

begin

single_dcm : entity work.single_dcm
	port map(
		CLKIN_IN => clk,
		CLKDV_OUT => clk_25,
		CLKFX_OUT => clk_fx,
		CLKIN_IBUFG_OUT => open,
		CLK0_OUT => clk_0,
		CLK90_OUT => clk_90,
		CLK180_OUT => clk_180,
		CLK270_OUT => clk_270,
		LOCKED_OUT => dcm_locked);

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
		req_burst => test_req_burst,
		req_rw => test_is_read,
		read_data_valid => test_read_valid,
		write_increment_en => test_increment_en,
		req_addr => test_address,
		req_data_write => data_write_out,
		req_data_read => test_data_read,
		req_done => done,
		
		-- debug
		data_debug => data_debug
		
	);

debug : entity work.debug
	generic map(N=>16)
	port map(
		clk_0 => clk_0,
		clk_90 => clk_90,
		clk_180 => clk_180,
		clk_270 => clk_270,
		
		debug_in => data_debug,
		
		debug_0_out => debug_0,
		debug_90_out => debug_90,
		debug_180_out => debug_180,
		debug_270_out => debug_270
	);
		
		

process(clk_int)
begin
	
	if rising_edge(clk_int) then
		case test_state is
			when idle =>
				test_data_write <= test_init;
				test_address <= (others => '0');
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
					test_data_write <= (test_data_write(14 downto 0))&(test_data_write(15) xor test_data_write(13) xor test_data_write(12) xor test_data_write(10));
				end if;
				if done = '1' then
					if test_address(22 downto 7) = x"FFFF" then
						test_state <= idle;
						test_is_read <= '1';
					else
						test_address <= std_logic_vector(unsigned(test_address) + BURST_LENGTH);
					end if;
				end if;
				if test_ready = '1' then
					test_req_burst <= '1';
				end if;
			when read_test =>
				test_req_burst <= '0';
				if test_read_valid = '1' then
					test_data_write <= (test_data_write(14 downto 0))&(test_data_write(15) xor test_data_write(13) xor test_data_write(12) xor test_data_write(10));
					if data_write_out /= test_data_read then
						error <= std_logic_vector(unsigned(error) + 1);
					end if;
				end if;
				if done = '1' then
					if test_address(22 downto 7) = x"FFFF" then
						test_state <= idle;
						test_is_read <= '0';
						test_init <= std_logic_vector(unsigned(test_init) + 1);
					else
						test_address <= std_logic_vector(unsigned(test_address) + BURST_LENGTH);
					end if;
				end if;
				if test_ready = '1' then
					test_req_burst <= '1';
				end if;
			when others =>
				null;
			end case;
		end if;
end process;
		
data_write_out <= test_data_write;

led(0) <= dcm_locked;
led(7 downto 1) <= error;




end Behavioral;

