library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity lab5 is
  port(CLOCK_50            : in  std_logic;
       KEY                 : in  std_logic_vector(3 downto 0);
       SW                  : in  std_logic_vector(17 downto 0);
       VGA_R, VGA_G, VGA_B : out std_logic_vector(9 downto 0);  -- The outs go to VGA controller
       VGA_HS              : out std_logic;
       VGA_VS              : out std_logic;
       VGA_BLANK           : out std_logic;
       VGA_SYNC            : out std_logic;
       VGA_CLK             : out std_logic;
		 LEDR						: out std_logic_vector(17 downto 0);
		 LEDG						: out std_logic_vector(4 downto 0));
end lab5;

architecture RTL of lab5 is

	
	 --Component from the Verilog file: vga_adapter.v
  component vga_adapter
    generic(RESOLUTION : string);
    port (resetn                                       : in  std_logic;
          clock                                        : in  std_logic;
          colour                                       : in  std_logic_vector(2 downto 0);
          x                                            : in  std_logic_vector(7 downto 0);
          y                                            : in  std_logic_vector(6 downto 0);
          plot                                         : in  std_logic;
          VGA_R, VGA_G, VGA_B                          : out std_logic_vector(9 downto 0);
          VGA_HS, VGA_VS, VGA_BLANK, VGA_SYNC, VGA_CLK : out std_logic);
  end component;
  
  signal x_out      : std_logic_vector(7 downto 0) :="00000000";
  signal y_out      : std_logic_vector(6 downto 0) :="0000000";
  signal colour : std_logic_vector(2 downto 0) :="000"; 
  signal SLOW_CLOCK: std_logic;
  signal PEDAL_CLOCK: std_logic;
  signal PEDAL_COUNTER: signed(25 DOWNTO 0) :="00000000000000000000000000";
  signal COUNTER: UNSIGNED(25 DOWNTO 0) :="00000000000000000000000000";
  signal T_h_linex :signed(8 downto 0):="000000000";
  signal T_h_liney :signed(7 downto 0):="00000011";
  signal B_h_linex :signed(8 downto 0):="000000000";
  signal B_h_liney :signed(7 downto 0):="01110100";
  signal P1_x :signed(8 downto 0):="000001000";
  signal P1_y :signed(7 downto 0):="00000100";
  signal count_P1:signed(3 downto 0):="0000";
  signal P2_x :signed(8 downto 0):="000100000";
  signal P2_y :signed(7 downto 0):="00000100";
  signal count_P2:signed(3 downto 0):="0000";
  signal P3_x :signed(8 downto 0):="001111111";
  signal P3_y :signed(7 downto 0):="00000100";
  signal count_P3:signed(3 downto 0):="0000";
  signal P4_x :signed(8 downto 0):="010010111";
  signal P4_y :signed(7 downto 0):="00000100";
  signal count_P4:signed(3 downto 0):="0000";
  signal plot   : std_logic;
  signal done_clear_screen: std_logic;
  signal done_drawing_L1: std_logic;
  signal done_drawing_L2: std_logic;
  signal done_drawing_P1: std_logic;
  signal done_drawing_P2: std_logic;
  signal done_drawing_P3: std_logic;
  signal done_drawing_P4: std_logic;
  signal done_drawing_pb: std_logic;
  signal done_drawing_pt: std_logic;
  signal clear_screen: std_logic;
  signal state   : std_logic_vector(4 downto 0);
  signal reset_count: std_logic_vector(14 downto 0);
  signal x_ori		 : signed(8 downto 0):="001010000";
  signal y_ori		 : signed(7 downto 0):="00111100";
  signal speed		: signed (25 downto 0):="00000000011110101111000010";
  signal reset_speed : std_logic;
  
begin
	plot <= SLOW_CLOCK;
   vga_u0 : vga_adapter
 generic map(RESOLUTION => "160x120") 
    port map(resetn    => KEY(3),
             clock     => CLOCK_50,
             colour    => colour,
             x         => x_out,
             y         => y_out,
             plot      => plot,
             VGA_R     => VGA_R,
             VGA_G     => VGA_G,
             VGA_B     => VGA_B,
             VGA_HS    => VGA_HS,
             VGA_VS    => VGA_VS,
             VGA_BLANK => VGA_BLANK,
             VGA_SYNC  => VGA_SYNC,
             VGA_CLK   => VGA_CLK);

