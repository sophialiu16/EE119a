--use IEEE.STD_LOGIC_1164.ALL;
--use IEEE.STD_LOGIC_ARITH.ALL;
--use IEEE.STD_LOGIC_UNSIGNED.ALL;

---- Uncomment the following library declaration if instantiating
---- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;
----------------------------------------------------------------------------
--
-- NTSC Controller EE119 HW6
--
-- Desc.
--
-- Ports:
--
-- Revision History:
-- 11/14/18 Sophia Liu Initial revision.
-- 11/15/18 Sophia Liu Updated comments.
--
----------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
ENTITY NTSC IS
	PORT (
		clk : IN std_logic;
		sync : OUT std_logic;
		blank : OUT std_logic;
		odd : OUT std_logic;
		addrrow : OUT std_logic_vector(7 DOWNTO 0); -- int?
		addrcol : OUT std_logic_vector(9 DOWNTO 0)); -- int?
END NTSC;

ARCHITECTURE Behavioral OF NTSC IS
	SIGNAL holdCount : INTEGER RANGE 0 TO 320 := 0;
	TYPE states IS (
	EQ_LOW_STATE,
	EQ_HIGH_STATE,
	SER_LOW_STATE,
	SER_HIGH_STATE,
	BLANK_LOW_STATE,
	BLANK_HIGH_STATE,
	BLANK_HIGH2_STATE,
	DATA_LOW_STATE,
	DATA_BP_STATE,
	DATA_ADDR_STATE,
	DATA_ADDR2_STATE,
	DATA_FP_STATE
	);
	SIGNAL State : states := EQ_LOW_STATE; -- TODO specify state bits
	
	constant EQ_LOW: integer := 23; 
	constant SER_LOW : INTEGER  := 273;
	constant BLANK_LOW : INTEGER:= 47;
	constant DATA_LOW : INTEGER:= 47;
	constant DATA_BP : INTEGER := 62;
	constant DATA_FP : INTEGER := 15;
	constant PULSEPER : INTEGER := 318;
