
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
 
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--USE ieee.numeric_std.ALL;
 
ENTITY simulation_testbench IS
END simulation_testbench;
 
ARCHITECTURE behavior OF simulation_testbench IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT hardware_testbench
    PORT(
         clk : IN  std_logic;
         micronAddr : OUT  std_logic_vector(22 downto 0);
         micronData : INOUT  std_logic_vector(15 downto 0);
         micronOE_n : OUT  std_logic;
         micronWE_n : OUT  std_logic;
         micronADV_n : OUT  std_logic;
         micronCE_n : OUT  std_logic;
         micronLB_n : OUT  std_logic;
         micronUB_n : OUT  std_logic;
         micronCRE : OUT  std_logic;
         micronClk : OUT  std_logic;
         flashCS_n : OUT  std_logic;
         led : OUT  std_logic_vector (7 downto 0);
			micronwait : IN std_logic
        );
    END COMPONENT;
    

   --Inputs
   signal clk : std_logic := '0';
	signal micronwait : std_logic := '0';

	--BiDirs
   signal micronData : std_logic_vector(15 downto 0);

 	--Outputs
   signal micronAddr : std_logic_vector(22 downto 0);
   signal micronOE_n : std_logic;
   signal micronWE_n : std_logic;
   signal micronADV_n : std_logic;
   signal micronCE_n : std_logic;
   signal micronLB_n : std_logic;
   signal micronUB_n : std_logic;
   signal micronCRE : std_logic;
   signal micronClk : std_logic;
   signal flashCS_n : std_logic;
   signal led : std_logic_vector (7 downto 0);

   -- Clock period definitions
   constant clk_period : time := 20 ns;

 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: hardware_testbench PORT MAP (
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
          led => led,
			 micronwait => micronwait
        );

   -- Clock process definitions
   clk_process :process
   begin
		clk <= '0';
		wait for clk_period/2;
		clk <= '1';
		wait for clk_period/2;
   end process;
 

 

   -- Stimulus process
   stim_proc: process
   begin		
      -- hold reset state for 100 ns.
      wait for 100 ns;	

      wait for clk_period*10;

      -- insert stimulus here 

      wait;
   end process;

END;
