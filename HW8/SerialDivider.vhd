----------------------------------------------------------------------------
--
--  16-bit Adder/Subtracter for EE 119 Serial Divider Board
--
--  This file contains a design for taking input from the keypad and
--  displaying it on the 7-segment LEDs.  When the calculate button is
--  pressed, either the sum or difference of the two input 16-bit values is
--  computed (depending on the position of the Divisor switch).  The input
--  and displayed values are in hexadecimal.  For both input values only the
--  last 4 hex digits (16-bits) are used.
--
--  Revision History:
--     25 Nov 18  Glen George       Initial version (from 11/21/09 version
--                                     of addsub16.abl)
--     27 Nov 18  Glen George       Changed HaveKey logic to be flip-flop
--                                     based instead of an implied latch.
--     27 Nov 18	Sophia Liu			Used adder/subtracter for initial 
-- 												divider template
--
----------------------------------------------------------------------------



-- libraries
library  ieee;
use  ieee.std_logic_1164.all;
use  ieee.numeric_std.all;



--
--  SerialDivider entity declaration
--
--  The entity takes input from the keypad and display it on the 7-segment
--  LEDs.  When the calculate button is pressed, either the sum or difference
--  of the two input 16-bit values is computed (depending on the position of
--  the Divisor switch).  The input values and sum/difference are displayed
--  in hexadecimal.  For both input values only the last 4 hex digits
--  (16-bits) are used.
--
--  Inputs:
--     nReset                 - active low reset signal (for testing only)
--                              tied high in hardware
--     nCalculate             - calculate the quotient (active low)
--     Divisor                - input the divisor (not the dividend)
--     KeypadRdy              - there is a key available
--     Keypad(3 downto 0)     - keypad input
--     CLK                    - the clock (1 MHz)
--
--  Outputs:
--     HexDigit(3 downto 0)   - hex digit to display (to segment decoder)
--     DecoderEn              - enable for the 4:12 digit decoder
--     DecoderBit(3 downto 0) - digit to display (to 4:12 decoder)
--
--  Revision History:
--     23 Nov 18  Glen George       initial revision
--

entity  SerialDivider  is

    port (
        nReset      :  in   std_logic;
        nCalculate  :  in   std_logic;
        DivisorSelIn  :  in   std_logic;
        KeypadRdy   :  in   std_logic;
        Keypad      :  in   std_logic_vector(3 downto 0);
        HexDigit    :  out  std_logic_vector(3 downto 0);
        DecoderEn   :  out  std_logic;
        DecoderBit  :  out  std_logic_vector(3 downto 0);
		  DivideDoneOut : out std_logic; 
        
		  CLK         :  in   std_logic;
		  
		  KeypadRow   :  in   std_logic_vector(3 downto 0); 
		  KeypadCol   :  in   std_logic_vector(3 downto 0); 
		  DigitSel    :  out  std_logic_vector(11 downto 0); 
--		  Divisor	  :  in   std_logic; 
--		  Calculate   :  in   std_logic; 
--		  HexDigit    :  out  std_logic_vector(3 downto 0); 
--		  DecoderEn   :  out  std_logic; 
--		  DecoderBit  :  out  std_logic_vector(3 downto 0); 
--		  Digit       :  out  std_logic_vector(11 downto 0); 
		  Segments     :  out  std_logic_vector(6 downto 0)
		  --TODO separate structure
    );

end  SerialDivider;


--
--  AddSub16 architecture
--

architecture  demo  of  SerialDivider  is

	 signal Remainder: std_logic_vector(16 downto 0);
	 signal NextRemainder: std_logic_vector(15 downto 0);
	 signal Quotient: std_logic_vector(15 downto 0); 
	 signal Divisor: std_logic_vector(15 downto 0);
	 signal Dividend : std_logic_vector(15 downto 0);

    -- keypad signals
    signal  HaveKey     :  std_logic;           -- have a key from the keypad
    signal  KeypadRdyS  :  std_logic_vector(2 downto 0); -- keypad ready synchronization

    -- LED multiplexing signals
    signal  MuxCntr  :  unsigned(9 downto 0);   -- multiplex counter (to
                                                --    divide 1 MHz to 1 KHz)
    signal  DigitClkEn  :  std_logic;           -- enable for the digit clock
    signal  CalcInEn    :  std_logic;           -- near end of a muxed digit
                                                --    (to enable calculations)
    signal  CurDigit  :  std_logic_vector(3 downto 0); -- current mux digit

    --  12 stored hex digits and remainder (65 bits) in a shift register
    --signal  DivShiftReg  :  std_logic_vector(64 downto 0) := "00000000000000000" 
	 --& "0000000000000000" & "0000000000001011" & "0000000010001001";

    --  adder/subtracter signals
    signal  CalcResultBit  :  std_logic;        -- sum/difference output
    signal  CalcCarryOut   :  std_logic;        -- carry/borrow out
    signal  CarryFlag      :  std_logic;        -- stored carry flag
	 
	 signal Subtract : std_logic; -- subtract when = 1 , add when 0 

	signal SignResultBit : std_logic;  
	
	signal CalculateQ : std_logic; 
	
	signal DivideDone : std_logic; 
	
	signal DivisorSel : std_logic; 

