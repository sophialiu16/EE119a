----------------------------------------------------------------------------
--
--  Test Bench for UniversalSR8
--
--  This is a test bench for the UniversalSR8 entity.  The test bench
--  thoroughly tests the entity by exercising it and checking the outputs
--  through the use of an array of test values (TestVector).  The test bench
--  entity is called universalsr8_tb and it is currently defined to test the
--  Structural architecture of the UniversalSR8 entity.
--
--  Revision History:
--      4/4/00   Automated/Active-VHDL    Initial revision.
--      4/4/00   Glen George              Modified to add documentation and
--                                           more extensive testing.
--      4/6/04   Glen George              Updated comments.
--     11/21/05  Glen George              Updated comments and formatting.
--
----------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity BitSerialMultiplierTB is
end BitSerialMultiplierTB;

architecture TB_ARCHITECTURE of BitSerialMultiplierTB is

    -- Component declaration of the tested unit
    component BitSerialMultiplier
	     generic (
        numbits  :  integer := 8    -- number of bits in the inputs
		);
		 port (
			  A      :  in      std_logic_vector((numbits - 1) downto 0);     -- multiplicand
			  B      :  in      std_logic_vector((numbits - 1) downto 0);     -- multiplier
			  START  :  in      std_logic;                                    -- start calculation
			  CLK    :  in      std_logic;                                    -- clock
			  Q      :  buffer  std_logic_vector((2 * numbits - 1) downto 0); -- product
			  DONE   :  out     std_logic                                     -- calculation completed
		 );
    end component;


    -- Stimulus signals - signals mapped to the input and inout ports of tested entity
    signal  A     :  std_logic_vector(15 downto 0);
    signal  B  	:  std_logic_vector(15 downto 0);
    signal  START	:  std_logic;
    signal  CLK   :  std_logic;
	 
	 
    -- Observed signals - signals mapped to the output ports of tested entity
	 signal  Q4   	:  std_logic_vector(7 downto 0);
	 signal  Q2   	:  std_logic_vector(3 downto 0);
	 signal  Q16   	:  std_logic_vector(31 downto 0);
					 
	 signal  DONE2 	: 	std_logic; 
	 signal  DONE4 	: 	std_logic; 
	 signal  DONE 	: 	std_logic; 

    -- Signal used to stop clock signal generators
    signal  END_SIM  :  BOOLEAN := FALSE;

    -- Test Input/Output Vectors
    signal  TestVector  :  std_logic_vector(824 downto 0)
                        := "111111111111111000000000011010010100000000010010111010100100100100000110001101111100111000001100111000100001111000110010010100111111101010010110010100000100100101000101010111000011111100101101000101001000111110001011010010100011111010010001010111100110000000111111100111100011100100000010011110101011011011100110110001110101111110001101000101100011100101110001010100111111011111000100100001011000011110001110000110101010011001100011101101000101011010011000011010110001110010101111101110000001010101111100011111001001100101000110101000011100011111110001011011010010100101011000101001010010111000100110001110111011010101100101101111111000011010100001110001010111000000100111000100000110010100100101111011011010111111110011010111101111010000101011000000001000101011110110001000111001011111110010100000011101101000111011101101010";


