----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    23:40:06 09/03/2011 
-- Design Name: 
-- Module Name:    controller - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity controller is
    Port ( CK1IN_p : out  STD_LOGIC;
           CK1IN_n : out  STD_LOGIC;
           RXIN2_p : out  STD_LOGIC;
           RXIN2_n : out  STD_LOGIC;
           RXIN1_p : out  STD_LOGIC;
           RXIN1_n : out  STD_LOGIC;
           RXIN0_p : out  STD_LOGIC;
           RXIN0_n : out  STD_LOGIC;
           clk_in : in  STD_LOGIC);
end controller;

architecture Behavioral of controller is

	-- fast clock, (100 Mhz / 2 )* 5 = 250 Mhz clock , which gives us a pixel clock of 36 Mhz
	signal clk_fast : std_logic;
	
	-- colors
	signal red : std_logic_vector(5 downto 0) := "000000";
	signal green : std_logic_vector(5 downto 0) := "000000";
	signal blue : std_logic_vector(5 downto 0) := "000000";
	
	-- which slot are we in right now?
	signal slot : integer range 0 to 6;
	
	-- control signals
	signal hsync : std_logic := '0';
	signal vsync : std_logic := '0';
	signal dataenable : std_logic := '0';
	
	-- display parameters
	constant htotal : integer := 1440; -- screen size, with back porch
	constant hfront : integer := 0; -- front porch
	constant hactive : integer := 1280; -- display size
	signal hcurrent : integer range 0 to htotal := 0;
	constant vtotal : integer := 823; -- screen size, with back porch
	constant vfront : integer := 0; -- front porch
	constant vactive : integer := 768; -- display size
	signal vcurrent : integer range 0 to vtotal := 0;
	
	-- the signals holding the data to be sent to the lcd on each slot.
	-- this is hardwired on the RGB, hsync and vsync signals.
	signal RX0DATA : std_logic_vector(0 to 6) := "0000000";
	signal RX1DATA : std_logic_vector(0 to 6) := "0000000";
	signal RX2DATA : std_logic_vector(0 to 6) := "0000000";
	constant CK1DATA : std_logic_vector(0 to 6) := "1100011"; -- this is per spec, the clock 
																					-- is always the same 
	-- internal LVDS signal inputs
	signal CK1IN : std_logic;
	signal RXIN0 : std_logic;
	signal RXIN1 : std_logic;
	signal RXIN2 : std_logic;
	
	signal color_cur : integer range 0 to 2 := 0;
begin

DCM_SP_inst : DCM_SP
	generic map (
		CLKFX_DIVIDE => 2,
		CLKFX_MULTIPLY => 5 -- (100 Mhz / 2 )* 5 = 250 Mhz clock
	)
	port map (
		CLKFX => clk_fast,
		CLKIN => clk_in,
		RST => '0'
	);

OBUFDS_CK1IN_inst : OBUFDS
	generic map (IOSTANDARD => "LVDS_33")
	port map (
		O => CK1IN_p,    -- Diff_p output (connect directly to top-level port)
		OB => CK1IN_n,   -- Diff_n output (connect directly to top-level port)
		I => CK1IN       -- Buffer input 
	);

OBUFDS_RXIN0_inst : OBUFDS
	generic map (IOSTANDARD => "LVDS_33")
	port map (
		O => RXIN0_p,    -- Diff_p output (connect directly to top-level port)
		OB => RXIN0_n,   -- Diff_n output (connect directly to top-level port)
		I => RXIN0       -- Buffer input 
	);

OBUFDS_RXIN1_inst : OBUFDS
	generic map (IOSTANDARD => "LVDS_33")
	port map (
		O => RXIN1_p,    -- Diff_p output (connect directly to top-level port)
		OB => RXIN1_n,   -- Diff_n output (connect directly to top-level port)
		I => RXIN1       -- Buffer input 
	);

OBUFDS_RXIN2_inst : OBUFDS
	generic map (IOSTANDARD => "LVDS_33")
	port map (
		O => RXIN2_p,    -- Diff_p output (connect directly to top-level port)
		OB => RXIN2_n,   -- Diff_n output (connect directly to top-level port)
		I => RXIN2       -- Buffer input 
	);

-- data enable: should be high when the data is valid for display
dataenable <= vsync and hsync;

-- RX2DATA is (DE, vsync, hsync, blue[5:2])
RX2DATA(0) <= dataenable;
RX2DATA(1) <= vsync;
RX2DATA(2) <= hsync;
RX2DATA(3 to 6) <= blue(5 downto 2);

-- RX1DATA is (blue[1:0], green[5:1])
RX1DATA(0 to 1) <= blue(1 downto 0);
RX1DATA(2 to 6) <= green(5 downto 1);

-- RX1DATA is (green[0], red[5:0])
RX0DATA(0) <= green(0);
RX0DATA(1 to 6) <= red(5 downto 0);

-- connect signals with the appropriate slot
RXIN0 <= RX0DATA(slot);
RXIN1 <= RX1DATA(slot);
RXIN2 <= RX2DATA(slot);
CK1IN <= CK1DATA(slot);

process(clk_fast) is
begin
	if rising_edge(clk_fast) then
		
		if hcurrent < hfront or (hcurrent >= (hfront+hactive)) then
			hsync <= '0';
		else
			hsync <= '1';
		end if;
		
		if vcurrent < vfront or (vcurrent >= (vfront+vactive)) then
			vsync <= '0';
		else
			vsync <= '1';
		end if;
		
		if slot = 6 then
			-- this is the last slot, wrap around
			slot <= 0;
			
			-- if this is the last pixel in the line, wrap around
			if hcurrent = htotal then
				hcurrent <= 0;
				
				if blue = "000000" then
					blue <= "111000";
					if green = "000000" then
						green <= "111000";
						if red = "000000" then
							red <= "111000";
						else
							red <= red - 8;
						end if;
					else
						green <= green - 8;
					end if;
				else
					blue <= blue - 8;
				end if;
				
				-- if this is the last line in the screen, wrap around.
				if vcurrent = vtotal then
					vcurrent <= 0;
					
					-- new screen, reset the colors
					red <= "111000";
					green <= "111000";
					blue <= "111000";
				else
					vcurrent <= vcurrent + 1;
				end if;
			else
				hcurrent <= hcurrent + 1;
			end if;
			
		else
			slot <= slot + 1;
		end if;
		
	end if;
end process;

end Behavioral;