begin

    -- one-bit adder/subtracter (operation determined by Divisor input)
    -- adds/subtracts low bits of the operands (bits 0 and 16) generating
    --    CalcResultBit and CalcCarryOut
    CalcResultBit <= Divisor(0) xor Subtract xor Remainder(0) xor CarryFlag;
    CalcCarryOut  <= (Remainder(0) and CarryFlag) or
                     ((Divisor(0) xor Subtract) and Remainder(0)) or
                     ((Divisor(0) xor Subtract) and CarryFlag);
							
							
	 -- partial adder for calculating the next remainder sign bit
    SignResultBit <= Remainder(16) xor Subtract xor CarryFlag;


    -- counter for mux rate of 1 KHz (1 MHz / 1024)

    process(CLK)
    begin

        -- count on the rising edge (clear on reset)
        if rising_edge(CLK) then
            if (nReset = '0') then
                MuxCntr <= (others => '0'); --0;
            else
                MuxCntr <= MuxCntr + 1;
            end if;
        end if;

    end process;
	 
	 
	 DigitClkEn  <=  '1'  when (MuxCntr = "1111111111")  else
                    '0';
	 	 
	 DivideDoneOut <= DivideDone; 
	 --Remainder <= DivShiftReg(64 downto 48); 
	 --Quotient <= (47 downto 32); 
	 --Divisor <= DivShiftReg(31 downto 16); 
	 --Dividend <= DivShiftReg(15 downto 0); 
	 process(CLK) 
	 begin 
		if rising_edge(CLK) then 
			if nCalculate = '0' then 
				CalculateQ <= '1'; 
			end if; 
			if DivideDone = '1' then 
				CalculateQ <= '0'; -- stop dividing only after finished operation 
			end if; 
		end if; 
	 end process; 
	 
	 
	 process(CLK) --TODO need?
	 begin 
		if rising_edge(CLK) then 
			DivisorSel <= DivisorSelIn;
		end if; 
	 end process; 
	 
	 -- main dividing 
	process(CLK)	
	begin 
		if rising_edge(clk) then 
			-- reset the decoder to 3 on reset
			if (nReset = '0') then
				Subtract <= '1'; 
				DivideDone <= '0'; 
				CarryFlag <= '1'; 
				Remainder 	<= "00000000000000000";
				NextRemainder <= "0000000000000000"; --TODO move?
			   Quotient  	<=	"0000000000000000";
				Divisor 		<= "0000000000000101";
			   Dividend		<= "0000000011100101"; --TODO for testing
									
			elsif (DigitClkEn = '1' and not (CurDigit = "1100")) then 
				-- shift to next displayed digit 
				--DivShiftReg <= DivShiftReg(64 downto 48) & DivShiftReg(3 downto 0) & DivShiftReg(47 downto 4);
				Dividend <= Divisor(3 downto 0) & Dividend(15 downto 4); 
				Divisor <= Quotient(3 downto 0) & Divisor (15 downto 4); 
				Quotient <= Dividend (3 downto 0) & Quotient(15 downto 4); 
				
				CarryFlag <= '1'; -- initial subtraction settings
				Subtract <= '1';
				DivideDone <= '0'; --TODO move
			elsif (std_match(MuxCntr, "1000000000") and CalculateQ = '1' and CurDigit = "1100") then 
				-- finished dividing
				DivideDone <= '1';  
			elsif (std_match(MuxCntr, "0----00000") and CalculateQ = '1'and CurDigit = "1100") then 
				-- start dividing 
				Remainder <= Remainder(15 downto 0) & Dividend(15);
			elsif (CalculateQ = '1' and CurDigit = "1100" and 
						(std_match(MuxCntr, "0----0----") or std_match(MuxCntr, "0----10000"))) then 
				-- rotate 16 times 
				CarryFlag <= CalcCarryOut; 
				
				Remainder <= Remainder(16) & Remainder(0) & Remainder(15 downto 1); 
				Divisor <= std_logic_vector(unsigned(Divisor) ror 1); 
				NextRemainder <= CalcResultBit & NextRemainder(15 downto 1); 
				
			elsif (CalculateQ = '1' and CurDigit = "1100" and std_match(MuxCntr, "0----10001")) then 
			   Subtract <= not SignResultBit; 
				Dividend <= Dividend(14 downto 0) & Remainder(0);
				Remainder <= SignResultBit & NextRemainder; 
				Quotient <= Quotient(14 downto 0) & (not SignResultBit);
				
			elsif (std_match(MuxCntr, "11-------0") and --(calculateQ = '0') and
					(HaveKey = '1') and (((CurDigit = "0011") and (DivisorSel = '0')) or
                                       ((CurDigit = "0111") and (DivisorSel = '1')))) then 
			  Quotient <= Quotient(11 downto 0) & Keypad; 
				--
			end if;
		end if; 	  
	 end process; 
	 
	 
	 -- handle key input 
	 
	 -- edge (and key) detection on KeypadRdy
    process(CLK)
    begin

        if rising_edge(CLK) then

            -- shift the keypad ready signal to synchronize and edge detect
            KeypadRdyS  <=  KeypadRdyS(1 downto 0) & KeypadRdy;

            -- have a key if have one already that hasn't been processed or a
            -- new one is coming in (rising edge of KeypadRdy), reset if on
            -- the last clock of Digit 3 or Digit 7 (depending on position of
            -- Divisor switch) and held otherwise
            if  (std_match(KeypadRdyS, "01-")) then
                -- set HaveKey on rising edge of synchronized KeypadRdy
                HaveKey <=  '1';
            elsif ((DigitClkEn = '1') and (CurDigit = "0011") and (DivisorSel = '0')) then
                -- reset HaveKey if on Dividend and current digit is 3
                HaveKey <=  '0';
            elsif ((DigitClkEn = '1') and (CurDigit = "0111") and (DivisorSel = '1')) then
                -- reset HaveKey if on Divisor and current digit is 7
                HaveKey <=  '0';
            else
                -- otherwise hold the value
                HaveKey <=  HaveKey;
            end if;

        end if;

    end process;
	 
	 -- handle keypress (TODO merge)
	 process(CLK) 
	 begin
	 
	 end process; 
	 
	 
	 

    -- create the counter for output the current digit - order is 3, 2, 1, 0,
    --    7, 6, 5, 4, 11, 10, 9, 8, then 12
    -- reset counter to 3, only increment if DigitClkEn is active

    process (CLK)
    begin

        if (rising_edge(CLK)) then

            -- reset the decoder to 3 on reset
            if (nReset = '0') then
                CurDigit <= "0011"; --TODO add more digits, calculate later

            -- create the appropriate count sequence
            elsif (DigitClkEn = '1') then
                CurDigit(0) <= not CurDigit(0);
                CurDigit(1) <= CurDigit(1) xor not CurDigit(0);
                if (std_match(CurDigit, "0-00")) then
                    CurDigit(2) <= not CurDigit(2);
                end if;
                if (std_match(CurDigit, "-100") or std_match(CurDigit, "1-00")) then
                    CurDigit(3) <= not CurDigit(3);
                end if;
					 if (std_match(CurDigit, "1000")) then 
						  CurDigit <= "1100";  
					 end if; 
					 if (std_match(CurDigit, "1100")) then 
						  CurDigit <= "0011"; --TODO simplify logic 
					 end if; 
            -- otherwise hold the current value
            else
                CurDigit <= CurDigit;

            end if;
        end if;

    end process;


    -- always enable the digit decoder
    DecoderEn  <=  '1';

    -- output the current digit to the digit decoder
    DecoderBit  <=  CurDigit;


    -- the hex digit to output is just the low nibble of the shift register
    HexDigit  <=  Dividend(3 downto 0);



end  demo;