------------------------------------------------------------------------------------------------------------------------------------------------	
	process(CLOCK_50)--slow down the clock 
	begin 
		if(rising_edge(CLOCK_50)) then
			if(COUNTER="0000000000000000000000001") then
				COUNTER<="00000000000000000000000000";
				SLOW_CLOCK<='1';
			else
				COUNTER<= COUNTER + 1;
				SLOW_CLOCK<='0';
			end if;
		end if;
	end process;
	------------------------------------------------------------------------------------------------------------------------------------------------
	process(SLOW_CLOCK,KEY(3))
	variable speed		: signed (25 downto 0):="00000000011110101111000010";
	begin
		if(KEY(3)='0') then
			speed:="00000000011110101111000010";
		elsif(reset_speed='1') then
			speed:="00000000011110101111000010";
		elsif(rising_edge(SLOW_CLOCK)) then
			if(PEDAL_COUNTER>=speed) then
				PEDAL_COUNTER<="00000000000000000000000000";
				if(speed>"00000000001001110001000000") then
					speed:=speed-"00000000000000000000001010";
				end if;
				PEDAL_CLOCK<='1';
			else
				PEDAL_CLOCK<='0';
				PEDAL_COUNTER<=PEDAL_COUNTER + 1;
			end if;
		end if;
	end process;

------------------------------------------------------------------------------------------------------------------------------------------------	
	process(KEY(0),SLOW_CLOCK) --state machine
	variable present_state : std_logic_vector(4 downto 0) := "00000";
	begin	
		if(KEY(3)='0') then
			present_state:="00000";
		elsif(rising_edge(SLOW_CLOCK)) then
			case present_state is
				when "00000" => 
					if(done_clear_screen='1') then--clear entire screen
						present_state:="00001";
					end if;
				when "00001" => 
					if(done_drawing_L1='1') then--draw horizontal line on top
						present_state:="00010";
					end if;
				when "00010" => 
					if(done_drawing_L2='1') then--draw horizontal line at bottom
						present_state:="00011";
					end if;
				when "00011" => ------------------draw first paddle
					if(done_drawing_P1='1') then
						present_state:="00100";
					end if;
				when "00100" => ------------------draw second paddle
					if(done_drawing_P2='1') then
						present_state:="00101";
					end if;
				when "00101" => -----------------draw third paddle
					if(done_drawing_P3='1') then
						present_state:="00110";
					end if;
				when "00110" =>------------------draw fourth paddle
					if(done_drawing_P4='1') then
						present_state:="00111";
					end if;
				when "00111" =>------------------draw p1 bottom
					--if(done_drawing_pb='1') then
						present_state:="01000";
					--end if;
				when "01000" =>------------------draw p2 bottom
					--if(done_drawing_pt='1') then
						present_state:="01001";
					--end if;	
				when "01001" =>------------------draw p3 bottom
					--if(done_drawing_pt='1') then
						present_state:="01010";
					--end if;	
				when "01010" =>------------------draw p4 bottom
					--if(done_drawing_pt='1') then
						present_state:="01011";
				when "01011" =>------------------draw p1 top
					--if(done_drawing_pt='1') then
						present_state:="01100";
				when "01100" =>------------------draw p2 top
					--if(done_drawing_pt='1') then
						present_state:="01101";
				when "01101" =>------------------draw p3 top
					--if(done_drawing_pt='1') then
						present_state:="01110";
					--end if;	
				when "01110" =>------------------draw p4 top
					--if(done_drawing_pt='1') then
						present_state:="01111";
				when "01111" =>------------------check for collision
						present_state:="10000";
				when "10000" =>
						present_state:="00111";
				when others => 
					present_state:="00001";
			end case;
		end if;
		ledg<=present_state;
		state<=present_state;
	end process;
