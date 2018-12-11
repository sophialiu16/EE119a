
library ieee; 
use ieee.std_logic_1164.all; 
use ieee.numeric_std.all;
use ieee.std_logic_signed.all;

----------------------------------------------------------------------------
-- 
-- EE119 HW9 Sophia Liu
-- 
-- GCD.vhd
--
-- This entity calculates the GCD of a and b, 16-bit operands. 
-- It takes as inputs the system clock, calculate user input, a and b operands,
-- and control signal can_read_vals. It outputs the 16-bit GCD result and 
-- result_rdy to indicate a valid result. If either a or b are zero, the 
-- non-zero value (if any) will be outputted as the result. 
-- A Moore state machine is used to calculate the GCD using Stein's algorithm. 
--
-- Inputs
-- 	sysclk 	: std_logic - system clock  
--
--    a 			: std_logic_vector(15 downto 0) - first 16-bit operand 
--
--    b			: std_logic_vector(15 downto 0) - second 16-bit operand 
--
--    can_read_vals	: std_logic - synchronous control signal 
-- 										- indicating when calculation must be 
-- 										- completed
--
--		calculate      : std_logic - unsynchrnoized active-low user input
--											- indicates when a GCD calculation 
-- 										- should be done
--	
-- Outputs 
-- 	result   		:  std_logic_vector(15 downto 0) - 16-bit GCD of a, b 
--		result_rdy 		:  std_logic - control signal, active when result is valid
--
-- Revision History:
-- 12/06/18 Sophia Liu Initial revision
-- 12/08/18 Sophia Liu GCD revision 
-- 12/11/18 Sophia Liu Updated comments 
--
----------------------------------------------------------------------------

-- GCD entity 
entity GCD is 
	  port(
			sysclk			:  in  std_logic;
			a					:  in  std_logic_vector(15 downto 0);
			b					:  in  std_logic_vector(15 downto 0);
			can_read_vals	:  in  std_logic;
			calculate      :  in  std_logic; 
			result   		:  out std_logic_vector(15 downto 0); 
			result_rdy 		:  out std_logic 
	  );
end GCD;

