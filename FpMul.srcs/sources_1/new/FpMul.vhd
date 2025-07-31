library ieee; 
use ieee.std_logic_1164.all;  
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all; 

entity FpMul is
	port(
		Reset, Clock, 	WriteEnable, BufferSel:in std_logic;
		WriteAddress: 	in std_logic_vector (9 downto 0);
		WriteData: 		in std_logic_vector (63 downto 0);

		ReadAddress: 	in std_logic_vector (9 downto 0);
		ReadEnable: 	in std_logic;
		A:              in std_logic_vector (5 downto 0);--矩阵X的行参数  
		B:              in std_logic_vector (5 downto 0);--矩阵X的列参数,输入矩阵Y的行参数  
		C:              in std_logic_vector (5 downto 0);--矩阵Y的列参数 
		
		ReadData: 		out std_logic_vector (63 downto 0);	
		DataReady: 		out std_logic
	);
end FpMul;

architecture IntMatMulCore_arch of FpMul is

COMPONENT add_double
  PORT (
    aclk : IN STD_LOGIC;
    s_axis_a_tvalid : IN STD_LOGIC;
    s_axis_a_tdata : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
    s_axis_b_tvalid : IN STD_LOGIC;
    s_axis_b_tdata : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
    m_axis_result_tvalid : OUT STD_LOGIC;
    m_axis_result_tdata : OUT STD_LOGIC_VECTOR(63 DOWNTO 0)
  );
END COMPONENT;

COMPONENT mul_double
  PORT (
    aclk : IN STD_LOGIC;
    s_axis_a_tvalid : IN STD_LOGIC;
    s_axis_a_tdata : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
    s_axis_b_tvalid : IN STD_LOGIC;
    s_axis_b_tdata : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
    m_axis_result_tvalid : OUT STD_LOGIC;
    m_axis_result_tdata : OUT STD_LOGIC_VECTOR(63 DOWNTO 0)
  );
END COMPONENT;


COMPONENT dpram1024x64
  PORT (
    clka : IN STD_LOGIC;
    wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    addra : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    dina : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
    clkb : IN STD_LOGIC;
    enb : IN STD_LOGIC;
    addrb : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    doutb : OUT STD_LOGIC_VECTOR(63 DOWNTO 0)
  );
END COMPONENT;

-- state definitions
type	stateType is (stIdle, stWriteBufferA, stWriteBufferB, stReadBufferAB,  stWriteBufferC, stComplete);   			
signal presState: stateType;
signal nextState: stateType;
signal iWriteEnableA, iWriteEnableB, iWriteEnableC: std_logic_vector(0 downto 0);
signal iReadEnableAB,iCountReset, iRowCountAReset, iColCountAReset, iRowCountBReset, iColCountBReset,iCountEnable, iRowCountAEnable, iColCountAEnable, iRowCountBEnable, iColCountBEnable: std_logic;

signal iNumberX: unsigned(11 downto 0);
signal iNumberY: unsigned(11 downto 0);
signal iColCountX: unsigned(4 downto 0); 
signal iRowCountX, iColCountY: unsigned(5 downto 0); 

signal imul_tvalid: std_logic;
signal omul_tvalid,oadd_tvalid: std_logic;

signal iWriteAddressC, iReadAddressX, iReadAddressY: std_logic_vector(9 downto 0); 
signal iReadDataX, iReadDataY: std_logic_vector (63 downto 0);
signal omul_result_tdata,oadd_result_tdata,iadd_b_tdata: std_logic_vector (63 downto 0);

signal iCount: unsigned(9 downto 0); 
signal iCountc: unsigned(9 downto 0); 
signal iColCountAr: unsigned(5 downto 0); 

