----------------------------------------------------------------------------
-- 
-- EE119 HW6 
-- 
-- NTSC Controller
--
-- This is a NTSC controller designed to output a color image stored in a 
-- 512Kx8 EPROM to an NTSC monitor. The SYNC and BLANK NTSC timing signals 
-- are generated, using a 10 MHz controller clock, along with the 
-- EPROM addresses. Each image line is 512 pixels, and the even and odd lines 
-- are interlaced on the display. 
-- The outputs are timed as followed. The first output timing lines are 
-- blanked for vertical synchronization, with equalizing pulses, 
-- serration pulses, additional equalizing pulses, and blanked video 
-- lines. The even video lines are then displayed, followed by 
-- blanked lines and the odd video lines. The EPROM addresses are 
-- pipelined and latched with an external latch. The result is a 
-- 512x512 8 bit image with 3 red, 3 green, and 2 blue bits.
--
-- A moore state machine is used, with the states shown below. 
-- There are states for each of the vertical synchronization 
-- and blanking pulses, and for outputing horizontal video 
-- data. 
-- 
-- States: 
--
--		SYNC equalizing pulse occuring in the first half of a line
--	EQ_LOW_STATE,			SYNC is first held low for EQ_LOW clocks. 
--	EQ_HIGH_STATE,			SYNC is then held high for the rest of 
-- 							the half-line
--
--		SYNC equalizing pulse occuring in the second half of a line
--	EQ_LOW_STATE2,			SYNC is first held low for EQ_LOW clocks
--	EQ_HIGH_STATE2,		SYNC is then held high for the rest of 
--								the half-line
--	
-- 	SYNC serration pulse occuring in the first half of a line 
--	SER_LOW_STATE,			SYNC is held low for SER_LOW clocks
--	SER_HIGH_STATE,		SYNC is then held high
--
-- 	SYNC serration pulse occuring in the second half of a line 
--	SER_LOW_STATE2,		SYNC is held low for SER_LOW clocks
--	SER_HIGH_STATE2,		SYNC is then held high
--
--		SYNC blank pulse 
--	BLANK_LOW_STATE,		SYNC is held low for BLANK_LOW clocks
--	BLANK_HIGH_STATE,		SYNC is held high for the remaining half-line
--	BLANK_HIGH2_STATE,	SYNC is held high for the second half-line
--	
-- 	Normal horizontal even/odd video lines
--	DATA_LOW_STATE,		SYNC is held low for DATA_LOW clocks
--	DATA_BP_STATE,			Back porch, blanked for DATA_BP clocks
--	DATA_ADDR_STATE,		Data is sent, with the column address incremented
--	DATA_FP_STATE			Front porch, blanked for DATA_FP clocks
-- 
-- State machine diagram: 
--
-- Ports:
--		clk 		: IN std_logic;
-- 		1 bit, 10 MHz input clock signal 
-- 	
--		sync 		: out std_logic;
-- 		1 bit, inverted (active high) sync timing signal 
-- 
--		blank 	: out std_logic;
--    	1 bit, active low blank timing signal 
-- 
--		odd 		: out std_logic;
-- 		1 bit EPROM address output indicating even field output when '0' 
--			and odd field output when '1'
-- 
--		addrrow 	: out std_logic_vector(7 downto 0);
--		 	8 bit EPROM address row output, with MSB 7. 
-- 		Even lines arelocated at EPROM rows 0 to 239 
-- 		(beginning at addrrow = "00000000", odd = '0'), 
-- 		and odd video lines are located at EPROM rows 256 to 495 
-- 		(beginning at addrrow = "00000000", odd = '1')
-- 
--		addrcol 	: out std_logic_vector(9 downto 0); 
--			10 bit EPROM address column output, with MSB 9
--
-- Revision History:
-- 11/14/18 Sophia Liu Initial revision
-- 11/15/18 Sophia Liu Added more states 
-- 11/16/18 Sophia Liu Updated comments
--
----------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
entity NTSC is
	PORT (
		clk 		: in std_logic; 
		-- 	1 bit, 10 MHz input clock signal
		
		sync 		: out std_logic;
		-- 	1 bit, inverted (active high) sync timing signal 
		
		blank 	: out std_logic;
		--   1 bit, active low blank timing signal 
		
		odd 		: out std_logic;
		-- 	1 bit EPROM address output indicating even field output when '0' 
		--			and odd field output when '1'
		
		addrrow 	: out std_logic_vector(7 downto 0);	
		-- 8 bit EPROM address row output, with MSB 7. 
		-- Even lines arelocated at EPROM rows 0 to 239 
		-- (beginning at addrrow = "00000000", odd = '0'), 
		-- and odd video lines are located at EPROM rows 256 to 495 
		-- (beginning at addrrow = "00000000", odd = '1')
		
		addrcol 	: out std_logic_vector(9 downto 0)); 
		--	10 bit EPROM address column output, with MSB 9
