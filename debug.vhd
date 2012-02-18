library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library UNISIM;
use UNISIM.VComponents.all;

-- interleaved sampling front-end for timing measurements
-- should be synthesized with shift register extraction disabled

entity debug is

	generic(N : integer := 1); -- width of input bus
	
	port(
		clk_0 : in std_logic;
		clk_90 : in std_logic;
		clk_180 : in std_logic;
		clk_270 : in std_logic;
		
		debug_in : in std_logic_vector (N-1 downto 0);
		
		debug_0_out : out std_logic_vector (N-1 downto 0);
		debug_90_out : out std_logic_vector (N-1 downto 0);
		debug_180_out : out std_logic_vector (N-1 downto 0);
		debug_270_out : out std_logic_vector (N-1 downto 0)
	);

end debug;

architecture Behavioral of debug is

	signal debug_0_sync : STD_LOGIC_VECTOR (N-1 downto 0) := (others => '0');
	signal debug_0_reg : STD_LOGIC_VECTOR (N-1 downto 0) := (others => '0');
	signal debug_0_reg1 : STD_LOGIC_VECTOR (N-1 downto 0) := (others => '0');
	signal debug_0_reg2 : STD_LOGIC_VECTOR (N-1 downto 0) := (others => '0');
	signal debug_90_sync : STD_LOGIC_VECTOR (N-1 downto 0) := (others => '0');
	signal debug_90_reg : STD_LOGIC_VECTOR (N-1 downto 0) := (others => '0');
	signal debug_90_reg1 : STD_LOGIC_VECTOR (N-1 downto 0) := (others => '0');
	signal debug_90_reg2 : STD_LOGIC_VECTOR (N-1 downto 0) := (others => '0');
	signal debug_180_sync : STD_LOGIC_VECTOR (N-1 downto 0) := (others => '0');
	signal debug_180_reg : STD_LOGIC_VECTOR (N-1 downto 0) := (others => '0');
	signal debug_180_reg1 : STD_LOGIC_VECTOR (N-1 downto 0) := (others => '0');
	signal debug_180_reg2 : STD_LOGIC_VECTOR (N-1 downto 0) := (others => '0');
	signal debug_270_sync : STD_LOGIC_VECTOR (N-1 downto 0) := (others => '0');
	signal debug_270_reg : STD_LOGIC_VECTOR (N-1 downto 0) := (others => '0');
	signal debug_270_reg1 : STD_LOGIC_VECTOR (N-1 downto 0) := (others => '0');
	signal debug_270_reg2 : STD_LOGIC_VECTOR (N-1 downto 0) := (others => '0');

	attribute maxdelay : string;
	attribute maxdelay of debug_0_sync : signal is "1.5 ns";
	attribute maxdelay of debug_90_sync : signal is "1.5 ns";
	attribute maxdelay of debug_180_sync : signal is "1.5 ns";
	attribute maxdelay of debug_270_sync : signal is "1.5 ns";
	
	attribute maxskew : string;
	attribute maxskew of debug_in : signal is "500 ps";
	attribute maxdelay of debug_in : signal is "1 ns";
	
	attribute iob : string;
	attribute iob of debug_0_sync : signal is "FALSE";  -- prevent XST from packing signals into DDR registers
	attribute iob of debug_90_sync : signal is "FALSE";
	attribute iob of debug_180_sync : signal is "FALSE";
	attribute iob of debug_270_sync : signal is "FALSE";
	
--	attribute keep : string;
--	attribute keep of debug_0_out : signal is "TRUE";  -- preserve registers to be probed by chipscope
--	attribute keep of debug_90_out : signal is "TRUE";
--	attribute keep of debug_180_out : signal is "TRUE";
--	attribute keep of debug_270_out : signal is "TRUE";

begin

	process(clk_0)
	begin
		if rising_edge(clk_0) then
			debug_0_sync <= debug_in;
			debug_0_reg <= debug_0_sync;
			debug_0_reg1 <= debug_0_reg;
			debug_0_reg2 <= debug_0_reg1;
			debug_90_reg1 <= debug_90_reg;
			debug_90_reg2 <= debug_90_reg1;
			debug_180_reg1 <= debug_180_reg;
			debug_180_reg2 <= debug_180_reg1;
			debug_270_reg2 <= debug_270_reg1;
		end if;
	end process;

	process(clk_90)
	begin
		if rising_edge(clk_90) then
			debug_90_sync <= debug_in;
			debug_90_reg <= debug_90_sync;
		end if;
	end process;

	process(clk_180)
	begin
		if rising_edge(clk_180) then
			debug_180_sync <= debug_in;
			debug_180_reg <= debug_180_sync;
			debug_270_reg1 <= debug_270_reg;
		end if;
	end process;

	process(clk_270)
	begin
		if rising_edge(clk_270) then
			debug_270_sync <= debug_in;
			debug_270_reg <= debug_270_sync;
		end if;
	end process;

	debug_0_out <= debug_0_reg2;
	debug_90_out <= debug_90_reg2;
	debug_180_out <= debug_180_reg2;
	debug_270_out <= debug_270_reg2;


end Behavioral;

