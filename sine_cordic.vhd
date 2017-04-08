library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use ieee.math_real.all;
use work.sine_cordic_constants.all;

entity sine_cordic is
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
end sine_cordic;


architecture syn of sine_cordic is

    component cordic_step is
        generic (
            DATA_WIDTH  : integer := 8
        );
        port (
            poweroftwo  : in integer range 0 to DATA_WIDTH;
            alpha       : in std_logic_vector(DATA_WIDTH-1 downto 0);
            beta_in     : in std_logic_vector(DATA_WIDTH-1 downto 0);
            sine_in     : in std_logic_vector(DATA_WIDTH-1 downto 0);
            cosine_in   : in std_logic_vector(DATA_WIDTH-1 downto 0);
            beta_out    : out std_logic_vector(DATA_WIDTH-1 downto 0);
            sine_out    : out std_logic_vector(DATA_WIDTH-1 downto 0);
            cosine_out  : out std_logic_vector(DATA_WIDTH-1 downto 0)
        );
    end component;
    
    component mult is
        generic (
            DATA_WIDTH  : integer := 8
        );
        port (
            clk     : in std_logic;
            reset   : in std_logic;
            dataa   : in std_logic_vector(DATA_WIDTH-1 downto 0);
            datab   : in std_logic_vector(DATA_WIDTH-1 downto 0);
            result  : out std_logic_vector(DATA_WIDTH*2-1 downto 0)
        );
    end component;

    component cordic_init is
        generic (
            DATA_WIDTH  : integer := 8
        );
        port (
            beta_in     : in std_logic_vector(DATA_WIDTH-1 downto 0);
            sine_in     : in std_logic_vector(DATA_WIDTH-1 downto 0);
            cosine_in   : in std_logic_vector(DATA_WIDTH-1 downto 0);
            beta_out    : out std_logic_vector(DATA_WIDTH-1 downto 0);
            sine_out    : out std_logic_vector(DATA_WIDTH-1 downto 0);
            cosine_out  : out std_logic_vector(DATA_WIDTH-1 downto 0)
        );
    end component;    
    
    constant INTERNAL_DATA_WIDTH : integer := MAX(INPUT_DATA_WIDTH, OUTPUT_DATA_WIDTH);
    
    type DATA_ARRAY_TYPE is array(0 to ITERATION_COUNT) of std_logic_vector(INTERNAL_DATA_WIDTH-1 downto 0); --extra output at end; ITERATION_COUNT is used instead of I_C-1 as an ITERATION_COUNT of 0 should also be supported
    
    signal k_n : std_logic_vector(INTERNAL_DATA_WIDTH-1 downto 0);
    signal beta_cast, beta_init, sine_init, cosine_init : std_logic_vector(INTERNAL_DATA_WIDTH-1 downto 0);
    signal beta_array, beta_array_next, sine_array, sine_array_next, cosine_array, cosine_array_next : DATA_ARRAY_TYPE;
    signal control : std_logic_vector(ITERATION_COUNT downto 0);
    signal control_init : std_logic;
    signal mult_result : std_logic_vector(INTERNAL_DATA_WIDTH*2-1 downto 0);
    
    constant RESULT_HIGH : integer := OUTPUT_DATA_WIDTH-1;
    constant MULT_RESULT_HIGH : integer := mult_result'high - Q_FORMAT_INTEGER_PLACES;
    -- shifted to account for n integer places results in 2*n integer places after multiplication
    constant MULT_RESULT_LOW : integer := MAX(MULT_RESULT_HIGH+1 - OUTPUT_DATA_WIDTH, 0);
    constant RESULT_LOW : integer := MAX(OUTPUT_DATA_WIDTH - (MULT_RESULT_HIGH+1 - MULT_RESULT_LOW), 0);
    
begin
    k_n <= cumulative_product_k(ITERATION_COUNT, INTERNAL_DATA_WIDTH - Q_FORMAT_INTEGER_PLACES, INTERNAL_DATA_WIDTH);
    beta_cast(INTERNAL_DATA_WIDTH-1 downto MAX(INTERNAL_DATA_WIDTH - INPUT_DATA_WIDTH, 0)) <= beta;
    beta_cast((INTERNAL_DATA_WIDTH - INPUT_DATA_WIDTH)-1 downto 0) <= (others => '0');
    result(RESULT_LOW-1 downto 0) <= (others => '0');
    result(RESULT_HIGH downto RESULT_LOW) <= mult_result(MULT_RESULT_HIGH downto MULT_RESULT_LOW);
    done <= control(ITERATION_COUNT);
    
    step_gen : for j in 1 to ITERATION_COUNT generate
    begin
        cordic_step_inst : cordic_step
            generic map (
                DATA_WIDTH  => INTERNAL_DATA_WIDTH
            )
            port map (
                poweroftwo  => j-1,
                alpha       => float_to_fixed(arctan(2.0**(-(j-1))), INTERNAL_DATA_WIDTH - Q_FORMAT_INTEGER_PLACES, INTERNAL_DATA_WIDTH),
                beta_in     => beta_array(j-1),
                sine_in     => sine_array(j-1),
                cosine_in   => cosine_array(j-1),
                beta_out    => beta_array_next(j),
                sine_out    => sine_array_next(j),
                cosine_out  => cosine_array_next(j)
            );
    end generate;
    
    mult_inst : mult
        generic map (
            DATA_WIDTH  => INTERNAL_DATA_WIDTH
        )
        port map (
            clk     => clk,
            reset   => reset,
            dataa   => sine_array(ITERATION_COUNT),
            datab   => k_n,
            result  => mult_result
        );

    init_inst : cordic_init
        generic map (
            DATA_WIDTH  => INTERNAL_DATA_WIDTH
        )
        port map (
            beta_in    => beta_cast,
            sine_in    => (others => '0'),
            cosine_in  => float_to_fixed(1.0, INTERNAL_DATA_WIDTH - Q_FORMAT_INTEGER_PLACES, INTERNAL_DATA_WIDTH),
            beta_out   => beta_init,
            sine_out   => sine_init,
            cosine_out => cosine_init
        );

    sync : process(reset, clk)
    begin
        if(rising_edge(clk)) then
            if(reset = '1') then
                beta_array      <= (others => (others => '0'));
                sine_array      <= (others => (others => '0'));
                cosine_array    <= (others => (others => '0'));
                control         <= (others => '0');
                control_init	<= '0';
            else
                control(ITERATION_COUNT downto 1)   <= control(ITERATION_COUNT-1 downto 0);
                control(0)                          <= control_init;
                control_init                        <= start;
               
                beta_array(0)   <= beta_init;
                for i in 1 to ITERATION_COUNT loop
                    beta_array(i)   <= beta_array_next(i);
                end loop;
               
                sine_array(0)   <= sine_init;
                for i in 1 to ITERATION_COUNT loop
                    sine_array(i)   <= sine_array_next(i);
                end loop;
                
                cosine_array(0) <= cosine_init;
                for i in 1 to ITERATION_COUNT loop
                    cosine_array(i) <= cosine_array_next(i);
                end loop;
            end if;
        end if;
    end process;

end architecture;