END NTSC;


ARCHITECTURE Behavioral OF NTSC IS

	-- Moore state machine for NTSC controller
	TYPE NTSCstates IS (
	-- Equalizing pulse
	EQ_LOW_STATE,  
	EQ_HIGH_STATE,
	EQ_LOW_STATE2,
	EQ_HIGH_STATE2,
	
	-- Serration pulse
	SER_LOW_STATE,
	SER_HIGH_STATE,
	SER_LOW_STATE2,
	SER_HIGH_STATE2,
	
	-- Blanking line 
	BLANK_LOW_STATE,
	BLANK_HIGH_STATE,
	BLANK_HIGH2_STATE,
	
	-- Normal video line 
	DATA_LOW_STATE,
	DATA_BP_STATE,
	DATA_ADDR_STATE,
	DATA_FP_STATE
	);
	
	-- current state  for NTSC state machine 
	SIGNAL state : NTSCstates := EQ_LOW_STATE;
	
	-- Constants 
	
	-- Timing constants
	constant EQ_LOW	 : integer := 23; 
	-- 	Number of clocks to hold SYNC low for equalizing pulse
	constant SER_LOW	 : integer := 273;
	-- 	Number of clocks to hold SYNC low for serration pulse
	constant BLANK_LOW : integer := 47;
	-- 	Number of clocks to hold SYNC low for blank line
	constant DATA_LOW  :	integer := 47;
	-- 	Number of clocks to hold SYNC low before addressing EPROM
	constant DATA_BP   :	integer := 62;
	-- 	Number of clocks to wait before sending video data
	constant DATA_FP   :	integer := 15;
	-- 	Number of clocks to wait after sending video data
	constant PULSEPER  :	integer := 318;
	-- 	Number of clocks for half a line ("pulse period")
	
	-- Line constants 
	constant LINETOTAL : integer := 525; 
	-- 	Total number of lines to output 
	
	
	-- Internal signals 
	-- 8 bit internal EPROM row address signal 
	signal row : std_logic_vector(7 DOWNTO 0);
	
	-- 10 bit internal EPROM column address signal 
	signal col : std_logic_vector(9 DOWNTO 0);
	
	-- internal integer for counting clocks up to half a line (PULSEPER clocks)
	signal holdCount : integer range 1 to PULSEPER := 1;
	
	begin
	process (clk)
	-- internal counter that keeps track of current line number
	variable dline : INTEGER RANGE 1 TO LINETOTAL + 1 := 1;
	begin
		IF rising_edge(clk) THEN
			CASE state IS
				WHEN EQ_LOW_STATE =>
					IF holdCount = EQ_LOW THEN
						-- move to rest of equalizing pulse after EQ_LOW clocks
						State <= EQ_HIGH_STATE;
					ELSE
						-- wait for correct number of clocks to elapse
						State <= EQ_LOW_STATE;
					END IF;

				WHEN EQ_HIGH_STATE =>
					IF holdCount = PULSEPER THEN
							--State <= EQ_LOW_STATE2; TODO remove
						IF dline = 266 THEN --TODO magic numbers
							State <= SER_LOW_STATE2;
						ELSIF dline = 272 THEN 
							State <= BLANK_HIGH2_STATE;
						ELSE
							State <= EQ_LOW_STATE2;
						END IF;
					ELSE 
						State <= EQ_HIGH_STATE;
					END IF;

				WHEN EQ_LOW_STATE2 =>
					IF holdCount = EQ_LOW THEN 
						State <= EQ_HIGH_STATE2;
					ELSE
						State <= EQ_LOW_STATE2;
					END IF;
				
				WHEN EQ_HIGH_STATE2 =>
					IF holdCount = PULSEPER THEN
						IF dline = 3 THEN
							State <= SER_LOW_STATE;
						ELSIF dline = 9 THEN
							State <= BLANK_LOW_STATE;
						ELSE
							State <= EQ_LOW_STATE;
						END IF;
						dline := dline + 1;
					ELSE 
						State <= EQ_HIGH_STATE2;
					END IF;
					
				WHEN SER_LOW_STATE =>
					IF holdCount = SER_LOW THEN
						State <= SER_HIGH_STATE;
					ELSE
						State <= SER_LOW_STATE;
					END IF;

				WHEN SER_HIGH_STATE =>
					IF holdCount = PULSEPER THEN
						IF dline = 269 THEN --TODO magic
							State <= EQ_LOW_STATE2;
						ELSE
							State <= SER_LOW_STATE2;
						END IF;
					ELSE
						State <= SER_HIGH_STATE;
					END IF;
					
				WHEN SER_LOW_STATE2 =>
					IF holdCount = SER_LOW THEN
						State <= SER_HIGH_STATE2;
					ELSE
						State <= SER_LOW_STATE2;
					END IF;

				WHEN SER_HIGH_STATE2 =>
					IF holdCount = PULSEPER THEN
						IF dline = 6 THEN
							State <= EQ_LOW_STATE;
						ELSE
							State <= SER_LOW_STATE;
						END IF;
						dline := dline + 1;
					ELSE
						State <= SER_HIGH_STATE2;
					END IF;

				WHEN BLANK_LOW_STATE =>
					IF holdCount = BLANK_LOW THEN
						State <= BLANK_HIGH_STATE;
					ELSE
						State <= BLANK_LOW_STATE;
					END IF;

				WHEN BLANK_HIGH_STATE =>
					IF holdCount = PULSEPER THEN
						IF dline = 263 THEN --TODO magic
							State <= EQ_LOW_STATE2;
						ELSE
							State <= BLANK_HIGH2_STATE;
						END IF;
					ELSE
						State <= BLANK_HIGH_STATE;
					END IF;

				WHEN BLANK_HIGH2_STATE =>
					IF holdCount = PULSEPER THEN
						IF dline = 525 THEN --TODO magic
							State <= EQ_LOW_STATE;
						ELSIF dline = 20 OR dline = 283 THEN
							State <= DATA_LOW_STATE;
						ELSE 
							State <= BLANK_LOW_STATE; 
						END IF;

						dline := dline + 1;
						IF dline > 525 THEN
							dline := 1;
						END IF;
					ELSE
						State <= BLANK_HIGH2_STATE;
					END IF;

				WHEN DATA_LOW_STATE =>
					IF holdCount = DATA_LOW THEN
						State <= DATA_BP_STATE;
					ELSE
						State <= DATA_LOW_STATE;
					END IF;

				WHEN DATA_BP_STATE =>
					IF holdCount = DATA_LOW + DATA_BP THEN
						State <= DATA_ADDR_STATE;
						IF dline = 21 then 
							odd <= '0';
							row <= "00000000";
						ELSIF dline = 284 then 
							odd <= '1';
							row <= "00000000";
						END IF;
						col <= "0000000000";
						addrrow <= row;
					ELSE
						State <= DATA_BP_STATE;
					END IF;

				WHEN DATA_ADDR_STATE =>
					addrcol <= col;
					col <= std_logic_vector(unsigned(col) + 1);
					IF unsigned(col) = 512 THEN
						State <= DATA_FP_STATE;
					ELSE
						State <= DATA_ADDR_STATE;
					END IF;

				WHEN DATA_FP_STATE =>
					IF holdCount = PULSEPER THEN
						IF dline = 260 OR dline = 523 THEN
							State <= BLANK_LOW_STATE;
						ELSE
							row <= std_logic_vector(unsigned(row) + 1);
							State <= DATA_LOW_STATE;
						END IF;
						dline := dline + 1;
					ELSE
						State <= DATA_FP_STATE;
					END IF;
			END CASE;
			
			IF holdCount = PULSEPER THEN
				holdCount <= 1;
			ELSE
				holdCount <= holdCount + 1;
			END IF;
		end if; 
	END PROCESS;

	-- assign outputs
	PROCESS (State)
		BEGIN
			CASE State IS
				WHEN EQ_LOW_STATE | EQ_LOW_STATE2=>
					sync <= '1';
					blank <= '0';