------------------------------------------------------------------------------------------------------------------------------------------------	
	process(SLOW_CLOCK,KEY(3)) ---clear screen screen
	
  Variable x0		 : signed(8 downto 0):="001010000";
  Variable y0		 : signed(7 downto 0):="00111100";
  Variable x1		 : signed(8 downto 0);
  Variable y1	    : signed(7 downto 0);
  Variable sx		 : signed(2 downto 0);
  Variable sy		 : signed(2 downto 0);
  Variable err	    : signed(8 downto 0);
  Variable e2	    : signed(9 downto 0);
  Variable dx			: signed(8 downto 0);
  Variable dy			: signed(7 downto 0);	
  Variable centre 	: std_logic;
  begin
  
  
		if(KEY(3)='0') then
			x0:="000000000";
			y0:="00000000";
			--LEDR<="000000000000000000";
			done_clear_screen<='0';
			done_drawing_P1<='0';
			done_drawing_P2<='0';
			done_drawing_P3<='0';
			done_drawing_P4<='0';
			done_drawing_L1<='0';
			done_drawing_L2<='0';
			count_P1<="0000";
			count_P2<="0000";
			count_p3<="0000";
			count_P4<="0000";
			P1_x<="000001000";
			P1_y<="00000100";
			P2_x<="000100000";
			P2_y<="00000100";
			P3_x<="001111111";
			P3_y<="00000100";
			P4_x<="010010111";
			P4_y<="00000100";
			dx :="000000001";
			dy :="11111111";
			x_ori<="001010000";
			y_ori<="00111100";
			
		elsif(rising_edge((SLOW_CLOCK)))then
		---------------------------------------------------------------------------------------------------------------------------------------------------------
			if(state="00000")then ------------------------------------clear entire screen---------------------------------------------------------------------------
				--if(done_reset='1') then
--					case colour is 
--						when "111" => colour<="000";
--						when others => colour<=std_logic_vector(unsigned(colour)+1);
--					end case;
				--else
					colour<="000";
				--end if;
				
					if(x0="10011111")then
						x0:="000000000";
						if(y0="1110111")then
							y0:="00000000";
							done_clear_screen<='1';
							x0:="000000000";
						else
							y0:=y0+1;
						end if;
					else
						x0:=x0+1;
						--if(done_reset='0') then
							--reset_count<=std_logic_vector(unsigned(reset_count)+1);
					--	end if;
					end if;
				x_out<=std_logic_vector(x0(7 downto 0));
				y_out<=std_logic_vector(y0(6 downto 0));
				-------------------------------------------------------DRAW TOP LINE------------------------------------------------------------------------------------------
			elsif(state="00001") then
				colour<="111";
				x0:=T_h_linex;
				y0:=T_h_liney;
				
				if(x0="10011111")then
					done_drawing_L1<='1';
					x0:="000000000";
				else
					x0:=x0+1;
				end if;
				T_h_linex<=x0;
				x_out<=std_logic_vector(x0(7 downto 0));
				y_out<=std_logic_vector(y0(6 downto 0));
				-----------------------------------------------------------DRAW BOTTOM LINE-------------------------------------------------------------------------------------
			elsif(state="00010") then
				colour<="111";
				x0:=B_h_linex;
				y0:=B_h_liney;
				
				if(x0="10011111")then
					done_drawing_L2<='1';
					x0:="000000000";
				else
					x0:=x0+1;
				end if;
				B_h_linex<=x0;
				x_out<=std_logic_vector(x0(7 downto 0));
				y_out<=std_logic_vector(y0(6 downto 0));
				-----------------------------------------------------------DRAW PEDAL 1-----------------------------------------------------------------------------------------
			elsif(state="00011") then
				colour<="101";
				x0:=P1_x;
				y0:=P1_y;
				if(count_P1="1111")then
					done_drawing_P1<='1';
				else
					y0:=y0+1;
					count_P1<=count_P1+1;
				end if;
				P1_y<=y0;
				x_out<=std_logic_vector(x0(7 downto 0));
				y_out<=std_logic_vector(y0(6 downto 0));	
				----------------------------------------------------------DRAW PEDAL 2------------------------------------------------------------------------------------------
			elsif(state="00100") then
				colour<="101";
				x0:=P2_x;
				y0:=P2_y;
				if(count_P2="1111")then
					done_drawing_P2<='1';
				else
					y0:=y0+1;
					count_P2<=count_P2+1;
				end if;
				P2_y<=y0;
				x_out<=std_logic_vector(x0(7 downto 0));
				y_out<=std_logic_vector(y0(6 downto 0));	
				----------------------------------------------------------DRAW PEDAL 3------------------------------------------------------------------------------------------
			elsif(state="00101") then
				colour<="110";
				x0:=P3_x;
				y0:=P3_y;
				if(count_P3="1111")then
					done_drawing_P3<='1';
				else
					y0:=y0+1;
					count_P3<=count_P3+1;
				end if;
				P3_y<=y0;
				x_out<=std_logic_vector(x0(7 downto 0));
				y_out<=std_logic_vector(y0(6 downto 0));
				----------------------------------------------------------DRAW PEDAL 4------------------------------------------------------------------------------------------
			elsif(state="00110") then
				
				colour<="110";
				x0:=P4_x;
				y0:=P4_y;
				if(count_P4="1111")then
					done_drawing_P4<='1';
					LEDR(17 downto 14)<=std_logic_vector(count_P4);
				else
					y0:=y0+1;
					count_p4<=count_P4+1;
					LEDR(7 downto 0)<=std_logic_vector(y0);
