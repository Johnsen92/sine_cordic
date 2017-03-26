library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cordic_step is
	port (
		reset       : in std_logic;
		clk         : in std_logic;
		index       : in std_logic_vector(INTERNAL_PRECISION-1 downto 0);
		alpha       : in std_logic_vector(INTERNAL_PRECISION-1 downto 0);
		k_n         : in std_logic_vector(INTERNAL_PRECISION-1 downto 0);
		beta_in     : in std_logic_vector(INTERNAL_PRECISION-1 downto 0);
		sine_in     : in std_logic_vector(INTERNAL_PRECISION-1 downto 0);
		cosine_in   : in std_logic_vector(INTERNAL_PRECISION-1 downto 0);
		beta_out    : out std_logic_vector(INTERNAL_PRECISION-1 downto 0);
		sine_out    : out std_logic_vector(INTERNAL_PRECISION-1 downto 0);
		cosine_out  : out std_logic_vector(INTERNAL_PRECISION-1 downto 0)
	);
end cordic_step;

architecture cordic_step_arc of cordic_step is

signal sine_int 	: std_logic_vector(INTERNAL_PRECISION-1 downto 0);
signal cosine_int	: std_logic_vector(INTERNAL_PRECISION-1 downto 0);
signal beta_int		: std_logic_vector(INTERNAL_PRECISION-1 downto 0);

begin  -- cordic_step_arc

	cordic_iteration : process(alpha, beta_in, sine_in, cosine_in)
	begin
		if beta_in < 0 then 
			cosine_int <= cosine_in + (sine_in sra index);
			sine_int <= sine_in - (cosine_in sra index);
			beta_int <= beta_in + alpha;
		else
			cosine_int <= cosine_in - (sine_in sra index);
			sine_int <= sine_in + (cosine_in sra index);
			beta_int <= beta_in - alpha;
		end if;
	end process cordic_iteration;
	
	cosine_out <= cosine_int;
	sine_out <= sine_int;
	beta_out <= beta_int;

end cordic_step_arc;
