 
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_textio.all;
use ieee.numeric_std.all;
use std.textio.all;


entity tb_FpMul is
end tb_FpMul;
 
architecture behavior of tb_FpMul is 
	 
component FpMul
	port(
		Reset, Clock, 	WriteEnable, BufferSel: 	in std_logic;
		WriteAddress: 	in std_logic_vector (9 downto 0);
		WriteData: 		in std_logic_vector (63 downto 0);

		ReadAddress: 	in std_logic_vector (9 downto 0);
		ReadEnable: 	in std_logic;
		A:              in std_logic_vector (5 downto 0);         --矩阵X的行参数  
		B:              in std_logic_vector (5 downto 0);         --矩阵X的列参数,输入矩阵Y的行参数  
		C:              in std_logic_vector (5 downto 0);         --矩阵Y的列参数 
		
		ReadData: 		out std_logic_vector (63 downto 0);	
		DataReady: 		out std_logic
	);
end component;	 

signal tb_A : std_logic_vector(5 downto 0) := (others => '0');
signal tb_B : std_logic_vector(5 downto 0) := (others => '0');
signal tb_C : std_logic_vector(5 downto 0) := (others => '0');

signal tb_AB: std_logic_vector(11 downto 0) := (others => '0');	 
signal tb_flag: std_logic;
signal tb_Reset : std_logic := '0';
signal tb_Clock : std_logic := '0';
signal tb_BufferSel : std_logic := '0';
signal tb_WriteEnable : std_logic := '0';
signal tb_WriteAddress : std_logic_vector(9 downto 0) := (others => '0');
signal tb_WriteData : std_logic_vector(63 downto 0) := (others => '0');
signal tb_ReadEnable : std_logic := '0';
signal tb_ReadAddress : std_logic_vector(9 downto 0) := (others => '0');

signal tb_DataReady : std_logic;
signal tb_ReadData : std_logic_vector(63 downto 0);


-- Clock period definitions
constant period : time := 200 ns;    

begin

	tb_A <= "100000";   --支持修改矩阵大小 默认32x32
	tb_B <= "100000";	--支持修改矩阵大小 默认32x32
	tb_C <= "100000";   --支持修改矩阵大小 默认32x32
	
	tb_AB<=std_logic_vector(unsigned(tb_A)*unsigned(tb_B)-1);
		
	uut: FpMul 
		PORT MAP (
			Reset			=> tb_Reset,
			Clock			=> tb_Clock,
			WriteEnable		=> tb_WriteEnable,
			BufferSel		=> tb_BufferSel,

			WriteAddress	=> tb_WriteAddress,
			WriteData		=> tb_WriteData,		

			ReadEnable		=> tb_ReadEnable,
			ReadAddress		=> tb_ReadAddress,
			
		    A               => tb_A,
			B               => tb_B,
			C               => tb_C,
			
			ReadData		=> tb_ReadData,
			DataReady		=> tb_DataReady
      );
		
	process is	
	begin
		while now <= 400000 * period loop
			tb_Clock <= '0';
			wait for period/2;
			tb_Clock <= '1';
			wait for period/2;
		end loop;
		wait;
	end process;
	
	process is	
	begin
		tb_Reset <= '1';
		wait for 10*period;
		tb_Reset <= '0';
		wait;   
	end process;
		
	writing: process is						
		file FIA: TEXT open READ_MODE is "InputX.txt";    
		file FIB: TEXT open READ_MODE is "InputY.txt";    
		variable L: LINE;
		variable tb_PreCharacterSpace: string(5 downto 1);
		variable tb_MatrixData: std_logic_vector(63 downto 0);
	begin
		tb_WriteEnable <= '0';
		tb_WriteAddress <= "1111111111";  
		wait for 20*period;
		
		while not ENDFILE(FIA)  loop
			READLINE(FIA, L);		
			READ(L, tb_PreCharacterSpace);
			HREAD(L, tb_MatrixData);	
			wait until falling_edge(tb_Clock);
			tb_WriteAddress <= std_logic_vector(unsigned(tb_WriteAddress)+1);
			tb_BufferSel   <= '1';
			tb_WriteEnable <= '1';
			tb_flag		   <= '1';	
			tb_WriteData <=tb_MatrixData;
		end loop;
		

		while not ENDFILE(FIB)  loop
			READLINE(FIB, L);		
			READ(L, tb_PreCharacterSpace);
			HREAD(L, tb_MatrixData);	
			wait until falling_edge(tb_Clock);	
			if tb_WriteAddress >= tb_AB(9 downto 0) and tb_AB(9 downto 0)<"1111111111" and tb_flag='1'then
				tb_WriteAddress <= "0000000000";	
				tb_flag		    <= '0';
			else
				tb_WriteAddress <= std_logic_vector(unsigned(tb_WriteAddress)+1);
			end if;
			tb_BufferSel <= '0';
			tb_WriteEnable <= '1';
			tb_WriteData <=tb_MatrixData;
		end loop;
		wait for period;
		tb_WriteEnable <= '0';		
		wait; 
	end process;	
	
	reading: process is						
		file FO: TEXT open WRITE_MODE is "OutputR.txt";
		file FI: TEXT open READ_MODE is "OutputR_matlab.txt";
		variable L, Lm: LINE;
		variable tb_PreCharacterSpace: string(5 downto 1);
		variable v_ReadDatam: std_logic_vector(63 downto 0);
		variable v_OK: boolean;
	begin
		tb_ReadEnable <= '0';
		tb_ReadAddress <=(others =>'0');
		
		wait until rising_edge(tb_DataReady); 	
		wait until falling_edge(tb_DataReady); 

		Write(L, STRING'("Results"));
		WRITELINE(FO, L);
		Write(L, STRING'("Data from Matlab"), Left, 20);
		Write(L, STRING'("Data from Simulation"), Left, 20);
		WRITELINE(FO, L);
		tb_ReadEnable<= '1';
		while not ENDFILE(FI)  loop
			wait until rising_edge(tb_Clock);
			wait for 5 ns;
			
			READLINE(FI, Lm);
			READ(Lm, tb_PreCharacterSpace);
			HREAD(Lm, v_ReadDatam);		
			if v_ReadDatam = tb_ReadData then
				v_OK := True;
			else
				v_OK := False;
			end if;
			HWRITE(L, v_ReadDatam, Left, 40);
			HWRITE(L, tb_ReadData, Left, 40);
			WRITE(L, v_OK, Left, 10);			
			WRITELINE(FO, L);		

			tb_ReadAddress <= std_logic_vector(unsigned(tb_ReadAddress)+1);

		end loop;
		tb_ReadEnable <= '0';
		wait;  
	end process;
	
end;
