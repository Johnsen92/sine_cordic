library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.sine_cordic_constants.all;

entity cordic_step is
    generic (
        DATA_WIDTH  : integer := 8
    );
	port (
		poweroftwo  : in integer;
		alpha       : in std_logic_vector(DATA_WIDTH-1 downto 0);
		beta_in     : in std_logic_vector(DATA_WIDTH-1 downto 0);
		sine_in     : in std_logic_vector(DATA_WIDTH-1 downto 0);
		cosine_in   : in std_logic_vector(DATA_WIDTH-1 downto 0);
		beta_out    : out std_logic_vector(DATA_WIDTH-1 downto 0);
		sine_out    : out std_logic_vector(DATA_WIDTH-1 downto 0);
		cosine_out  : out std_logic_vector(DATA_WIDTH-1 downto 0)
	);
end cordic_step;

architecture cordic_step_arc of cordic_step is

signal sine_int 	: std_logic_vector(DATA_WIDTH-1 downto 0);
signal cosine_int	: std_logic_vector(DATA_WIDTH-1 downto 0);
signal beta_int		: std_logic_vector(DATA_WIDTH-1 downto 0);

begin  -- cordic_step_arc

	cordic_iteration : process(alpha, beta_in, sine_in, cosine_in, poweroftwo)
	begin
		if signed(beta_in) < 0 then
			cosine_int <= std_logic_vector(signed(cosine_in) + shift_right(signed(sine_in), poweroftwo));
			sine_int <= std_logic_vector(signed(sine_in) - shift_right(signed(cosine_in), poweroftwo));
			beta_int <= std_logic_vector(signed(beta_in) + signed(alpha));
		else
			cosine_int <= std_logic_vector(signed(cosine_in) - shift_right(signed(sine_in), poweroftwo));
			sine_int <= std_logic_vector(signed(sine_in) + shift_right(signed(cosine_in), poweroftwo));
			beta_int <= std_logic_vector(signed(beta_in) - signed(alpha));
		end if;
	end process cordic_iteration;
	
	cosine_out <= cosine_int;
	sine_out <= sine_int;
	beta_out <= beta_int;

end cordic_step_arc;
