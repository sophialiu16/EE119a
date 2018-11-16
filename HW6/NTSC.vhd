----------------------------------------------------------------------------
-- 
-- EE119 HW6 Sophia Liu
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
-- and blanking pulses, and for outputting horizontal video 
-- data. 
-- 
-- States: 
--
--		SYNC equalizing pulse occurring in the first half of a line
--	EQ_LOW_STATE,			SYNC is first held low for EQ_LOW clocks. 
--	EQ_HIGH_STATE,			SYNC is then held high for the rest of 
-- 							the half-line
--
--		SYNC equalizing pulse occurring in the second half of a line
--	EQ_LOW_STATE2,			SYNC is first held low for EQ_LOW clocks
--	EQ_HIGH_STATE2,		SYNC is then held high for the rest of 
--								the half-line
--	
-- 	SYNC serration pulse occurring in the first half of a line 
--	SER_LOW_STATE,			SYNC is held low for SER_LOW clocks
--	SER_HIGH_STATE,		SYNC is then held high
--
-- 	SYNC serration pulse occurring in the second half of a line 
--	SER_LOW_STATE2,		SYNC is held low for SER_LOW clocks
--	SER_HIGH_STATE2,		SYNC is then held high
--
--		SYNC blank pulse 
--	BLANK_LOW_STATE,		SYNC is held low for BLANK_LOW clocks
--	BLANK_HIGH_STATE,		SYNC is held high for the remaining half-line
--	BLANK_HIGH_STATE2,	SYNC is held high for the second half-line
--	
-- 	Normal horizontal even/odd video lines
--	DATA_LOW_STATE,		SYNC is held low for DATA_LOW clocks
--	DATA_BP_STATE,			Back porch, blanked for DATA_BP clocks
--	DATA_ADDR_STATE,		Data is sent, with the column address incremented
--	DATA_FP_STATE			Front porch, blanked for DATA_FP clocks
-- 
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
	BLANK_HIGH_STATE2,
	
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
	constant EQSER		: integer := 266; 
	-- 	line with half equalizing half serration pulse 
	constant BLANKEQ	: integer := 263; 
	-- 	line with half blanked half equalizing pulse 
	constant SEREQ		: integer := 269; 
	--		line with half serration half equalizing pulse 
	constant EQBLANK	: integer := 272; 
	-- 	line with half equalizing half blanked pulse
	
	constant EQSER_EVEN : integer := 3; 
	--		line to transition from equalizing to serration pulses for even lines
	constant SEREQ_EVEN : integer := 6; 
	--		line to transition from serration to equalizing pulses for even lines
	constant EQBLANK_EVEN : integer := 9; 
	--		line to transition from serration to equalizing pulses for even lines
	constant BLANKEQ_EVEN : integer := 525; 
	--		line to transition from blanking to equalizing pulses for even lines
	constant BLANKEVEN : integer := 20; 
	--		line to transition from blanking to even video lines 
	constant BLANKODD : integer := 283; 
	--		line to transition from blanking to odd video lines
	
	constant DATAEVEN : integer := BLANKEVEN + 1; 
	constant DATAODD: integer := BLANKODD + 1;
	-- 	beginning line of even and odd video data lines 
	constant DATAEVEN_DONE : integer := 260; 
	constant DATAODD_DONE : integer := 523;
	--		end line of even and odd video data lines
	constant DATAWIDTH : integer := 512; 
	-- 	horizontal pixel width of image
	
	-- Internal signals 
	-- 8 bit internal EPROM row address signal 
	signal row : std_logic_vector(7 DOWNTO 0);
	
	-- 10 bit internal EPROM column address signal 
	signal col : std_logic_vector(9 DOWNTO 0);
	
	-- internal integer for counting clocks up to half a line (PULSEPER clocks)
	signal holdCount : integer range 1 to PULSEPER := 1;
	
	begin
	process (clk)
	-- internal counter that keeps track of current display line number
	variable dline : integer range 1 to LINETOTAL + 1 := 1;
	begin
		if rising_edge(clk) then 
			case state is
				WHEN EQ_LOW_STATE =>
					-- move to rest of equalizing pulse after EQ_LOW clocks
					IF holdCount = EQ_LOW THEN
						state<= EQ_HIGH_STATE;
					ELSE
						-- wait for correct number of clocks to elapse before transitioning 
						state<= EQ_LOW_STATE;
					END IF;

				WHEN EQ_HIGH_STATE =>
					IF holdCount = PULSEPER THEN
						-- upon finishing half of line, check what to do next 
						-- based on current line number
						IF dline = EQSER THEN 
							state<= SER_LOW_STATE2;	
						ELSIF dline = EQBLANK THEN
							state<= BLANK_HIGH_STATE2;
						ELSE
							state<= EQ_LOW_STATE2;
						END IF;
					ELSE 
						-- wait for correct number of clocks to elapse
						state<= EQ_HIGH_STATE;
					END IF;

				WHEN EQ_LOW_STATE2 =>
					-- move to rest of equalizing pulse after EQ_LOW clocks
					IF holdCount = EQ_LOW THEN 
						state<= EQ_HIGH_STATE2;
					ELSE
						-- wait for correct number of clocks before transitioning 
						state<= EQ_LOW_STATE2;
					END IF;
				
				WHEN EQ_HIGH_STATE2 =>
					IF holdCount = PULSEPER THEN
						-- upon finishing second half of line, check what to do 
						-- next based on current line number 
						IF dline = EQSER_EVEN THEN
							state<= SER_LOW_STATE;
						ELSIF dline = EQBLANK_EVEN THEN
							state<= BLANK_LOW_STATE;
						ELSE
							state<= EQ_LOW_STATE;
						END IF;
						-- advance to the next line 
						dline := dline + 1;
					ELSE 
						-- wait for line to finish
						state<= EQ_HIGH_STATE2;
					END IF;
					
				WHEN SER_LOW_STATE =>
					-- move to rest of serration pulse after SER_LOW clocks
					IF holdCount = SER_LOW THEN
						state<= SER_HIGH_STATE;
					ELSE
						state<= SER_LOW_STATE;
					END IF;

				WHEN SER_HIGH_STATE =>
					IF holdCount = PULSEPER THEN
					-- upon finishing half of line, check what to do 
					-- in second half of line next based on current line number 
						IF dline = SEREQ THEN  
							state<= EQ_LOW_STATE2;
						ELSE
							state<= SER_LOW_STATE2;
						END IF;
					ELSE
						-- wait for half of line to finish
						state<= SER_HIGH_STATE;
					END IF;
					
				WHEN SER_LOW_STATE2 =>
					--  move to rest of serration pulse after SER_LOW clocks
					IF holdCount = SER_LOW THEN
						state<= SER_HIGH_STATE2;
					ELSE
						-- wait for SER_LOW clocks before advancing
						state<= SER_LOW_STATE2;
					END IF;

				WHEN SER_HIGH_STATE2 =>
					-- upon finishing line, check what to do 
					-- in next line based on current line number 
					IF holdCount = PULSEPER THEN
						IF dline = SEREQ_EVEN THEN
							state<= EQ_LOW_STATE;
						ELSE
							state<= SER_LOW_STATE;
						END IF;
						-- advance to next line 
						dline := dline + 1;
					ELSE
						-- wait for line to finish
						state<= SER_HIGH_STATE2;
					END IF;

				WHEN BLANK_LOW_STATE =>
					-- move to rest of blank pulse after BLANK_LOW clocks
					IF holdCount = BLANK_LOW THEN
						state<= BLANK_HIGH_STATE;
					ELSE
						state<= BLANK_LOW_STATE;
					END IF;

				WHEN BLANK_HIGH_STATE =>
					-- upon finishing blank pulse, check what to do 
					-- in next half line based on current line number
					IF holdCount = PULSEPER THEN
						IF dline = BLANKEQ THEN 
							state<= EQ_LOW_STATE2;
						ELSE
							state<= BLANK_HIGH_STATE2;
						END IF;
					ELSE
						-- wait for pulse to finish
						state<= BLANK_HIGH_STATE;
					END IF;

				WHEN BLANK_HIGH_STATE2 =>
					-- upon finishing blank line, check whether to do 
					-- an equalizing pulse, video lines, or more blank lines 
					-- based on current line number
					IF holdCount = PULSEPER THEN
						IF dline = BLANKEQ_EVEN THEN
							state <= EQ_LOW_STATE;
						ELSIF dline = BLANKEVEN or dline = BLANKODD THEN
							state <= DATA_LOW_STATE;
						ELSE 
							state <= BLANK_LOW_STATE; 
						END IF;
						-- advance to next line 
						dline := dline + 1;
						IF dline > LINETOTAL THEN
							dline := 1; -- wrap line count back to beginning
						END IF;
					ELSE
						-- wait for line to finish
						state<= BLANK_HIGH_STATE2;
					END IF;

				WHEN DATA_LOW_STATE =>
					-- move to back porch state after DATA_LOW clocks
					IF holdCount = DATA_LOW THEN
						state<= DATA_BP_STATE;
					ELSE
						state<= DATA_LOW_STATE;
					END IF;

				WHEN DATA_BP_STATE =>
					-- move to video data state after another DATA_BP clocks
					IF holdCount = DATA_LOW + DATA_BP THEN
						state<= DATA_ADDR_STATE;
						-- assign initial row and column EPROM addresses
						IF dline = DATAEVEN THEN 
							odd <= '0';
							row <= "00000000";
						ELSIF dline = DATAODD THEN
							odd <= '1';
							row <= "00000000";
						END IF;
						col <= "0000000000";
						addrrow <= row;
					ELSE
						state<= DATA_BP_STATE;
					END IF;

				WHEN DATA_ADDR_STATE =>
					-- output and increment column EPROM address 
					addrcol <= col;
					col <= std_logic_vector(unsigned(col) + 1);
					IF unsigned(col) = DATAWIDTH THEN
						-- done once entire row has been outputted
						state<= DATA_FP_STATE;
					ELSE
						state<= DATA_ADDR_STATE;
					END IF;

				WHEN DATA_FP_STATE =>
					IF holdCount = PULSEPER THEN
						IF dline = DATAEVEN_DONE or dline = DATAODD_DONE THEN
							-- move to blank state if all even or odd lines are finished
							state<= BLANK_LOW_STATE;
						ELSE
							-- otherwise, increment row and continue to next video data line 
							row <= std_logic_vector(unsigned(row) + 1);
							state<= DATA_LOW_STATE;
						END IF;
						-- advance to next linee 
						dline := dline + 1;
					ELSE
						-- wait for front porch blanking to finish 
						state<= DATA_FP_STATE;
					END IF;
			END CASE;
			
			-- increment the timing counter with clock rising edge
			IF holdCount = PULSEPER THEN
				-- wrap counter after half a line (or 1 blanking pulse)
				holdCount <= 1;
			ELSE
				holdCount <= holdCount + 1;
			END IF;
		end if; 
	END PROCESS;

	-- Assign SYNC and BLANK outputs based on current state
	PROCESS (state)
		BEGIN
			CASE state IS
				WHEN EQ_LOW_STATE | EQ_LOW_STATE2=>
					sync <= '1';
					blank <= '0';			
				WHEN SER_LOW_STATE | SER_LOW_STATE2=>
					sync <= '1';
					blank <= '0';				
				WHEN BLANK_LOW_STATE => 
					sync <= '1';
					blank <= '0';			
				WHEN EQ_HIGH_STATE | EQ_HIGH_STATE2 =>
					sync <= '0';
					blank <= '0';
				WHEN SER_HIGH_STATE | SER_HIGH_STATE2 =>
					sync <= '0';
					blank <= '0';
				WHEN BLANK_HIGH_STATE | BLANK_HIGH_STATE2=> 
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