--					case count_P4 is
--						when "0000" => count_P4<="0001"; 
--						when "0001" => count_P4<="0010"; 
--						when "0010" => count_P4<="0011"; 
--						when "0011" => count_P4<="0100"; 
--						when "0100" => count_P4<="0101"; 
--						when "0101" => count_P4<="0110"; 
--						when "0110" => count_P4<="0111"; 
--						when "0111" => count_P4<="1000"; 
--						when "1000" => count_P4<="1001"; 
--						when "1001" => count_P4<="1010"; 
--						when "1010" => count_P4<="1011"; 
--						when "1011" => count_P4<="1100"; 
--						when "1100" => count_P4<="1101"; 
--						when "1101" => count_P4<="1110"; 
--						when "1110" => count_P4<="1111"; 
--						when others => count_P4<="1111"; 
--					end case;
				end if;
				P4_y<=y0;
				x_out<=std_logic_vector(x0(7 downto 0));
				y_out<=std_logic_vector(y0(6 downto 0));
			-------------------------------------------------------------------------P1 Bottom-----------------------------------------------------------------------------------------------
			elsif(state="00111") then
				if(SW(17)='1' AND p1_y>"00010011") then
					if(PEDAL_CLOCK='1') then
						colour<="000";
						x_out<="00001000";
						y_out<=std_logic_vector(p1_y(6 downto 0));
						--p1_y<=P1_y-1;
					end if;
				elsif(SW(17)='0'AND p1_y<"01110011")then
					if(PEDAL_CLOCK='1')then
						colour<="101";
						x_out<="00001000";
						y_out<=std_logic_vector(p1_y(6 downto 0));
						--p1_y<=P1_y+1;
					end if;
				end if;
				------------------------------------------------------------------------P2 Bottom-----------------------------------------------------------------------------------------	
		  elsif(state="01000")then 
				if(SW(16)='1' AND p2_y>"00010011") then
					if(PEDAL_CLOCK='1') then
						colour<="000";
						x_out<="00100000";
						y_out<=std_logic_vector(p2_y(6 downto 0));
						--p1_y<=P1_y-1;
					end if;
				elsif(SW(16)='0'AND p2_y<"01110011")then
					if(PEDAL_CLOCK='1')then
						colour<="101";
						x_out<="00100000";
						y_out<=std_logic_vector(p2_y(6 downto 0));
						--p1_y<=P1_y+1;
					end if;
				end if;
		-------------------------------------------------------------------P3 Bottom-------------------------------------------		
			 elsif(state="01001")then 
				if(SW(1)='1' AND p3_y>="00010100") then
					if(PEDAL_CLOCK='1') then
						colour<="000";
						x_out<="01111111";
						y_out<=std_logic_vector(p3_y(6 downto 0));
						--p1_y<=P1_y-1;
					end if;
				elsif(SW(1)='0'AND p3_y<="01110010")then
					if(PEDAL_CLOCK='1')then
						colour<="110";
						x_out<="01111111";
						y_out<=std_logic_vector(p3_y(6 downto 0));
						--p1_y<=P1_y+1;
					end if;
				end if;	
