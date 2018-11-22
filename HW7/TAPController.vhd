----------------------------------------------------------------------------
-- 
-- EE119 HW Sophia Liu
-- 
-- Name
--
-- Description
--
-- Ports:
--
-- Revision History:
-- 11/14/18 Sophia Liu Initial revision
-- 11/16/18 Sophia Liu Updated comments
--
----------------------------------------------------------------------------

library ieee; 
use ieee.std_logic_1164.all; 
use ieee.numeric_std.all;

entity TAPController is 
        port(
            TRST  :  in  std_logic;
            TMS   :  in  std_logic;
            TDI   :  in  std_logic;
            TCK   :  in  std_logic;
            TDO   :  out std_logic
        );
end TAPController; 

architecture TAP of TAPController is 
	type TAPStates is (
	LogicReset, 
	Idle, 
	
	SelectDR, 
	CaptureDR, 
	ShiftDR,
	ExitDR, 
	PauseDR, 
	Exit2DR,
	UpdateDR,
	
	SelectIR, 
	CaptureIR, 
	ShiftIR, 
	ExitIR, 
	PauseIR, 
	Exit2IR, 
	UpdateIR
	); 
	
	signal curState : TAPStates := LogicReset; 
	
	constant DRBITS: integer := 32;
	constant IRBITS: integer := 7;
	
	signal DR : std_logic_vector(DRbits - 1 downto 0); 
	signal IR : std_logic_vector(IRbits - 1 downto 0); 
	signal TDOSel : std_logic := '0'; -- '0' = DR, '1' = IR 
	
	begin 
	
	process(TCK)
		begin 
		if rising_edge(TCK) then 
			if TRST = '1' then -- Reset override
				curState <= LogicReset; 
			else 
				case curState is 
					when LogicReset => 
						if TMS = '0' then 
							curState <= Idle; 
						else -- TMS = '1'
							curState <= LogicReset; 
						end if; 
					
					when Idle => 
						if TMS = '1' then 
							curState <= SelectDR; 
						else -- TMS = '0' 
							curState <= Idle; 
						end if;
					
					when SelectDR => 
							TDOSel <= '0'; 
						if TMS = '1' then 
							curState <= SelectIR; 
						else -- TMS = '0' 
							curState <= CaptureDR; 
						end if;
						
					when CaptureDR => 
						if TMS = '1' then 
							curState <= ExitDR; 
						else -- TMS = '0' 
							curState <= ShiftDR;
						end if;
					
					when ShiftDR => 
							DR <= std_logic_vector(unsigned(DR) sll 1); 
							DR(0) <= TDI; 
						if TMS = '1' then 
							curState <= ExitDR; 
						else -- TMS = '0' 
							curState <= ShiftDR; 
						end if;
					
					when ExitDR => 
						if TMS = '1' then 
							curState <= UpdateDR; 
						else -- TMS = '0' 
							curState <= PauseDR; 
						end if;
						
					when PauseDR => 
						if TMS = '1' then 
							curState <= Exit2DR; 
						else -- TMS = '0' 
							curState <= PauseDR; 
						end if;
					
					when Exit2DR => 
						if TMS = '1' then 
							curState <= UpdateDR; 
						else -- TMS = '0' 
							curState <= ShiftDR; 
						end if;
						
					when UpdateDR => 
						if TMS = '1' then 
							curState <= SelectDR; 
						else -- TMS = '0' 
							curState <= Idle; 
						end if;
						
					when SelectIR => 
							TDOSel <= '1'; 
						if TMS = '1' then 
							curState <= LogicReset; 
						else -- TMS = '0' 
							curState <= CaptureIR; 
						end if;
						
					when CaptureIR => 
						if TMS = '1' then 
							curState <= ExitIR; 
						else -- TMS = '0' 
							curState <= ShiftIR; 
						end if;
					
					when ShiftIR => 
							IR <= std_logic_vector(unsigned(IR) sll 1); 
							IR(0) <= TDI; 
						if TMS = '1' then 
							curState <= ExitIR; 
						else -- TMS = '0' 
							curState <= ShiftIR; 
						end if;
					
					when ExitIR => 
						if TMS = '1' then 
							curState <= UpdateIR; 
						else -- TMS = '0' 
							curState <= PauseIR; 
						end if;
						
					when PauseIR => 
						if TMS = '1' then 
							curState <= Exit2IR; 
						else -- TMS = '0' 
							curState <= PauseIR; 
						end if;
					
					when Exit2IR => 
						if TMS = '1' then 
							curState <= UpdateIR; 
						else -- TMS = '0' 
							curState <= ShiftIR; 
						end if;
						
					when UpdateIR => 
						if TMS = '1' then 
							curState <= SelectDR; 
						else -- TMS = '0' 
							curState <= Idle; 
						end if;
				end case; 
			end if;
			
		end if;
	end process; 
	
--	process(TDOSel, DR, IR) 
--	begin 
--			-- TDO mux
--		if TDOSel = '0' then 
--			TDO <= DR(DRBITS - 1); 
--		elsif TDOSel = '1' then 
--			TDO <= IR(IRBITS - 1); 
--		else 
--			TDO <= 'X'; 
--		end if; 
--	end process; 
--	
	with TDOSel select 
		TDO <= DR(DRBITS - 1) when '0', 
				 IR(IRBITS - 1) when '1',
				 'X' when others; 
	
end TAP; 