-- GCD architecture
architecture GCD of GCD is 
	-- GCD calculation signals 
	-- flag for storing calculate button input 
	signal calculateGCD : std_logic; 
	
	-- power of 2 multiplier for final GCD result 
	-- max a, b = 2^16 - 1; max k = 15
	signal k : integer range 0 to 15; 
	
	-- buffers for storing a and b inputs 
	signal aBuf : std_logic_vector(15 downto 0);
	signal bBuf : std_logic_vector(15 downto 0);
	-- t used during calculations
	signal t : std_logic_vector(16 downto 0);
	
	-- subtraction signals for a - b
	signal subResultBit : std_logic; -- difference  
	signal subCarryOut : std_logic;	-- carry out bit 
	signal carryFlag : std_logic;    -- storage fo carry out
	
	-- constant for subtraction setting
	constant  SUBTRACT : std_logic := '1'; 
	
	 -- 
	 signal shiftCount : integer range 0 to 15; 
	-- done with subtraction once subtracted all 16 bits of a and b 
	constant SUBDONE : integer := 15;  
	
	 -- constants for vectors of zero 
	 constant ZERO16 : std_logic_vector(15 downto 0) := "0000000000000000";
	 constant ZERO17 : std_logic_vector(16 downto 0) := "00000000000000000"; 
	 
	-- states for GCD FSM 
	type GCDStates is (
		IDLE,		-- idle state, waiting for calculate and can_read_vals input 
		EVEN,    -- remove common powers of 2 from a, b
		TSET,    -- set initial t value for calculations (t = -b or a) 
		TEVEN,   -- divide t by 2 while t is even 
		TLARGE,  -- re-set a or b to t or -t
		SUBBIT,  -- subtract and store LSB of a and b
		SHIFT,	-- Shift a and b to subtract next bit  
		DONE     -- finished once t = 0, have GCD of a and b
	);

	-- state variable, initialize as IDLE state
	signal curState : GCDStates := IDLE; 
	 
	begin 
	
	-- one-bit subtracter that subtracts LSB of a and b (a(0) - b(0))
   -- difference is subResultBit, carry out bit is subCarryOut
    subResultBit <= bBuf(0) xor SUBTRACT xor aBuf(0) xor carryFlag;
    subCarryOut  <= (aBuf(0) and CarryFlag) or
                     ((bBuf(0) xor SUBTRACT) and aBuf(0)) or
                     ((bBuf(0) xor SUBTRACT) and carryFlag);
	
	-- Moore state machine for calculating GCD using Stein's algorithm
	process(sysclk) 
	begin 	
		if rising_edge(sysclk) then  
		case curState is
				-- leave idle state only when can_read_vals is active and 
			   -- the calculate button has been pressed 
				when IDLE =>
					result_rdy <= '0';  -- GCD has not been calculated yet
					if calculateGCD = '1' and  can_read_vals = '1' then
						-- store the current a, b inputs in buffers 
						aBuf <= a; 
						bBuf <= b;  
						k <= 0; -- reset k to 0
						curState <= EVEN; -- move to EVEN state
					else  
						curState <= IDLE; -- otherwise wait in IDLE
					end if; 
					
				-- while both a and b are even, divide a and b by two, 
				-- increment k counter 
				when EVEN => 
					-- handle zero case - return nonzero number if there is one
					if aBuf = ZERO16 then
						aBuf <= bBuf; 
						curState <= DONE; 
					elsif bBuf = ZERO16 then 
						curState <= DONE; 
					-- can proceed if neither a, b are zero 
					elsif aBuf(0) = '0' and bBuf(0) = '0' then 
						-- if both a and b are even, shift and increment k
						k <= k + 1;  
						aBuf <= '0' & aBuf(15 downto 1); -- divide a by 2
						bBuf <= '0' & bBuf(15 downto 1); -- divide b by 2
						curState <= EVEN; -- loop to check if they are still even
					else  
						-- Proceed to set t state
						curState <= TSET;
					end if; 
				
				-- set initial t value based on a 
				when TSET => 
					if aBuf(0) = '1' then 		-- if a is odd
						t <= std_logic_vector(-signed('0' & bBuf)); -- t = -b
					elsif aBuf(0) = '0' then 	-- if a is even
						t <= '0' & aBuf; 			-- t = a 
					else -- otherwise a(0) is an undefined value 
						t <= (others => 'X'); 	-- set t to be undefined (for simulation)
					end if; 
					-- proceed to loop while t is not 0 
					curState <= TEVEN; 
				
				-- divide t by 2 if t is even
				when TEVEN => 
					if t = ZERO17 then 
						curState <= DONE; 				-- stop looping when t = 0 
					elsif t(0) = '0' then 				-- if t is even  
						t <= t(16) & t(16 downto 1);  -- divide t by 2 (arithmetic shift) 
						curState <= TEVEN; 				-- loop to check if t is still even
					elsif t(0) = '1' then  				-- if t is odd
						curState <= TLARGE; 				-- proceed to next state
					else								-- otherwise t includes undefined values 
						t <= (others => 'X');  	-- set t to undefined (for simulation) 
						curState <= TEVEN; 	  	-- loop here (for simulation) 
					end if; 
					
				-- re-assign a or b depending on t 
				when TLARGE => 
					if t(16) =  '1' or t = ZERO17 then 							-- if t <= 0
						bBuf <= std_logic_vector(-signed(t(15 downto 0))); -- set b = -t 
					else 								-- otherwise t > 0
						aBuf <= t(15 downto 0); -- set a = t 
					end if; 
					-- next perform t = a - b
					-- initialize signals for subtracting a and b
					shiftCount <= 0;				-- reset bits subtracted to 0
					carryFlag <= '1'; 			-- reset carry flag to 1
					curState <= SUBBIT;			-- proceed to subtract
			
				-- subtract LSB of a, b, and store in t
				when SUBBIT => 
					t(15) <= subResultBit;   	-- save  a(0) - b(0)
					carryFlag <= subCarryOut; 	-- save next carry flag 
					curState <= SHIFT; 			-- proceed to rotate a, b, t
				
				-- rotate a and b to subtract next bit and shift t
				when SHIFT => 
					-- rotate a, b right 
					aBuf <= aBuf(0) & aBuf(15 downto 1); 
					bBuf <= bBuf(0) & bBuf(15 downto 1); 
					if shiftCount > SUBDONE - 1 then -- finished subtracting
					   t(16) <= not(carryFlag); 		-- set sign bit of t 
						curState <= TEVEN;            -- move to top of loop 
					else 										-- not done subtracting
						t <= t(16) & t(16 downto 1);  -- shift t to store next a-b
						shiftCount <= shiftCount + 1; -- increment subtracted bits count 
						curState <= SUBBIT;           -- continue subtracting next bit 
					end if;
				
				-- finished with GCD calculation 
				when DONE => 	
					-- GCD is a * 2^k 
					result <= std_logic_vector(unsigned(aBuf) sll k); 
					result_rdy <= '1'; -- pull result_rdy high  
					curState <= IDLE;  -- go back to idle state 
			end case;
		end if;  	
	end process; 
	
	 -- storage for when calculation button has been pressed, 
	 -- synchronizes active low calculate input.
	 -- clears once GCD calculation has completed
	 process(sysclk) 
	 begin 
		if rising_edge(sysclk) then 
			-- store active low calculate input
			if calculate = '0' then 
				calculateGCD <= '1'; 
			elsif curState = DONE then  
				-- finished with calculation when current state is DONE
				calculateGCD <= '0';  
			end if; 
		end if; 
	 end process; 
	
end GCD; 