signal InputBufferAddrX,InputBufferAddrY: unsigned(11 downto 0); 
begin	

	iWriteEnableA(0) <= WriteEnable and BufferSel;
	iWriteEnableB(0) <= WriteEnable and (not BufferSel);
	
	iNumberX   <= (unsigned (A)) * (unsigned (B))-1;
	iNumberY   <= (unsigned (B)) * (unsigned (C))-1;
	iColCountAr<= (unsigned (B)-1);

	
	InputBufferX : dpram1024x64
		PORT MAP (
			clka  	=> Clock,
			wea   	=> iWriteEnableA,
			addra 	=> WriteAddress,
			dina  	=> WriteData,
			clkb 	=> Clock,
			enb		=> iReadEnableAB,
			addrb 	=> iReadAddressX,
			doutb 	=> iReadDataX
		);
	
	InputBufferY : dpram1024x64
		PORT MAP (
			clka  	=> Clock,
			wea   	=> iWriteEnableB,
			addra 	=> WriteAddress,
			dina  	=> WriteData,
			clkb 	=> Clock,
			enb		=> iReadEnableAB,
			addrb 	=> iReadAddressY,
			doutb 	=> iReadDataY
		);	

	OutputBufferR : dpram1024x64
		PORT MAP (
			clka 	=> Clock,			
			wea 	=> iWriteEnableC,
			addra 	=> iWriteAddressC,
			dina 	=> oadd_result_tdata,
			clkb 	=> Clock,
			enb 	=> ReadEnable,
			addrb 	=> ReadAddress,
			doutb 	=> ReadData
		);
		
	add_double_u: add_double 	
		PORT MAP (
			aclk => Clock,
			s_axis_a_tvalid => omul_tvalid,
			s_axis_a_tdata  => omul_result_tdata ,
			s_axis_b_tvalid => omul_tvalid,
			s_axis_b_tdata  => iadd_b_tdata,
			m_axis_result_tvalid => oadd_tvalid,
			m_axis_result_tdata  => oadd_result_tdata
		);
		
	mul_double_u: mul_double 
		PORT MAP (
			aclk => Clock,
			s_axis_a_tvalid => imul_tvalid,
			s_axis_a_tdata  => iReadDataX,
			s_axis_b_tvalid => imul_tvalid,
			s_axis_b_tdata  => iReadDataY,
			m_axis_result_tvalid => omul_tvalid,
			m_axis_result_tdata  => omul_result_tdata
		);

			
 	process (Clock)
	begin
		if rising_edge (Clock) then    
			if iRowCountAReset = '1' then       
				iRowCountX <= (others=>'0');
			elsif iRowCountAEnable = '1' then
				iRowCountX <= iRowCountX + 1;
			end if;

			if iColCountAReset = '1' then       
				iColCountX <= (others=>'0');
			elsif iColCountAEnable = '1' then
				iColCountX <= iColCountX + 1;
			end if;		

			if iColCountBReset = '1' then       
				iColCountY <= (others=>'0');
			elsif iColCountBEnable = '1' then
				iColCountY <= iColCountY + 1;
			end if;		
		end if;			
	end process;
	InputBufferAddrX    <=iRowCountX*unsigned (B)+unsigned('0'&std_logic_vector(iColCountX));
	InputBufferAddrY    <=unsigned('0'&std_logic_vector(iColCountX))*unsigned (C)+iColCountY;						
	iReadAddressX <= std_logic_vector(InputBufferAddrX(9 downto 0));	
	iReadAddressY <= std_logic_vector(InputBufferAddrY(9 downto 0));
	
 	process (Clock)
	begin
		if rising_edge (Clock) then    
			if iCountReset = '1' then       
				iCount <= (others=>'0');
			elsif iCountEnable = '1' then
				iCount <= iCount + 1;
			end if;
		end if;
	end process;
					
 	process (Clock)
	begin
		if rising_edge (Clock) then    
			if oadd_tvalid = '0' then       
				iCountc <= (others=>'1');
			elsif oadd_tvalid = '1'  then		
				if iCountc=unsigned(x"0"&B)-1 then
					iCountc <= (others=>'0');
				else
					iCountc <= iCountc + 1;
				end if;	
			end if;	
			
			if Reset = '1' then
				iWriteAddressC  <= (others=>'0');
			elsif iWriteEnableC(0)='1' then
				iWriteAddressC  <= std_logic_vector(unsigned(iWriteAddressC)+1);			
			end if;					
		end if;			
	end process;	
	iadd_b_tdata	 <= (others=>'0') when iCountc="1111111111" or iCountc=unsigned(x"0"&B)-1 else oadd_result_tdata;
	iWriteEnableC(0) <= '1' when iCountc=unsigned(x"0"&B)-1  else '0';
	
 	process (Clock)
	begin
		if rising_edge (Clock) then    
			if Reset = '1' then
				presState <= stIdle;
			else
				presState <= nextState;
			end if;	
		end if;	
	end process;
	
	process (presState, WriteEnable, BufferSel, iCount, iRowCountX, iColCountX, iColCountY)
	begin
		-- signal defaults
		iCountReset  <= '0';
		iCountEnable <= '1'; 		
		iRowCountAReset <= '0';
		iRowCountAEnable <= '0';

		iColCountAReset <= '0';
		iColCountAEnable <= '0';
		iColCountBReset <= '0';	
		iColCountBEnable <= '0';
		
		iReadEnableAB <= '0'; 		
		DataReady <= '0';
		imul_tvalid <= '0';
		case presState is
			when stIdle =>
			
				if (WriteEnable = '1' and BufferSel = '1') then
					nextState <= stWriteBufferA;
				else
					iCountReset <= '1';
					nextState <= stIdle;
				end if;
			when stWriteBufferA =>
			
				if iCount = iNumberX(9 downto 0) then
					iCountReset <= '1';				
					nextState <= stWriteBufferB;
 				else
					nextState <= stWriteBufferA;
				end if;
			when stWriteBufferB =>
			
				if iCount = iNumberY(9 downto 0) then
					iCountReset <= '1';
					iRowCountAReset <= '1';
					iColCountAReset <= '1';
					iColCountBReset <= '1';
					nextState <= stReadBufferAB;
 				else
					nextState <= stWriteBufferB;
				end if;
			when stReadBufferAB =>
			

				if iColCountX = iColCountAr(4 downto 0) then				
					if iColCountY = unsigned(C)-1 then
						iRowCountAEnable <= '1';
						iColCountBReset <= '1';
						iColCountAReset <= '1';
						nextState <= stReadBufferAB;
						if iRowCountX = unsigned(A)-1 then
						iRowCountAReset <= '1';
						iColCountBReset <= '1';
						iColCountAReset <= '1';
						nextState <= stWriteBufferC;
						end if;
					else
						iColCountAReset  <= '1';
						iColCountBEnable <= '1';
						nextState <= stReadBufferAB;
					end if;	
				else
					iColCountAEnable <= '1';
					nextState <= stReadBufferAB;
				end if;

				imul_tvalid 	 <= '1';
				iReadEnableAB    <= '1';				

			when stWriteBufferC =>		
			
				if iCountc=unsigned(x"0"&B)-1 then
					iCountReset <= '1';
					nextState <= stComplete;
				else
					imul_tvalid   <= '1';
					nextState <= stWriteBufferC;
				end if;		
				
			when stComplete =>
			
				DataReady <= '1';
				nextState <= stIdle;			
		
		end case;
		
	end process;

end IntMatMulCore_arch;
