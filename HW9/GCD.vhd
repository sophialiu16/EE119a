----------------------------------------------------------------------------
-- 
-- EE119 HW9 Sophia Liu
-- 
-- GCD.vhd
--
-- Description
--
-- Inputs
--
-- Outputs
--
-- Revision History:
-- 12/06/18 Sophia Liu Initial revision
-- 12/08/18 Sophia Liu Updated comments
--
----------------------------------------------------------------------------
--
--The inputs to the component are sysclk (the system clock),
-- calculate (the undebounced and unsychronized user input to indicate a 
-- GCD calculation should be done), a[15:0] (first 16-bit operand), b[15:0]
-- (second 16-bit operand), and can_read_vals (a synchronous control signal). 
-- The control signal (can_read_vals) is active when the values on a[15:0] and b[15:0] 
-- are valid. This signal will be active for approximately 32,000 system clocks (sysclk) 
-- and will go active approximately every 400,000 system clocks (sysclk). The user designed
-- component must generate two signals from these inputs, result[15:0] (the 16-bit computation result)
-- and result_rdy (indicates a valid result). The result_rdy signal is used to latch the value on the 
-- result bus and must go active during the time the can_read_vals signal is active.

library ieee; 
use ieee.std_logic_1164.all; 
use ieee.numeric_std.all;
use ieee.std_logic_signed.all;

entity GCD is 
        port(
            sysclk			:  in  std_logic; -- system clock 
            a					:  in  std_logic_vector(15 downto 0);
            b					:  in  std_logic_vector(15 downto 0);
            can_read_vals	:  in  std_logic;
				calculate      :  in  std_logic; 
				
            result   		:  out std_logic_vector(15 downto 0); 
				result_rdy 		:  out std_logic 
        );
end GCD; 

architecture GCD of GCD is 

	-- internal signals
	signal calculateGCD : std_logic; 
	
	--max a, b = 2^16; max k = 16
	signal k : integer range 0 to 15; --std_logic_vector(4 downto 0); -- 3?; TODO rage
	
	signal aBuf : std_logic_vector(15 downto 0);
	signal bBuf : std_logic_vector(15 downto 0);
	
	signal t : std_logic_vector(16 downto 0);
	
	-- subtraction signals 
	signal subResultBit : std_logic; 
	signal subCarryOut : std_logic;
	signal carryFlag : std_logic; 
	constant  SUBTRACT : std_logic := '1'; 
	 
	 constant ZERO16 : std_logic_vector(15 downto 0) := "0000000000000000";
	 
	 signal shiftCount : integer range 0 to 15; 
	 
	 	-- Moore state machine for unsigned multiplier
	type GCDStates is (
		IDLE,		-- Idle state, waiting for start input 
		EVEN, 
		TSET,
		TEVEN,
		TLARGE,
		SUBBIT,
		SHIFT,	-- Shift product register 
		DONE   -- Finished multiplying 
	);

	signal curState : GCDStates := IDLE; -- State variable
	 
	begin 
	
	-- one-bit adder/subtracter (operation determined by Divisor input)
    -- adds/subtracts low bits of the divisor and reminder generating
    --    CalcResultBit and CalcCarryOut
	 -- a - b
    subResultBit <= bBuf(0) xor SUBTRACT xor aBuf(0) xor carryFlag;
    subCarryOut  <= (aBuf(0) and CarryFlag) or
                     ((bBuf(0) xor SUBTRACT) and aBuf(0)) or
                     ((bBuf(0) xor SUBTRACT) and carryFlag);
	
	
	-- calculate GCD 
	process(sysclk) 
	begin 	
		if rising_edge(sysclk) then  
		case curState is
				when IDLE =>
					result_rdy <= '0';  
					if calculateGCD = '1' and  can_read_vals = '1' then  -- TODO begin calculate signal  
						aBuf <= a; 
						bBuf <= b;  
						k <= 0;
						curState <= EVEN;
					else 
						curState <= IDLE; 
					end if; 
					
				when EVEN => 
					if aBuf = ZERO16 then -- handle zero case (both zero will return 0)
						aBuf <= bBuf; 
						curState <= DONE; 
					elsif bBuf = ZERO16 then 
						curState <= DONE; 
					elsif aBuf(0) = '0' and bBuf(0) = '0' then 
						k <= k + 1;  
						aBuf <= '0' & aBuf(15 downto 1); 
						bBuf <= '0' & bBuf(15 downto 1); 
						curState <= EVEN; 
					else  
						curState <= TSET;
					end if; 
				
				when TSET => 
					if aBuf(0) = '1' then 
						t <= std_logic_vector(-signed('0' & bBuf)); --TODO valid?
					elsif aBuf(0) = '0' then 
						t <= '0' & aBuf;  
					else 
						t <= (others => 'X'); -- undefined
					end if; 
					curState <= TEVEN; 
				
				when TEVEN => 
					if t = '0' & ZERO16 then 
						curState <= DONE;
					elsif t(0) = '0' then 
						t <= t(16) & t(16 downto 1);  
						curState <= TEVEN; 
					elsif t(0) = '1' then 
						curState <= TLARGE; 
					else 
						t <= (others => 'X');  -- undefined
						curState <= TEVEN; 
					end if; 
				
				when TLARGE => 
					if t(16) =  '1' or t = '0' & ZERO16 then 
						bBuf <= std_logic_vector(-signed(t(15 downto 0))); 
					else -- t > 0 
						aBuf <= t(15 downto 0); 
					end if; 
					shiftCount <= 0;
					carryFlag <= '1'; 
					curState <= SUBBIT;
			
				
				when SUBBIT => 
					t(15) <= subResultBit; 
					carryFlag <= subCarryOut; 
					curState <= SHIFT; 
				
				when SHIFT => 
					aBuf <= aBuf(0) & aBuf(15 downto 1); 
					bBuf <= bBuf(0) & bBuf(15 downto 1); 
					if shiftCount > 14 then 
					   t(16) <= not(carryFlag); 
						curState <= TEVEN;
					else 
						t <= t(16) & t(16 downto 1);
						shiftCount <= shiftCount + 1; 
						curState <= SUBBIT;
					end if;
				
				when DONE => 	
					result <= std_logic_vector(unsigned(aBuf) sll k); 
					result_rdy <= '1'; 
					--if can_read_vals = '1' then 
					curState <= IDLE; 
					--else 
					--	curState <= DONE; -- wait until can_read_vals high?
					--end if; 
		end case;
		end if;  	
	end process; 
	
	
	 -- debounce calculate?  
	 -- storage for when calculation button has been pressed, 
	 -- clears once GCD has completed
	 process(sysclk) 
	 begin 
		if rising_edge(sysclk) then 
			if calculate = '0' then --TODO active low?
				calculateGCD <= '1'; -- store active low calculate input
			elsif curState = DONE then  
				calculateGCD <= '0';  
			end if; 
		end if; 
	 end process; 
	
end GCD; 