----------------------------------------------------------------------------
--
--  NTSC Controller EE119 HW6
--
--  Desc. 
--
--  Ports: 
-- 
--  Revision History:
--      11/14/18  Sophia Liu    Initial revision.
--      11/15/18	Sophia Liu    Updated comments. 
--      
----------------------------------------------------------------------------

-- even field: lines 0  to 239 
-- odd field: lines 256 to 495

-- blanked: lines 1 to 20, 261-283, 524-525:
-- 9 vert synch: 
--    3 equalizing 
--    3 serration 
--    3 equalizing 
-- 11 blank 

-- video line 0 at line 21 (first line even field 00000)
-- video line 1 at line 284 (first line odd field 40000)

-- each field is 262.5 lines 

-- 1 clk = 0.1 usec
-- pipeline 
-- state machine 
-- outputs:  SYNC, BLANK
-- counters: dline (display line), eline (eprom line)
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity NTSCcon is 
	generic ( 
	EQ_LOW: integer:= 23; 
	EQ_HIGH: integer := 295; 
	SER_LOW: integer :=  273;
	SER_HIGH: integer := 45; 
	BLANK_LOW: integer := 47;
	BLANK_HIGH: integer := 291;
	BLANK_HIGH2: integer := 318;
	DATA_LOW: integer := 47; 
	DATA_BP: integer := 62;
	DATA_ADDR: integer := 512; 
	DATA_FP: integer := 15;
	PULSEPER: integer := 318;
	);

	port (
	clk 	:  in std_logic; 
	sync  :  out std_logic;
   blank :  out std_logic;
	odd 	:  out std_logic; 
	row	: 	out std_logic_vector(7 downto 0); -- int?
	col	: 	out std_logic_vector(9 downto 0)); -- int?
end NTSCcon;

