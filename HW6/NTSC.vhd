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
		addrrow : OUT std_logic_vector(7 DOWNTO 0);
		addrcol : OUT std_logic_vector(9 DOWNTO 0)); 
END NTSC;

ARCHITECTURE Behavioral OF NTSC IS
	SIGNAL holdCount : INTEGER RANGE 1 TO 320 := 1;
	TYPE states IS (
	EQ_LOW_STATE,
	EQ_HIGH_STATE,
	EQ_LOW_STATE2,
	EQ_HIGH_STATE2,
	
	SER_LOW_STATE,
	SER_HIGH_STATE,
	SER_LOW_STATE2,
	SER_HIGH_STATE2,
	
	BLANK_LOW_STATE,
	BLANK_HIGH_STATE,
	BLANK_HIGH2_STATE,
	
	DATA_LOW_STATE,
	DATA_BP_STATE,
	DATA_ADDR_STATE,
	--DATA_ADDR2_STATE,
	DATA_FP_STATE
	);
	--attribute enum_encoding : string;
	--attribute enum_encoding of states : type is "sequential";
	SIGNAL State : states := EQ_LOW_STATE;
	
	constant EQ_LOW: integer := 23; 
	constant SER_LOW : INTEGER  := 273;
	constant BLANK_LOW : INTEGER:= 47;
	constant DATA_LOW : INTEGER:= 47;
	constant DATA_BP : INTEGER := 62;
	constant DATA_FP : INTEGER := 15;
	constant PULSEPER : INTEGER := 318;
	
	signal row : std_logic_vector(7 DOWNTO 0);-- := "00000000";
	signal col : std_logic_vector(9 DOWNTO 0);-- := "0000000000";
	

BEGIN
	PROCESS (clk)
	variable dline : INTEGER RANGE 1 TO 526 := 1;
	BEGIN
		IF rising_edge(clk) THEN
			CASE State IS
				WHEN EQ_LOW_STATE =>
					IF holdCount = EQ_LOW THEN
						State <= EQ_HIGH_STATE;
					ELSE
						State <= EQ_LOW_STATE;
					END IF;

				WHEN EQ_HIGH_STATE =>
					IF holdCount = PULSEPER THEN
							State <= EQ_LOW_STATE2; 
						IF dline = 266 THEN 
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
						--ELSE
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
						IF dline = 21 then -->= 21 and dline <= 260 THEN
							odd <= '0';
							row <= "00000000";
						ELSIF dline = 284 then -- dline = 284
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

--				WHEN DATA_ADDR2_STATE =>
--					addrcol <= col;
--					col <= std_logic_vector(unsigned(col) + 1);
--					IF holdCount = PULSEPER - DATA_FP THEN
--						State <= DATA_FP_STATE;
--					ELSE
--						State <= DATA_ADDR2_STATE;
--					END IF;

				WHEN DATA_FP_STATE =>
					IF holdCount = PULSEPER THEN
						IF dline = 260 OR dline = 523 THEN
							State <= BLANK_LOW_STATE;
						ELSE
							row <= std_logic_vector(unsigned(row) + 1);
							--col <= "0000000000";
							--addrrow <= row;
							State <= DATA_LOW_STATE;
						END IF;
						dline := dline + 1;
					ELSE
						State <= DATA_FP_STATE;
					END IF;
				
				--when others => 
					--State <= EQ_LOW_STATE;
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
				WHEN DATA_BP_STATE => --DATA_ADDR2_STATE |
					sync <= '0';
					blank <= '1';
				WHEN DATA_ADDR_STATE => 
					sync <= '0'; 
					blank <= '1'; 
				WHEN DATA_FP_STATE => 
					sync <= '0'; 
					blank <= '1'; 
				--when others =>
					--sync <= '0';
					--blank <= '0';
			END CASE;
		END PROCESS;

END Behavioral;



