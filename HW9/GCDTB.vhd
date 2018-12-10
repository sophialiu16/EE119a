----------------------------------------------------------------------------
--
--  Test Bench for GCD.vhd
--
--  This is a test bench for the GCD entity. The test bench
--  thoroughly tests the entity by exercising it and checking the outputs
--  through the use of an array of test values (TestVector). The test bench
--  entity is called GCDTB.
--
--  Revision History:
--      4/4/00   Automated/Active-VHDL    Initial revision.
--      12/09/18 Sophia Liu               Update for GCD
--
----------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity GCDTB is
end GCDTB;

architecture TB_ARCHITECTURE of GCDTB is


    -- Component declaration of the tested unit
    component GCD
		 port (
				sysclk			:  in  std_logic; -- system clock 
            a					:  in  std_logic_vector(15 downto 0);
            b					:  in  std_logic_vector(15 downto 0);
            can_read_vals	:  in  std_logic;
				calculate      :  in  std_logic; 
				
            result   		:  out std_logic_vector(15 downto 0); 
				result_rdy 		:  out std_logic
		 );
    end component;
	 

    -- Stimulus signals - signals mapped to the input and inout ports of tested entity
	 signal  a           : std_logic_vector(15 downto 0); 
	 signal  b           : std_logic_vector(15 downto 0); 
    signal  calculate  	:  std_logic;
	 signal  can_read_vals   :  std_logic; 
    signal  CLK   :  std_logic;
	 
	 
    -- Observed signals - signals mapped to the output ports of tested entity
    signal  result : std_logic_vector(15 downto 0);  
	 signal result_rdy: std_logic;  

    -- Signal used to stop clock signal generators
    signal  END_SIM  :  BOOLEAN := FALSE;
	 
	 signal counter : integer := 0; 

    -- Test Input Vector, largely randomly generated 
    signal  TestVector  :  std_logic_vector(255 downto 0) 
	 := "0000000000011001" & "0000000001101110" & "0000000000011001" & -- 25, 110 
		 "0000000000111100" & "0000000001010100" & "0000000000111100" & -- 60, 84 
		 "0000000000011001" & "0000000000001011" & "0000000000011001" & -- 25, 11 
		 "0000000001000000" & "0000000001011000" & "0000000001000000" & -- 60, 84 
		 "0000000000000000" & "0000000000000000" & "1111111111111111" &
		 "1111111111111111"; 
		 
	 
	 constant CLKPERIOD : time := 20 ns;  -- 20 ns clock period 
begin

    -- Unit Under Test port maps
	UUT : GCD
        port map  (
				sysclk => CLK, 
				a => a,
				b => b, 
				can_read_vals => can_read_vals, 
				calculate => calculate,
				result => result,
				result_rdy => result_rdy
        );
		  
    -- now generate the stimulus and test the design
    process

			variable  i  :  integer;        -- general loop index
			
			-- variables for checking for successful tests 
			variable  ResultMatch   	:  std_logic_vector(15 downto 0);
		  
		  begin 
		  
		  -- initially everything is X, have not started
		  	a  <= "XXXXXXXXXXXXXXXX";  
			b  <= "XXXXXXXXXXXXXXXX";
			calculate  	<= 'X';
			wait for 5*CLKPERIOD; 
			calculate <= '1';
			wait for 5*CLKPERIOD;	
			
			
         for i in 0 to TestVector'high loop
				A <= TestVector(15 downto 0); -- assign multiplicand and multiplier
				B <= TestVector(31 downto 16); 
				wait for 10 * CLKPERIOD;  
				
				calculate <= '0'; 
				wait for 5 * CLKPERIOD;	
				calculate <= '1';
				
				if result_rdy /= '1' then 		
					wait until result_rdy = '1';
				end if; 
				-- check result 
				wait for 5 * CLKPERIOD; 
			  
				-- rotate through test vector 
				TestVector <= std_logic_vector(unsigned(TestVector) ror 16); 
				wait for 5 * CLKPERIOD; 
			end loop; 
		  
		  
--			wait for 100 ns; 
--			-- assign correct products for 2, 4, 16 bit multipliers
--			Q2Match := std_logic_vector(unsigned(A(1 downto 0)) * unsigned(B(1 downto 0))); 
--			Q4Match := std_logic_vector(unsigned(A(3 downto 0)) * unsigned(B(3 downto 0))); 
--			Q16Match := std_logic_vector(unsigned(A(15 downto 0)) * unsigned(B(15 downto 0))); 		
--			
--			
--			-- check for successful multiplication 
--			assert (std_match(Q2, Q2Match))
--                report  "Q2 failure"
--                severity  ERROR;

        END_SIM <= TRUE;        -- end of stimulus events
        wait;                   -- wait for simulation to end

    end process; -- end of stimulus process
    

    CLOCK_CLK : process
    begin

        -- this process generates a 20 ns 50% duty cycle clock
        -- stop the clock when the end of the simulation is reached
        if END_SIM = FALSE then
            CLK <= '0';
            wait for CLKPERIOD/2;
        else
            wait;
        end if;

        if END_SIM = FALSE then
            CLK <= '1';
				counter <= counter + 1; 
				if counter < 32000 then 
					can_read_vals <= '1'; 
				else 
					can_read_vals <= '0'; 
				end if; 
				
				if counter > 440000 then 
					counter <= 0; 
				end if; 
            wait for CLKPERIOD/2;
        else
            wait;
        end if;

    end process;
		-- counter to generate approximate can_read_vals signal 

	 
end TB_ARCHITECTURE;


configuration TESTBENCH_FOR_GCD of GCDTB is
    for TB_ARCHITECTURE 
		  for UUT : GCD
            use entity work.GCD;
        end for;
    end for;
end TESTBENCH_FOR_GCD;