--				WHEN EQ_LOW_STATE2 => 
--					sync <= '1';
--					blank <= '0';				
				WHEN SER_LOW_STATE =>
					sync <= '1';
					blank <= '0';				
				WHEN SER_LOW_STATE2 => 
					sync <= '1';
					blank <= '0';			
				WHEN BLANK_LOW_STATE => 
					sync <= '1';
					blank <= '0';			
				WHEN EQ_HIGH_STATE =>
					sync <= '0';
					blank <= '0';
				WHEN EQ_HIGH_STATE2 =>
					sync <= '0';
					blank <= '0';
				WHEN SER_HIGH_STATE =>
					sync <= '0';
					blank <= '0';
				WHEN SER_HIGH_STATE2  =>
					sync <= '0';
					blank <= '0';
				WHEN BLANK_HIGH_STATE => 
					sync <= '0'; 
					blank <= '0'; 
				WHEN BLANK_HIGH2_STATE => 
					sync <= '0'; 
					blank <= '0'; 				
				WHEN DATA_LOW_STATE =>
					sync <= '1';
					blank <= '1';
				WHEN DATA_BP_STATE => 
					sync <= '0';
					blank <= '1';
				WHEN DATA_ADDR_STATE => 
					sync <= '0'; 
					blank <= '1'; 
				WHEN DATA_FP_STATE => 
					sync <= '0'; 
					blank <= '1'; 
			END CASE;
		END PROCESS;

END Behavioral;