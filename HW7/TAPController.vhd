----------------------------------------------------------------------------
-- 
-- JTAG Test Access Port (TAP) Controller 
-- EE119 HW7 Sophia Liu
--
-- This is a simplified implementation of a TAP controller for the JTAG 
-- debugging interface. Four synchronous signals, TCK, TMS, TDI, TDO, and 
-- a reset signal are used to control a 7 bit instruction register (IR) and 
-- 32 bit data register (DR). Bits are serially shifted into a register 
-- via TDI and shifted out via TDO, MSB first. 
--
-- This is implemented with a Moore state machine, which is controlled 
-- via the TMS input signal. The state machine begins from a reset state, 
-- and moves through the idle state to select either the DR or IR, and 
-- then can shift data in and out of either register, pausing and exiting 
-- as necessary.   
--
-- Inputs: 
-- 	TRST: std_logic - active high reset signal for the state machine 
--    TMS: std_logic - test mode select signal for controlling the interface
-- 	TDI: std_logic - test data in signal, used to shift bits into registers
--    TCK: std_logic - test clock signal 
-- 
-- Outputs: 
--		TDO: std_logic - test data out signal, used to shift data from registers
--
-- Revision History:
-- 11/21/18 Sophia Liu Initial revision
-- 11/22/18 Sophia Liu Updated comments
--
----------------------------------------------------------------------------

library ieee; 
use ieee.std_logic_1164.all; 
use ieee.numeric_std.all;

entity TAPController is 
        port(
            TRST  :  in  std_logic;		-- test reset signal 
            TMS   :  in  std_logic;		-- test mode select signal
            TDI   :  in  std_logic;		-- test data in signal
            TCK   :  in  std_logic;		-- test clock signal
            TDO   :  out std_logic		-- test data out signal
        );
end TAPController; 

architecture TAP of TAPController is 
	-- states for TAP moore state machine 
	type TAPStates is (
	LogicReset, 	-- reset state
	Idle, 			-- idle state
	-- states for selecting, inputting, and reading from DR
	SelectDR, 		-- select DR for TDO 
	CaptureDR, 
	ShiftDR,			-- shift data in/out of DR via TDI/TDO
	ExitDR, 
	PauseDR, 
	Exit2DR,
	UpdateDR,		
	-- states for selecting, inputting, and reading from IR 
	SelectIR, 		-- select IR for TDO 
	CaptureIR, 
	ShiftIR, 		-- shift data in/out of IR via TDI/TDO
	ExitIR, 
	PauseIR, 
	Exit2IR, 
	UpdateIR
	); 
	-- state variable for TAP state machine, beginning on reset state
	signal curState : TAPStates := LogicReset; 
	
	-- constants for size of DR and IR 
	constant DRBITS: integer := 32;
	constant IRBITS: integer := 7;
	
	-- implementation of data register and instruction register
	signal DR : std_logic_vector(DRbits - 1 downto 0); 
	signal IR : std_logic_vector(IRbits - 1 downto 0); 
	
	-- select signal for TDO mux
	signal TDOSel : std_logic := 'X'; -- '0' selects DR, '1' selects IR 
	
	begin 
	
	process(TCK)
		begin 
		if rising_edge(TCK) then 
			if TRST = '1' then -- Reset override
				curState <= LogicReset; 
			else 
				case curState is 
					when LogicReset => 
						-- reset until TMS is inactive
						if TMS = '0' then 
							curState <= Idle; -- next move to idle state
						else -- TMS = '1'
							curState <= LogicReset; 
						end if; 
					
					when Idle => 
						-- stay in idle state until TMS active
						if TMS = '1' then 
							curState <= SelectDR; -- move to select DR
						else -- TMS = '0' 
							curState <= Idle; 
						end if;
					
					when SelectDR => 
							TDOSel <= '0';  -- currently selecting top of DR 
						if TMS = '1' then  -- select IR instead if TMS is active
							curState <= SelectIR; 
						else -- TMS = '0' 
							curState <= CaptureDR; -- otherwise move to capture DR state
						end if;
						
					when CaptureDR => 
						-- exit DR if TMS is active, otherwise move to shifting state
						if TMS = '1' then 
							curState <= ExitDR; 
						else -- TMS = '0' 
							curState <= ShiftDR;
						end if;
					
					when ShiftDR => 
						-- shift TDI input into DR, MSB first
						DR <= std_logic_vector(unsigned(DR) sll 1); 
						DR(0) <= TDI; 
						if TMS = '1' then -- continue shifing unil TMS is active
							curState <= ExitDR; 
						else -- TMS = '0' 
							curState <= ShiftDR; 
						end if;
					
					when ExitDR => 
						-- next pause or update DR, depending on TMS
						if TMS = '1' then 
							curState <= UpdateDR; 
						else -- TMS = '0' 
							curState <= PauseDR; 
						end if;
						
					when PauseDR => 
						-- continue to exit once TMS is active
						if TMS = '1' then 
							curState <= Exit2DR; 
						else -- TMS = '0' 
							curState <= PauseDR; 
						end if;
					
					when Exit2DR => 
						-- move to update DR state, or continue shifting in/out of DR
						if TMS = '1' then 
							curState <= UpdateDR; 
						else -- TMS = '0' 
							curState <= ShiftDR; 
						end if;
						
					when UpdateDR => 
						-- Either select DR or move to idle state 
						if TMS = '1' then 
							curState <= SelectDR; 
						else -- TMS = '0' 
							curState <= Idle; 
						end if;
						
					when SelectIR => 
							TDOSel <= '1';  -- select top of IR 
						if TMS = '1' then  -- move to reset logic or capture IR state
							curState <= LogicReset; 
						else -- TMS = '0' 
							curState <= CaptureIR; 
						end if;
						
					when CaptureIR => 
						-- Exit if TMS is active, else move to shift in/out of IR
						if TMS = '1' then 
							curState <= ExitIR; 
						else -- TMS = '0' 
							curState <= ShiftIR; 
						end if;
					
					when ShiftIR => 
						-- Shift TDI input into IR, MSB first 
						IR <= std_logic_vector(unsigned(IR) sll 1); 
						IR(0) <= TDI; 
						if TMS = '1' then -- continue shifting until TMS is active
							curState <= ExitIR; 
						else -- TMS = '0' 
							curState <= ShiftIR; 
						end if;
					
					when ExitIR => 
						-- next pause or update IR, depending on TMS
						if TMS = '1' then 
							curState <= UpdateIR; 
						else -- TMS = '0' 
							curState <= PauseIR; 
						end if;
						
					when PauseIR => 
						-- continue to exit once TMS is active
						if TMS = '1' then 
							curState <= Exit2IR; 
						else -- TMS = '0' 
							curState <= PauseIR; 
						end if;
					
					when Exit2IR => 
						-- move to update DR state, or continue shifting in/out of DR
						if TMS = '1' then 
							curState <= UpdateIR; 
						else -- TMS = '0' 
							curState <= ShiftIR; 
						end if;
						
					when UpdateIR => 
						-- Either move to selecting states or move to idle state 
						if TMS = '1' then 
							curState <= SelectDR; 
						else -- TMS = '0' 
							curState <= Idle; 
						end if;
				end case; 
			end if;
			
		end if;
	end process; 
	
	--	TDO mux, selects from DR and IR 
	with TDOSel select 
		TDO <= DR(DRBITS - 1) when '0',  -- MSB of DR when select is '0'
				 IR(IRBITS - 1) when '1',  -- MSB of IR when select is '1'
 				 'X' when others; 			-- otherwise undefined (for simulations)
	
end TAP; 