------------------------------------------------------------------------------P4 Bottom-----------------------------------------------------------------------------------	
			 elsif(state="01010")then 
				if(SW(0)='1' AND p4_y>"00010011") then
					if(PEDAL_CLOCK='1') then
						colour<="000";
						x_out<="10010111";
						y_out<=std_logic_vector(p4_y(6 downto 0));
						--p1_y<=P1_y-1;
					end if;
				elsif(SW(0)='0'AND p4_y<"01110011")then
					if(PEDAL_CLOCK='1')then
						colour<="110";
						x_out<="10010111";
						y_out<=std_logic_vector(p4_y(6 downto 0));
						--p1_y<=P1_y+1;
					end if;
				end if;			
				-----------------------------------------------------------------------P1 Top------------------------------------------------------------------------------------------	
			elsif(state="01011")then 
				if(SW(17)='1'AND p1_y>"00010011")then
					if(PEDAL_CLOCK='1')then
						colour<="101";
						x_out<="00001000";
						y_out<=std_logic_vector(p1_y(6 downto 0)-15);
						p1_y<=P1_y-1;
					end if;
				elsif(SW(17)='0'AND p1_y<"01110011")then
					if(PEDAL_CLOCK='1')then
						colour<="000";
						x_out<="00001000";
						y_out<=std_logic_vector(p1_y(6 downto 0)-15);
						p1_y<=P1_y+1;
					end if;
				end if;
				----------------------------------------------------------------------P2 Top-------------------------------------------------------------------------------------------	
			elsif(state="01100")then 
				if(SW(16)='1' AND p2_y>"00010011") then
					if(PEDAL_CLOCK='1') then
						colour<="101";
						x_out<="00100000";
						y_out<=std_logic_vector(p2_y(6 downto 0)-15);
						p2_y<=P2_y-1;
					end if;
				elsif(SW(16)='0'AND p2_y<"01110011")then
					if(PEDAL_CLOCK='1')then
						colour<="000";
						x_out<="00100000";
						y_out<=std_logic_vector(p2_y(6 downto 0)-15);
						p2_y<=P2_y+1;
					end if;
				end if;
	----------------------------------------------------------------------------------P3 Top-------------------------------------------------------------------------------				
		elsif(state="01101")then 
				if(SW(1)='1' AND p3_y>="00010100") then
					if(PEDAL_CLOCK='1') then
						colour<="110";
						x_out<="01111111";
						y_out<=std_logic_vector(p3_y(6 downto 0)-15);
						p3_y<=P3_y-1;
					end if;
				elsif(SW(1)='0'AND p3_y<="01110010")then
					if(PEDAL_CLOCK='1')then
						colour<="000";
						x_out<="01111111";
						y_out<=std_logic_vector(p3_y(6 downto 0)-15);
						p3_y<=P3_y+1;
					end if;
				end if;
	------------------------------------------------------------------------------------P4 Top----------------------------------------------------------------------------				
			elsif(state="01110")then 
			
				if(SW(0)='1' AND p4_y>"00010100") then
					if(PEDAL_CLOCK='1') then
						colour<="110";
						x_out<="10010111";
						y_out<=std_logic_vector(p4_y(6 downto 0)-15);
						p4_y<=P4_y-1;
					end if;
				elsif(SW(0)='0'AND p4_y<"01110011")then
					if(PEDAL_CLOCK='1')then
						colour<="000";
						x_out<="10010111";
						y_out<=std_logic_vector(p4_y(6 downto 0)-15);
						p4_y<=P4_y+1;
					end if;
				end if;
			reset_speed<='0';	
			elsif(state="01111")then
				if(PEDAL_CLOCK='1')then
					colour<="000";
					x_out<=std_logic_vector(x_ori(7 downto 0));
					y_out<=std_logic_vector(y_ori(6 downto 0));
					
					if(y_ori="00000100") then
						dy:="00000001";
					elsif(y_ori="01110011") then
						dy:="11111111";
					elsif(x_ori="001111110" AND y_ori<P3_y AND y_ori>(P3_y-15))then
						dx:="111111111";
					elsif(x_ori="010010110" AND y_ori<P4_y AND y_ori>(P4_y-15))then
						dx:="111111111";
					elsif(x_ori="000100001" AND y_ori<P2_y AND y_ori>(P2_y-15))then
						dx:="000000001";
					elsif(x_ori="000001001" AND y_ori<P1_y AND y_ori>(P1_y-15))then
						dx:="000000001";
					elsif(x_ori="010011001" OR x_ori="000000000") then	
						dx:="000000001";
						dy:="11111111";
						centre:='1';
						reset_speed<='1';
					end if;
					if(centre='0') then 
						x_ori<=x_ori+dx;
						y_ori<=y_ori+dy;
					else	
						x_ori<="001010000";
						y_ori<="00111100";
						centre:='0';
					end if;
				end if;
			elsif(state="10000")then
				if(PEDAL_CLOCK='1') then
					colour<="111";
					x_out<=std_logic_vector(x_ori(7 downto 0));
					y_out<=std_logic_vector(y_ori(6 downto 0));
				end if;
			end if;
			
		end if;
	end process;
end RTL;


