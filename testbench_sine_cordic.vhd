library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.sine_cordic_constants.all;

entity testbench is
end testbench;

architecture beh of testbench is

    component sine_cordic is
        generic (
            INPUT_DATA_WIDTH    : integer := 8;
            OUTPUT_DATA_WIDTH   : integer := 8;
            ITERATION_COUNT     : integer := 12
        );
        port (
            reset               : in std_logic;
            clk                 : in std_logic;
            beta                : in std_logic_vector(INPUT_DATA_WIDTH-1 downto 0);
            start               : in std_logic;
            done                : out std_logic;
            result              : out std_logic_vector(OUTPUT_DATA_WIDTH-1 downto 0)
        );
    end component;

    constant CLK_PERIOD : time := 4 ns;
    constant INPUT_DATA_WIDTH : integer := 32;
    constant OUTPUT_DATA_WIDTH : integer := 32;
    constant ITERATION_COUNT : integer := 24;
    
    type testcase_array is array(8 downto 0) of real;
    constant testcases : testcase_array := (
        0.0,
        MATH_PI*2.0**(-1),
        -MATH_PI*2.0**(-1),
        MATH_PI*3.0**(-1),
        -MATH_PI*3.0**(-1),
        MATH_PI*4.0**(-1),
        -MATH_PI*4.0**(-1),
        MATH_PI,
        -MATH_PI
        --MATH_PI*6.0**(-1),
        ---MATH_PI*6.0**(-1)
    );

    signal clk, reset : std_logic;
    signal beta : std_logic_vector(INPUT_DATA_WIDTH-1 downto 0);
    signal start, done : std_logic;
    signal result : std_logic_vector(OUTPUT_DATA_WIDTH-1 downto 0);
    
    signal result_converted : real;
    signal testcase : real;
    signal comparison : real;

begin
    result_converted <= fixed_to_float(result, OUTPUT_DATA_WIDTH - Q_FORMAT_INTEGER_PLACES);

    top_inst : sine_cordic
        generic map (
            INPUT_DATA_WIDTH    => INPUT_DATA_WIDTH,
            OUTPUT_DATA_WIDTH   => OUTPUT_DATA_WIDTH,
            ITERATION_COUNT     => ITERATION_COUNT
        )
        port map (
            reset   => reset,
            clk     => clk,
            beta    => beta,
            start   => start,
            done    => done,
            result  => result
        );
 
    -- Generates the clock signal
    clkgen : process
    begin
        clk <= '0';
        wait for CLK_PERIOD/2;
        clk <= '1';
        wait for CLK_PERIOD/2;
    end process clkgen;

    -- Generates the reset signal
    resetgen : process
    begin  -- process reset
        reset <= '1';
        wait for 2*CLK_PERIOD;
        reset <= '0';
        wait;
    end process;

    -- Generates the input
    input : process
    begin  -- process input
        start <= '0';
        beta <= (others => '0');
        wait until falling_edge(reset);
        wait until rising_edge(clk);

        for i in testcases'high downto testcases'low loop
            wait until rising_edge(clk);
            testcase <= testcases(i);
            beta <= float_to_fixed(testcases(i), INPUT_DATA_WIDTH - Q_FORMAT_INTEGER_PLACES, INPUT_DATA_WIDTH);
            start <= '1';
            wait until rising_edge(clk);
            start <= '0';
            
            wait until rising_edge(done);
            comparison <= sin(testcases(i));
        end loop;
        
        wait;
    end process;

end beh;