----use IEEE.STD_LOGIC_1164.ALL;
----use IEEE.STD_LOGIC_ARITH.ALL;
----use IEEE.STD_LOGIC_UNSIGNED.ALL;
--
------ Uncomment the following library declaration if instantiating
------ any Xilinx primitives in this code.
----library UNISIM;
----use UNISIM.VComponents.all;
------------------------------------------------------------------------------
----
---- NTSC Controller EE119 HW6
----
---- Desc.
----
---- Ports:
----
---- Revision History:
---- 11/14/18 Sophia Liu Initial revision.
---- 11/15/18 Sophia Liu Updated comments.
----
------------------------------------------------------------------------------
--LIBRARY ieee;
--USE ieee.std_logic_1164.ALL;
--USE ieee.numeric_std.ALL;
--ENTITY NTSC IS
--	PORT (
--		clk : IN std_logic;
--		sync : OUT std_logic;
--		blank : OUT std_logic;
--		odd : OUT std_logic;
--		addrrow : OUT std_logic_vector(7 DOWNTO 0); 
--		addrcol : OUT std_logic_vector(9 DOWNTO 0)); 
--END NTSC;
--
--ARCHITECTURE Behavioral OF NTSC IS
--	SIGNAL holdCount : INTEGER RANGE 0 TO 637 := 0;
--	SIGNAL dline : INTEGER RANGE 1 TO 525 := 1;
--	--SIGNAL blank : std_logic;
--	signal row : std_logic_vector(7 DOWNTO 0); --:= "00000000";
--	signal col : std_logic_vector(9 DOWNTO 0); --:= "0000000000";
--	--signal sync: std_logic;
--	
--	constant EQ_LOW: natural := 23; 
--	constant SER_LOW : natural := 273;
--	constant BLANK_LOW : natural := 47;
--	constant DATA_LOW : natural := 47;
--	constant DATA_BP : natural := 62;
--	constant DATA_FP : natural := 15;
--	constant PULSEPER : natural := 318;
--	constant LINEPER : natural := 636;
--BEGIN
--	PROCESS (clk)
--	BEGIN
--		IF rising_edge(clk) THEN
--		case dline is 
--			when 1 to 3 | 7 to 9 | 264 | 265 | 270 | 271 =>
--				-- 2 eq pulses 
--					--blank <= '0';
--				if holdCount = PULSEPER then 
--				--(holdCount <= EQ_LOW) or (holdCount > PULSEPER and holdCount <= EQ_lOW + PULSEPER) then 
--					sync <= '0';
--				elsif holdCount = EQ_LOW or holdCount = EQ_LOW + PULSEPER then 
--				--(holdCount > EQ_LOW and holdCount <= PULSEPER) or (holdCount > EQ_LOW + PULSEPER and holdCount <= LINEPER)
--					sync <= '1'; 
--				end if; 
--				
--			when 4 to 6 | 267 | 268 =>
--				-- 2 ser pulses
--				--blank <= '0';
--				if holdCount = PULSEPER then 
--				--(holdCount <= SER_LOW) or (holdCount > PULSEPER and holdCount <= SER_lOW + PULSEPER) then 
--					sync <= '0';
--				elsif holdCount = SER_LOW or holdCount = SER_LOW + PULSEPER then 
--				--(holdCount > SER_LOW and holdCount <= PULSEPER) or 
--				--(holdCount > EQ_LOW + PULSEPER and holdCount <= LINEPER) 
--					sync <= '1'; 
--				end if; 
--
--			when 10 to 20 | 273 to 283 | 523 to 525 | 261 to 262 =>
--				-- blank pulse
--				blank <= '0';
--				--if holdCount = 0 then --(holdCount <= BLANK_LOW) then 
--				--	sync <= '0';
--				if holdCount = BLANK_LOW then 
--					sync <= '1'; 
--				end if; 
--					
--			when 263 => 
--				-- blank/eq 
--				--blank <= '0';
--				--if holdCount = 0 then --(holdCount <= BLANK_LOW) then 
--					--sync <= '0';
--				if holdCount = BLANK_LOW then --(holdCount  <= PULSEPER) then 
--					sync <= '1'; 
--				elsif holdCount = PULSEPER then --(holdCount <= PULSEPER + EQ_LOW) then 
--					sync <= '0'; 
--				elsif holdCount = PULSEPER + EQ_LOW then 
--					sync <= '1';
--				end if; 
--				
--			when 266 => 
--				-- eq/ser  
--				--blank <= '0';
--				--if holdCount = 0 then --(holdCount <= EQ_LOW) then 
--					--sync <= '0';
--				if holdCount = EQ_LOW then -- (holdCount  <= PULSEPER) then 
--					sync <= '1'; 
--				elsif holdCount = PULSEPER then --(holdCount <= PULSEPER + SER_LOW) then 
--					sync <= '0'; 
--				elsif holdCount = PULSEPER + SER_LOW then 
--					sync <= '1';
--				end if; 
--				
--			when 269 =>
--				-- ser/eq 
--				--blank <= '0';
--				--if holdCount = 0 then --(holdCount <= SER_LOW) then 
--					--sync <= '0';
--				if holdCount = SER_LOW then --(holdCount  <= PULSEPER) then 
--					sync <= '1'; 
--				elsif holdCount = PULSEPER then --(holdCount <= PULSEPER + EQ_LOW) then 
--					sync <= '0'; 
--				elsif holdCount = PULSEPER + EQ_LOW then
--					sync <= '1';
--				end if; 
--				
--			when 272 =>
--				-- eq/blank
--				--blank <= '0';
--				--if holdCount = 0 then --(holdCount <= EQ_LOW) then 
--				--	sync <= '0';
--				if holdCount = EQ_LOW then 
--					sync <= '1';
--				end if; 
--				
--			when 21 to 260 | 284 to 522 =>
--				-- even 
--				blank <= '1';
--				if dline = 21 then 
--					row <= "00000000"; 
--					odd <= '0'; 
--				elsif dline = 284 then 
--					row <= "00000000";
--					odd <= '1'; 
--				end if ; 
--				
--				--if holdCount = 0 then --(holdCount <= DATA_LOW) then -- hold low 
--					--sync <= '0';
--				if holdCount = DATA_LOW then --(holdCount <= DATA_LOW + DATA_BP) then -- hold back porch 
--					sync <= '1';
--					col <= "0000000000"; 
--				elsif holdCount = DATA_LOW + DATA_BP then --(holdCount <= DATA_LOW + DATA_BP + 512) then 
--					sync <= '1'; 
--					addrrow <= row; 
--					addrcol <= col; 
--					col <= std_logic_vector(unsigned(col) + 1); 
--				elsif holdCount = DATA_LOW + DATA_BP + 512 then 
--					sync <= '0'; 
--				end if; 
--				
--				if holdCount >= LINEPER then 
--					--dline := dline + 1; 
--					row <= std_logic_vector(unsigned(row) + 1); 
--				end if; 
--			end case;
--			
--			IF holdCount = LINEPER THEN
--				holdCount <= 0;
--				sync <= '0'; --TODO offby1
--				if dline = 525 then 
--					dline <= 1; 
--				else 
--					dline <= dline + 1; 
--				end if; 	
--			ELSE
--				holdCount <= holdCount + 1;
--			END IF;
--			
--			--syncout <= sync; 
--			--blankout <= blank; 
--			
--		end if; 
--	END PROCESS;
--	
--END Behavioral;