BEGIN
	PROCESS (clk)
	VARIABLE dline : INTEGER RANGE 0 TO 526 := 0;
	VARIABLE pulseCount : INTEGER RANGE 0 TO 1 := 0;
	VARIABLE row : std_logic_vector(7 DOWNTO 0) := "00000000";
	VARIABLE col : std_logic_vector(9 DOWNTO 0) := "0000000000";
	BEGIN
		IF rising_edge(clk) THEN
			CASE State IS
				WHEN EQ_LOW_STATE =>
					IF holdCount >= EQ_LOW THEN -- > eq_low - 1?
						State <= EQ_HIGH_STATE;
					ELSE
						State <= EQ_LOW_STATE;
					END IF;

				WHEN EQ_HIGH_STATE =>
					IF holdCount >= PULSEPER THEN
						IF pulseCount = 0 THEN
							pulseCount := 1;
							IF dline = 266 THEN --TODO magic
								State <= SER_LOW_STATE;
							ELSIF dline = 272 THEN --TODO magic
								State <= BLANK_HIGH2_STATE;
							ELSE
								State <= EQ_LOW_STATE;
							END IF;
						ELSE -- pulseCount = 1
							pulseCount := 0;
							IF dline = 3 THEN
								State <= SER_LOW_STATE;
							ELSIF dline = 9 THEN
								State <= BLANK_LOW_STATE;
							ELSE
								State <= EQ_LOW_STATE;
							END IF;
							dline := dline + 1;
						END IF;
					ELSE -- holdCount < EQ_HIGH
						State <= EQ_HIGH_STATE;
					END IF;

				WHEN SER_LOW_STATE =>
					IF holdCount >= SER_LOW THEN
						State <= SER_HIGH_STATE;
					ELSE
						State <= SER_LOW_STATE;
					END IF;

				WHEN SER_HIGH_STATE =>
					IF holdCount >= PULSEPER THEN
						IF pulseCount = 0 THEN
							pulseCount := 1;
							IF dline = 269 THEN --TODO magic
								State <= EQ_LOW_STATE;
							ELSE
								State <= SER_LOW_STATE;
							END IF;
						ELSE -- pulseCount = 1
							pulseCount := 0;
							IF dline = 6 THEN
								State <= EQ_LOW_STATE;
							ELSE
								State <= SER_LOW_STATE;
							END IF;
							dline := dline + 1;
						END IF;
					ELSE
						State <= SER_HIGH_STATE;
					END IF;

				WHEN BLANK_LOW_STATE =>
					IF holdCount >= BLANK_LOW THEN
						State <= BLANK_HIGH_STATE;
					ELSE
						State <= BLANK_LOW_STATE;
					END IF;

				WHEN BLANK_HIGH_STATE =>
					IF holdCount >= PULSEPER THEN
						--if pulseCount = 0 then
						pulseCount := 1;
						IF dline = 263 THEN --TODO magic
							State <= EQ_LOW_STATE;
						ELSE
							State <= BLANK_HIGH2_STATE;
						END IF;
						--else -- pulseCount = 1
						-- error
					ELSE
						State <= BLANK_HIGH_STATE;
					END IF;

				WHEN BLANK_HIGH2_STATE =>
					IF holdCount >= PULSEPER THEN
						--if pulseCount = 1 then
						pulseCount := 0;
						IF dline = 525 THEN --TODO magic
							State <= EQ_LOW_STATE;
						ELSIF dline <= 20 OR dline <= 283 THEN
							State <= DATA_LOW_STATE;
						END IF;

						IF dline = 525 THEN
							dline := dline + 1;
						ELSE
							dline := 1;
						END IF;
						--else -- pulseCount = 0
						-- error
					ELSE
						State <= BLANK_HIGH2_STATE;
					END IF;

				WHEN DATA_LOW_STATE =>
					IF holdCount >= DATA_LOW THEN
						State <= DATA_BP_STATE;
					ELSE
						State <= DATA_LOW_STATE;
					END IF;

				WHEN DATA_BP_STATE =>
					IF holdCount >= DATA_LOW + DATA_BP THEN
						State <= DATA_ADDR_STATE;
						IF dline = 21 THEN
							odd <= '0';
						ELSE -- dline = 284
							odd <= '1';
						END IF;
						row := "00000000";
						col := "0000000000";
						addrrow <= row;
					ELSE
						State <= DATA_BP_STATE;
					END IF;

				WHEN DATA_ADDR_STATE =>
					addrcol <= col;
					col := std_logic_vector(unsigned(col) + 1);
					IF holdCount >= PULSEPER THEN
						State <= DATA_ADDR2_STATE;
					ELSE
						State <= DATA_ADDR_STATE;
					END IF;

				WHEN DATA_ADDR2_STATE =>
					IF holdCount >= PULSEPER - DATA_FP THEN
						State <= DATA_FP_STATE;
					ELSE
						addrcol <= col;
						col := std_logic_vector(unsigned(col) + 1);
						State <= DATA_ADDR2_STATE;
					END IF;

				WHEN DATA_FP_STATE =>
					IF holdCount >= PULSEPER THEN
						IF dline = 260 OR dline = 523 THEN
							State <= BLANK_LOW_STATE;
						ELSE
							row := std_logic_vector(unsigned(row) + 1);
							col := "0000000000";
							addrrow <= row;
							State <= DATA_BP_STATE;
						END IF;
						dline := dline + 1;
					ELSE
						State <= DATA_FP_STATE;
					END IF;
				
				when others => 
					State <= EQ_LOW_STATE;
			END CASE;
			
			IF holdCount >= PULSEPER THEN
				holdCount <= 0;
			ELSE
				holdCount <= holdCount + 1;
			END IF;
		end if; 
	END PROCESS;

	-- assign outputs
	PROCESS (State)
		BEGIN
			CASE State IS
				WHEN EQ_LOW_STATE =>
					sync <= '0';
					blank <= '0';
				WHEN EQ_HIGH_STATE =>
					sync <= '1';
					blank <= '0';
				WHEN SER_LOW_STATE =>
					sync <= '0';
					blank <= '0';
				WHEN SER_HIGH_STATE =>
					sync <= '1';
					blank <= '0';
				WHEN BLANK_LOW_STATE =>
					sync <= '0';
					blank <= '0';
				WHEN BLANK_HIGH_STATE =>
					sync <= '1';
					blank <= '0';
				WHEN BLANK_HIGH2_STATE =>
					sync <= '1';
					blank <= '0';
				WHEN DATA_LOW_STATE =>
					sync <= '0';
					blank <= '1';
				WHEN DATA_BP_STATE =>
					sync <= '1';
					blank <= '1';
				WHEN DATA_ADDR_STATE =>
					sync <= '1';
					blank <= '1';
				WHEN DATA_ADDR2_STATE =>
					sync <= '1';
					blank <= '1';
				WHEN DATA_FP_STATE =>
					sync <= '1';
					blank <= '1';
				when others =>
					sync <= '0';
					blank <= '0';
			END CASE;
		END PROCESS;

END Behavioral;
