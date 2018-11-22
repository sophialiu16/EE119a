----------------------------------------------------------------------------
--
--  1 bit full adder 
--
--  Revision History:
--      11/01/18  Sophia Liu    Initial revision.
-- 
----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fullAdder is
	port(
		A   		:  in      std_logic;
		B 	 		:  in      std_logic;   					
		Cin  		:  in      std_logic;						
		Cout    	:  out     std_logic; 
		Sum  		:  out      std_logic
	  );
end fullAdder;

architecture fullAdder of fullAdder is 
	begin 
		Sum <= A xor B xor Cin; 
		Cout <= (A and B) or (A and Cin) or (B and Cin); 
end fullAdder; 


-- bring in the necessary packages
library  ieee;
use  ieee.std_logic_1164.all;
use ieee.numeric_std.all;


----------------------------------------------------------------------------
--
--  n-bit Bit-Serial Multiplier
--
--  This is an implementation of an n-bit bit serial multiplier.  The
--  calculation will take 2n^2 clocks after the START signal is activated.
--  The multiplier is implemented with a single adder.  This file contains
--  only the entity declaration for the multiplier.
--
--  Parameters:
--      numbits - number of bits in the multiplicand and multiplier (n)
--
--  Inputs:
--      A       - n-bit unsigned multiplicand
--      B       - n-bit unsigned multiplier
--      START   - active high signal indicating a multiplication is to start
--      CLK     - clock input (active high)
--
--  Outputs:
--      Q       - (2n-1)-bit product (multiplication result)
--      DONE    - active high signal indicating the multiplication is complete
--                and the Q output is valid
--
--
--  Revision History:
--      7 Apr 00  Glen George       Initial revision.
--     12 Apr 00  Glen George       Changed Q to be type buffer instead of
--                                  type out.
--     21 Nov 05  Glen George       Changed nobits to numbits for clarity
--                                  and updated comments.
--
----------------------------------------------------------------------------

entity  BitSerialMultiplier  is

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

end  BitSerialMultiplier;

-- TODO bring in entity instead 

architecture bitMult of BitSerialMultiplier is 

-- components 

	component shiftReg 
		generic (
			n  :  integer
		);
		port(
			DI   :  in      std_logic_vector(n-1 downto 0 );
			LSI  :  in      std_logic;   					
			RSI  :  in      std_logic;						
			S    :  in      std_logic_vector(1 downto 0); 
			CLR  :  in      std_logic;	
			CLK  :  in      std_logic;	
			DO   :  buffer  std_logic_vector(n-1 downto 0)
       );
	end component; 
	
	component fullAdder
		port(
			A   		:  in      std_logic;
			B 	 		:  in      std_logic;   					
			Cin  		:  in      std_logic;						
			Cout    	:  out     std_logic; 
			Sum  		:  out      std_logic
		);
	end component; 
	
	signal Areg : std_logic_vector((numbits - 1) downto 0);
	
	signal Breg : std_logic_vector((numbits - 1) downto 0);
	
	signal Qreg : std_logic_vector((2*numbits - 1) downto 0);
	
	signal adderA : std_logic; 
	signal adderB : std_logic;
	signal adderCin : std_logic := '0'; 
	signal adderCout : std_logic; 
	signal adderSum : std_logic;
	
	type multStates is (
		IDLE,
		SHIFT,
		ADD,
		NEXTBIT, 
		FINISH
	);
	
	signal curState : multStates := IDLE; 
	
	signal bitCountA : integer range 1 to numbits := 1; 
	signal bitCountB : integer range 1 to numbits := 1; 
	signal bitProduct: std_logic; 
	
	begin
	
	adder: fullAdder
	port map(
		A 	 	=> Qreg(0),
		B		=> bitProduct,					
		Cin 	=> adderCin,
		Cout  => adderCout,
		Sum  	=> adderSum
	  );
	 
	bitProduct <= Areg(0) and Breg(0); 
	
	process(clk) 
		begin 
		if rising_edge(clk) then 
			case curState is 
				when IDLE => 
					DONE <= '0'; 
					if START = '1' then 
						Areg <= A; 
						Breg <= B; 
						Qreg <= (others => '0');
						adderCin <= '0';
						bitCountA <= 1; 
						bitCountB <= 1;
						curState <= SHIFT;
					else 
						curState <= IDLE; 
					end if; 
				when SHIFT =>
						-- roate Q right 
						Qreg <= std_logic_vector(unsigned(Qreg) ror 1);
						curState <= ADD; 
					
				when ADD =>
						Qreg(0) <= adderSum; 
						adderCin <= adderCout;
						-- rotate A right 
						Areg <= std_logic_vector(unsigned(Areg) ror 1); 
						
					if bitCountA < numbits then 
						bitCountA <= bitCountA + 1; 
						curState <= SHIFT; 
					else 
						Qreg(1) <= adderCout;
						adderCin <= '0';
						bitCountA <= 1;
						curState <= NEXTBIT; 
					end if; 
					
				when NEXTBIT => 
						-- shift product register back n-1 times for next bit 
					if bitCountB < numbits then 
						Qreg <= std_logic_vector(unsigned(Qreg) rol numbits - 1);
						Breg <= std_logic_vector(unsigned(Breg) ror 1); 
						bitCountB <= bitCountB + 1; 
						curState <= SHIFT; 
					else 
						Qreg <= std_logic_vector(unsigned(Qreg) ror 2);
						curState <= FINISH;
					end if;
				
				when FINISH => 
					Q <= Qreg; 
					DONE <= '1'; 
					curState <= IDLE; 
			end case; 
		end if;
		 
	end process;
	
--	process(curState) 
--	begin 
--		case curState is 
--			when IDLE => 
--			
--			when SHIFT => 
--			
--			when ADD => 
--			
--			when NEXTBIT =>
--			
--			when FINISH => 
--			
--		end case;	
--	
--	end process;
	
				
end bitMult;