begin

    -- Unit Under Test port map
	
	 mult4bit : BitSerialMultiplier
		  generic map ( 
		  numbits => 4
		  )
        port map  (
            A    	=> A(3 downto 0),
            B 		=> B(3 downto 0),
            START => START,
            CLK  	=> CLK,
            Q    	=> Q4,
				DONE 	=> DONE4
        );
		  
	mult2bit : BitSerialMultiplier
		  generic map ( 
		  numbits => 2
		  )
        port map  (
            A    	=> A(1 downto 0),
            B 		=> B(1 downto 0),
            START => START,
            CLK  	=> CLK,
            Q    	=> Q2,
				DONE 	=> DONE2
        );

	mult16bit : BitSerialMultiplier
		  generic map ( 
		  numbits => 16
		  )
        port map  (
            A    	=> A(15 downto 0),
            B 		=> B(15 downto 0),
            START => START,
            CLK  	=> CLK,
            Q    	=> Q16,
				DONE 	=> DONE
        );

    -- now generate the stimulus and test the design
    process

        -- some useful variables
        variable  i  :  integer;        -- general loop index
	 
			variable  Q4Match   	:  std_logic_vector(7 downto 0);
			variable  Q2Match   	:  std_logic_vector(3 downto 0);
			variable  Q16Match   	:  std_logic_vector(31 downto 0);
		  
		  begin 
		  
		  -- initially everything is X, have not started
        START  <= '0';
        A <= (others => 'X');
        B <= (others => 'X');

        -- run for a few clocks
        wait for 100 ns;	
		  
        for i in 0 to TestVector'high loop
			A <= TestVector(15 downto 0); 
			B <= TestVector(18 downto 3); 
			
			wait for 100 ns; 
			Q2Match := std_logic_vector(unsigned(A(1 downto 0)) * unsigned(B(1 downto 0))); 
			Q4Match := std_logic_vector(unsigned(A(3 downto 0)) * unsigned(B(3 downto 0))); 
			Q16Match := std_logic_vector(unsigned(A(15 downto 0)) * unsigned(B(15 downto 0))); 		
			
         START <='1';
			wait for 20 ns;
			START <= '0';
			if DONE /= '1' then 
				wait until DONE = '1';
			end if; 
			
			 assert (std_match(Q2, Q2Match))
                report  "Q2 failure"
                severity  ERROR;
			
			assert (std_match(Q4, Q4Match))
                report  "Q4 failure"
                severity  ERROR;
			
			assert (std_match(Q16, Q16Match))
                report  "Q16 failure"
                severity  ERROR;
			TestVector <= std_logic_vector(unsigned(TestVector) ror 2); 
			
			wait for 10 ns; 
			
			end loop; 
			
					 
			
		  
		         
---------------------------------------------
			A <= (others => '1'); 
			B <= (others => '1'); 
			
         START <='1';
			wait for 40 ns;
			START <= '0';
			if DONE4 /= '1' then 
				wait until DONE4 = '1';
			end if; 

			 assert (std_match(Q4, "11100001"))
                report  "all 1 failure"
                severity  ERROR;
			------------------------------
			A(3 downto 0) <= "0001"; 
			B(3 downto 0) <= "0001"; 
			
         START <='1';
			wait for 40 ns;
			START <= '0';
			if DONE4 /= '1' then 
				wait until DONE4 = '1';
			end if; 

			 assert (std_match(Q4, "00000001"))
                report  "1 failure"
                severity  ERROR;
			-----------------------------		 
			A(3 downto 0) <= "0101"; 
			B(3 downto 0) <= "0010"; 
			
         START <='1';
			wait for 40 ns;
			START <= '0';
			if DONE4 /= '1' then 
				wait until DONE4 = '1';
			end if; 

			 assert (std_match(Q4, "00001010"))
                report  "1010 failure"
                severity  ERROR;

			------------------------------		 
			A(3 downto 0) <= "1110"; 
			B(3 downto 0) <= "1010"; 
			
         START <='1';
			wait for 40 ns;
			START <= '0';
			if DONE4 /= '1' then 
				wait until DONE4 = '1';
			end if; 

			 assert (std_match(Q4, "10001100"))
                report  "1110 failure"
                severity  ERROR;
			------------------------------
		  	A(3 downto 0) <= "1110"; 
			B(3 downto 0) <= "0000"; 
			
         START <='1';
			wait for 40 ns;
			START <= '0';
			if DONE4 /= '1' then 
				wait until DONE4 = '1';
			end if; 

			 assert (std_match(Q4, "00000000"))
                report  "0 failure"
                severity  ERROR;
					 
        END_SIM <= TRUE;        -- end of stimulus events
        wait;                   -- wait for simulation to end

    end process; -- end of stimulus process
    

    CLOCK_CLK : process
    begin

        -- this process generates a 20 ns 50% duty cycle clock
        -- stop the clock when the end of the simulation is reached
        if END_SIM = FALSE then
            CLK <= '0';
            wait for 10 ns;
        else
            wait;
        end if;

        if END_SIM = FALSE then
            CLK <= '1';
            wait for 10 ns;
        else
            wait;
        end if;

    end process;


end TB_ARCHITECTURE;


configuration TESTBENCH_FOR_BitSerialMultiplier of BitSerialMultiplierTB is
    for TB_ARCHITECTURE
        for mult4bit : BitSerialMultiplier
            use entity work.BitSerialMultiplier;
        end for;
		  for mult2bit : BitSerialMultiplier
            use entity work.BitSerialMultiplier;
        end for;
		  for mult16bit : BitSerialMultiplier
            use entity work.BitSerialMultiplier;
        end for;
    end for;
end TESTBENCH_FOR_BitSerialMultiplier;
