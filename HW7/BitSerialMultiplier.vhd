----------------------------------------------------------------------------
--
--  1 Bit Full Adder
--
--  Implementation of a full adder. This entity takes the one bit 
--  inputs A and B with a carry in input and outputs the sum and carry 
--  out bits, using combinational logic. 
--
-- Inputs:
-- 		A: std_logic - 1 bit adder input
--			B: std_logic - 1 bit adder input
-- 		Cin: std_logic - 1 bit carry in input
--
-- Outputs:
-- 		Sum: std_logic - 1 bit sum of A, B, and Cin
--       Cout: std_logic - 1 bit carry out value 
--
--  Revision History:
--      11/21/18  Sophia Liu    Initial revision.
--      11/22/18  Sophia Liu    Updated comments.
--
----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fullAdder is
	port(
		A   		:  in      std_logic;  -- adder input 
		B 	 		:  in      std_logic;  -- adder input 
		Cin  		:  in      std_logic;  -- carry in value 
		Cout    	:  out     std_logic;  -- carry out value 
		Sum  		:  out     std_logic   -- sum of A, B with carry in
	  );
end fullAdder;

architecture fullAdder of fullAdder is
	begin
		-- combinational logic for calculating the sum and carry out bit
		Sum <= A xor B xor Cin;
		Cout <= (A and B) or (A and Cin) or (B and Cin);
end fullAdder;





----------------------------------------------------------------------------
--
--  n-bit Bit-Serial Multiplier
--
--  This is an implementation of an n-bit bit serial multiplier.  The
--  calculation will take 2n^2 clocks after the START signal is activated.
--  The multiplier is implemented with a moore state machine and a single 
--  one bit adder. 
--
--  The state machine starts with an active START signal 
--  and continually shifts the multiplicand, multiplies the last bit with 
--  the last multiplier bit, and adds it to the product register.
--  The multiplier register is then shifted to the next bit until the 
--  multiplication is completed. The DONE signal is pulled high for one 
--  clock upon completion. 
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
--     21 Nov 18  Sophia Liu        Added architecture and implementation
--     22 Nov 18  Sophia Liu        Updated comments
----------------------------------------------------------------------------

library  ieee;
use  ieee.std_logic_1164.all;
use ieee.numeric_std.all;

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

architecture bitMult of BitSerialMultiplier is

	-- component declarations 
	component fullAdder
		port(
			A   		:  in      std_logic;
			B 	 		:  in      std_logic;
			Cin  		:  in      std_logic;
			Cout    	:  out     std_logic;
			Sum  		:  out      std_logic
		);
	end component;
	
	-- internal signals for adder component 
	signal adderCin : std_logic := '0';
	signal adderCout : std_logic;
	signal adderSum : std_logic;

	
	
	-- Shift registers 
		-- Muliplicand (A) shift register 
	signal Areg : std_logic_vector((numbits - 1) downto 0);
		-- Multiplier (B) shift register 
	signal Breg : std_logic_vector((numbits - 1) downto 0);
		-- Product (Q) shift register 
	signal Qreg : std_logic_vector((2*numbits - 1) downto 0);
	
	-- Moore state machine for unsigned multiplier
	type multStates is (
		IDLE,		-- Idle state, waiting for start input 
		SHIFT,	-- Shift product register 
		ADD,     -- Add product to product register, shift multiplicand 
		NEXTBIT, -- Shift product register and muliplier register
		FINISH   -- Finished multiplying 
	);

	signal curState : multStates := IDLE; -- State variable

	-- Counters for current multiplicand, multiplier, and product bit  
	signal bitCountA : integer range 1 to numbits := 1;
	signal bitCountB : integer range 1 to numbits := 1;
	signal bitProduct: std_logic;

	begin
	-- adder instance for adding the next bit product to the product register
	adder: fullAdder
	port map(
		A 	 	=> Qreg(0),
		B		=> bitProduct,
		Cin 	=> adderCin,
		Cout  => adderCout,
		Sum  	=> adderSum
	  );
	  
	-- 1 bit multiplier for the last bits of multiplicand and multiplier  
	bitProduct <= Areg(0) and Breg(0);

	process(clk)
		begin
		if rising_edge(clk) then
			case curState is
				when IDLE =>
					DONE <= '0';
					-- On start signal, move multiplier and multiplicand into 
					-- registers, initialize other signals 
					if START = '1' then
						Areg <= A;
						Breg <= B;
						Qreg <= (others => '0'); -- Product is initially zero 
						adderCin <= '0';	-- Initially no carry in value
						bitCountA <= 1;	-- Initially start at first bit in registers
						bitCountB <= 1;
						curState <= SHIFT;	-- Begin multiplying 
					else
						curState <= IDLE;
					end if;
					
				when SHIFT =>
						-- rotate product right to add to next product term  
						Qreg <= std_logic_vector(unsigned(Qreg) ror 1);
						curState <= ADD;

				when ADD =>
					-- Add and replace product bit with correct sum 
					Qreg(0) <= adderSum;
					-- carry in the carry output from the sum to the next term
					adderCin <= adderCout;
					-- rotate multiplier right to move to next multiplicand bit
					Areg <= std_logic_vector(unsigned(Areg) ror 1);
					-- continue if haven't gone through all multiplicand bits
					if bitCountA < numbits then 
						bitCountA <= bitCountA + 1;
						curState <= SHIFT;
					else -- Finished with current multiplier bit
						Qreg(1) <= adderCout;	-- add in final carry out 
						adderCin <= '0';			-- reset carry in bit 
						bitCountA <= 1;			-- reset multiplicand bit count
						curState <= NEXTBIT;		
					end if;

				when NEXTBIT =>
					if bitCountB < numbits then -- haven't finished multiplying 
						-- shift product register back to add next group of products
						Qreg <= std_logic_vector(unsigned(Qreg) rol numbits - 1);
						-- move to next multiplier bit 
						Breg <= std_logic_vector(unsigned(Breg) ror 1);
						bitCountB <= bitCountB + 1; 	-- moving to next multiplier bit
						curState <= SHIFT;				-- coninue shifting and adding 
					else	-- finished multiplying 
						-- Shift product register back to initial position 
						-- assign product output 
						Q <= std_logic_vector(unsigned(Qreg) ror 2);
						curState <= FINISH;
					end if;

				when FINISH =>
					DONE <= '1';		-- send DONE signal to indicate product finished 
					curState <= IDLE; -- go back to idle to wait for START
					
			end case;
		end if;
	end process;
end bitMult;