architecture NTSCcon of NTSCcon is 
	signal dline			: integer range 0 to 526   := 0; 
	signal eline			: integer range 0 to 495   := 0;
	signal holdCount 		: integer range 0 to 320 	:= 0; 
	signal pulseCount 	: integer range 0 to 1 		:= 0; 
	
	type states is (
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
	
	signal CurrentState	: states; -- TODO specify state bits
	signal NextState 		: states;
	
	begin 
		process(CurrentState)
		begin 
			case CurrentState is 
				when EQ_LOW_STATE =>  
					if holdCount >= EQ_LOW then -- > eq_low - 1?  
						NextState <= EQ_HIGH_STATE; 
					else 
						NextState <= EQ_LOW_STATE; 
					end if; 
					
				when EQ_HIGH_STATE => 
					if holdCount >= PULSEPER then 
						if pulseCount = 0 then 
							pulseCount <= 1; 
							if dline = 266 then --TODO magic
								NextState <= SER_LOW_STATE; 
							elsif dline = 272 then --TODO magic
								NextState <= BLANK_HIGH2_STATE;
							else 
								NextState <= EQ_LOW_STATE; 
							end if; 
						else -- pulseCount = 1
							pulseCount <= 0; 
							if dline = 3 then 
								NextState <= SER_LOW_STATE;
							elsif dline = 9 then 
								NextState <= BLANK_LOW_STATE; 
							else 
								NextState <= EQ_LOW_STATE; 
							end if; 
							dline <= dline + 1; 
						end if; 
					else -- holdCount < EQ_HIGH
						NextState <= EQ_HIGH_STATE;
					end if; 
					
				when SER_LOW_STATE => 
					if holdCount >= SER_LOW then 
						NextState <= SER_HIGH_STATE; 
					else 
						NextState <= SER_LOW_STATE;  
					end if; 
			
				when SER_HIGH_STATE => 
					if holdCount >= PULSEPER then 
						if pulseCount = 0 then 
							pulseCount <= 1; 
							if dline = 269 then --TODO magic
								NextState <= EQ_LOW_STATE; 
							else 
								NextState <= SER_LOW_STATE; 
							end if; 
						else -- pulseCount = 1
							pulseCount <= 0; 
							if dline = 6 then 
								NextState <= EQ_LOW_STATE;
							else 
								NextState <= SER_LOW_STATE; 
							end if; 
							dline <= dline + 1; 
						end if; 
					else 
						NextState <= SER_HIGH_STATE; 
					end if; 
				
				when BLANK_LOW_STATE => 
					if holdCount >= BLANK_LOW then 
						NextState <= BLANK_HIGH_STATE; 
					else 
						NextState <= BLANK_LOW_STATE; 
					end if; 
				
				when BLANK_HIGH_STATE => 
					if holdCount >= PULSEPER then 
						--if pulseCount = 0 then 
						pulseCount <= 1; 
						if dline = 263 then --TODO magic
							NextState <= EQ_LOW_STATE; 
						else 
							NextState <= BLANK_HIGH2_STATE; 
						end if; 
						--else -- pulseCount = 1
							-- error  
					else 
						NextState <= BLANK_HIGH_STATE;
					end if; 

				when BLANK_HIGH2_STATE => 
					if holdCount >= PULSEPER then 
						--if pulseCount = 1 then 
						pulseCount <= 0; 
						dline <= dline + 1; 
						if dline = 525 then --TODO magic
							dline <= 1; 
							NextState <= EQ_LOW_STATE; 
						elsif dline <= 20 or dline <= 283 then 
							NextState <= DATA_LOW_STATE;
						end if; 
						--else -- pulseCount = 0
							-- error  
					else 
						NextState <= BLANK_HIGH2_STATE;
					end if; 
					
				when DATA_LOW_STATE => 
					if holdCount >= DATA_LOW then 
						NextState <= DATA_BP_STATE; 
					else 
						NextState <= DATA_LOW_STATE; 
					end if; 
				
				when DATA_BP_STATE => 
					if holdCount >= DATA_LOW + DATA_BP then 
						NextState <= DATA_ADDR; 
							if dline = 21 then 
								row <= std_logic_vector(0); 
								odd <= '0'; 
							else -- dline = 284 
								row <= std_logic_vector(256); 
								odd <= '1'; 
							end if; 
							col <= std_logic_vector(0); 
					else 
						NextState <= DATA_BP_STATE; 
					end if; 
				
				when DATA_ADDR_STATE => 
					col <= std_logic_vector(unsigned(row) + 1);
					if holdCount >= PULSEPER then 
						NextState <= DATA_ADDR2_STATE; 
					else 
						NextState <= DATA_ADDR_STATE; 
					end if; 
				
				when DATA_ADDR2_STATE => 
					if holdCount >= PULSEPER - DATA_FP then 
						NextState <= DATA_FP_STATE; 
					else 
						col <= std_logic_vector(unsigned(row) + 1);
						NextState <= DATA_ADDR2_STATE; 
					end if; 
					
				when DATA_FP_STATE => 
					if holdCount >= PULSEPER then 
						if dline = 260 or dline = 523 then 
							NextState <= BLANK_LOW_STATE; 
						else 
							col <= std_logic_vector(unsigned(col) + 1); 
							row <= std_logic_vector(0)
							NextState <= DATA_BP_STATE; 
						end if; 
						dline <= dline + 1;
					else 
						NextState <= DATA_FP_STATE; 
					end if; 
			end case; 
				
		end process; 
		
		-- assign outputs 
		process(CurrentState) 
		begin  
			case CurrentState is 
				when EQ_LOW_STATE =>  	
					sync <= '0';
					blank <= '0'; 

				when EQ_HIGH_STATE => 
					sync <= '1';
					blank <= '0'; 

				when SER_LOW_STATE => 
					sync <= '0';
					blank <= '0'; 	
					
				when SER_HIGH_STATE => 
					sync <= '1';
					blank <= '0'; 
				
				when BLANK_LOW_STATE => 
					sync <= '0';
					blank <= '0';
					
				when BLANK_HIGH_STATE => 
					sync <= '1';
					blank <= '0';
				
				when BLANK_HIGH2_STATE => 
					sync <= '1';
					blank <= '0';
					
				when DATA_LOW_STATE => 
					sync <= '0';
					blank <= '1';
				
				when DATA_BP_STATE => 
					sync <= '1';
					blank <= '1';
				
				when DATA_ADDR_STATE => 
					sync <= '1';
					blank <= '1';			
					
				when DATA_ADDR2_STATE => 
					sync <= '1';
					blank <= '1';		
					
				when DATA_FP_STATE => 
					sync <= '1';
					blank <= '1';
			end case; 
		end process; 
		
		-- state storage, loads next state on rising edge of clock 
		process (clk)
		begin 
			if rising_edge(clk) then 
				CurrentState <= NextState; 
				if holdCount >= PULSEPER then 
					holdCount <= 0;
				else 
					holdCount <= holdCount + 1; 
			end if; 
		end process; 
		
end NTSCcon;