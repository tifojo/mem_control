--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   01:01:37 01/17/2012
-- Design Name:   
-- Module Name:   C:/Documents and Settings/timothyj/My Documents/Xilinx/Memory Controller/mem_control/simulation_testbench.vhd
-- Project Name:  mem_control
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: mem_control
-- 
-- Dependencies:
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
-- Notes: 
-- This testbench has been automatically generated using types std_logic and
-- std_logic_vector for the ports of the unit under test.  Xilinx recommends
-- that these types always be used for the top-level I/O of a design in order
-- to guarantee that the testbench will bind correctly to the post-implementation 
-- simulation model.
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
 
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--USE ieee.numeric_std.ALL;
 
ENTITY simulation_testbench IS
END simulation_testbench;
 
ARCHITECTURE behavior OF simulation_testbench IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT mem_control
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
         ready : OUT  std_logic;
         req_burst_128 : IN  std_logic;
         req_read : IN  std_logic;
         increment_en : OUT  std_logic;
         req_addr : IN  std_logic_vector(22 downto 0);
         req_data_write : IN  std_logic_vector(15 downto 0);
         req_data_read : OUT  std_logic_vector(15 downto 0)
        );
    END COMPONENT;
    

   --Inputs
   signal clk : std_logic := '0';
   signal req_burst_128 : std_logic := '0';
   signal req_read : std_logic := '0';
   signal req_addr : std_logic_vector(22 downto 0) := (others => '0');
   signal req_data_write : std_logic_vector(15 downto 0) := (others => '0');

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
   signal ready : std_logic;
   signal increment_en : std_logic;
   signal req_data_read : std_logic_vector(15 downto 0);

   -- Clock period definitions
   constant clk_period : time := 20 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: mem_control PORT MAP (
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
          ready => ready,
          req_burst_128 => req_burst_128,
          req_read => req_read,
          increment_en => increment_en,
          req_addr => req_addr,
          req_data_write => req_data_write,
          req_data_read => req_data_read
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
