library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use ieee.math_real.all;

entity sine_cordic is
    generic (
        INPUT_DATA_WIDTH    : integer := work.sine_cordic_constants.INPUT_DATA_WIDTH;
        OUTPUT_DATA_WIDTH   : integer := work.sine_cordic_constants.OUTPUT_DATA_WIDTH;
        ITERATION_COUNT     : integer := work.sine_cordic_constants.ITERATION_COUNT;
        INTERNAL_PRECISION  : integer := work.sine_cordic_constants.INTERNAL_PRECISION
    );
    port
    (
        reset               : in std_logic;
        clk                 : in std_logic;
        beta                : in std_logic_vector(INPUT_DATA_WIDTH-1 downto 0);
        start               : in std_logic;
        done                : out std_logic;
        result              : out std_logic_vector(OUTPUT_DATA_WIDTH-1 downto 0)
    );
end sine_cordic;


architecture syn of sine_cordic is
    constant REAL_CORRECTION : integer := 10; -- used to convert real decimal to representative integer
    
    component cordic_step is

        port
        (
	    poweroftwo  : in integer;
            alpha       : in std_logic_vector(INTERNAL_PRECISION-1 downto 0);
            beta_in     : in std_logic_vector(INTERNAL_PRECISION-1 downto 0);
            sine_in     : in std_logic_vector(INTERNAL_PRECISION-1 downto 0);
            cosine_in   : in std_logic_vector(INTERNAL_PRECISION-1 downto 0);
            beta_out    : out std_logic_vector(INTERNAL_PRECISION-1 downto 0);
            sine_out    : out std_logic_vector(INTERNAL_PRECISION-1 downto 0);
            cosine_out  : out std_logic_vector(INTERNAL_PRECISION-1 downto 0)
        );
    end component;
    
    function cumulative_product_k(n : integer) return std_logic_vector
    is
        variable product : real;
    begin
        product := 1.0;
        for i in 0 to n-1 loop
            product := product*(1.0/sqrt(1.0 + 1.0/(2.0**(2*i))));
        end loop;
        
        return std_logic_vector(to_unsigned(integer(product*2.0**REAL_CORRECTION), INTERNAL_PRECISION)); -- TODO shift
    end function;
    
    type DATA_ARRAY_TYPE is array(0 to ITERATION_COUNT) of std_logic_vector(INTERNAL_PRECISION-1 downto 0); --extra output at end; ITERATION_COUNT is used instead of I_C-1 as an ITERATION_COUNT of 0 should also be supported
    
    signal k_n : std_logic_vector(INTERNAL_PRECISION-1 downto 0);
    signal beta_array, beta_array_next, sine_array, sine_array_next, cosine_array, cosine_array_next : DATA_ARRAY_TYPE;
    signal control : std_logic_vector(ITERATION_COUNT downto 0);
    
begin
    k_n <= cumulative_product_k(ITERATION_COUNT);
    result <= sine_array(ITERATION_COUNT)(INTERNAL_PRECISION-1 downto INTERNAL_PRECISION - INPUT_DATA_WIDTH);
    done <= control(ITERATION_COUNT);
    
    step_gen : for j in 1 to ITERATION_COUNT generate
    begin
        cordic_step_inst : cordic_step
            port map(
                poweroftwo  => j-1,
		-- REAL_CORRECTION = INTERNAL_PRECISION - 1
                alpha       => std_logic_vector(to_unsigned(integer(1.0/arctan(2.0**(j))*2.0**REAL_CORRECTION), INTERNAL_PRECISION)), --TODO shift
                beta_in     => beta_array(j-1),
                sine_in     => sine_array(j-1),
                cosine_in   => cosine_array(j-1),
                beta_out    => beta_array_next(j),
                sine_out    => sine_array_next(j),
                cosine_out  => cosine_array_next(j)
            );
    end generate;

    sync : process(reset, clk)
    begin
        if(rising_edge(clk)) then
            if(reset = '1') then
                beta_array      <= (others => (others => '0'));
                sine_array      <= (others => (others => '0'));
                cosine_array    <= (others => (others => '0'));
                control         <= (others => '0');
            else
                control(ITERATION_COUNT downto 1)   <= control(ITERATION_COUNT-1 downto 0);
                control(0)                          <= start;
                
                beta_array(0)   <= (others => '0');
                beta_array(0)(INPUT_DATA_WIDTH-1 downto 0) <= beta; --pad beta to new precision
                for i in 1 to ITERATION_COUNT loop
                    beta_array(i)   <= beta_array_next(i);
                end loop;
                
                sine_array(0)   <= (others => '0');
                for i in 1 to ITERATION_COUNT loop
                    sine_array(i)   <= sine_array_next(i);
                end loop;
                
                cosine_array(0) <= std_logic_vector(to_unsigned(1*2**REAL_CORRECTION, INTERNAL_PRECISION)); --TODO shift
                for i in 1 to ITERATION_COUNT loop
                    cosine_array(i) <= cosine_array_next(i);
                end loop;
            end if;
        end if;
    end process;

end architecture;
