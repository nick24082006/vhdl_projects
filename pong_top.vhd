library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pong_top is
  port(
    clk_50mhz: in std_logic;
    reset_sw: in std_logic;
    sw : in std_logic_vector(3 downto 0);
    btn_user: in std_logic_vector (1 downto 0);
    hsync, vsync: out std_logic;
    vga_r, vga_g, vga_b: out std_logic_vector(7 downto 0);
    vga_clk: out std_logic;
    vga_sync: out std_logic;
    vga_blank: out std_logic;
    led_red: out std_logic
  );
end pong_top;

architecture arch of pong_top is
  component my_altpll
    port (
      refclk   : in  std_logic := '0';
      rst      : in  std_logic := '0';
      outclk_0 : out std_logic
    );
  end component;
  
  component clk_divider
    port ( 
      CLK_IN : in STD_LOGIC;
      CLK_OUT : out STD_LOGIC
    );
  end component;

  type state_type is (newgame, play, newball, over);
  signal video_on, pixel_tick: std_logic;
  signal pixel_x, pixel_y: std_logic_vector (9 downto 0);
  signal graph_on, gra_still, hit, miss: std_logic;
  signal text_on: std_logic_vector(3 downto 0);
  signal graph_rgb, text_rgb: std_logic_vector(2 downto 0);
  signal rgb_reg, rgb_next: std_logic_vector(2 downto 0);
  signal state_reg, state_next: state_type;
  signal dig0, dig1: std_logic_vector(3 downto 0);
  signal d_inc, d_clr: std_logic;
  signal timer_tick, timer_start, timer_up: std_logic;
  signal ball_reg, ball_next: unsigned(1 downto 0);
  signal ball: std_logic_vector(1 downto 0);
  signal reset, clk, clk_1Hz: std_logic;
  signal btn: std_logic_vector (1 downto 0);
   
begin
  clk_pll_instance: my_altpll port map(
    refclk   => clk_50mhz,
    rst      => '0',  
    outclk_0 => clk);
    
  inst_clk_divider: clk_divider port map (CLK_IN => clk, CLK_OUT => clk_1Hz);

  color_map_unit: entity work.color_map port map(sw, rgb_reg, vga_r, vga_g, vga_b);

  reset <= reset_sw; 
  btn <= not btn_user;
  led_red <= clk_1Hz;
  
  vga_sync <= '1';
  vga_blank <= video_on;
  vga_clk <= pixel_tick;
  
  vga_sync_unit: entity work.vga_sync
    port map(clk=>clk, reset=>reset,
             video_on=>video_on, p_tick=>pixel_tick,
             hsync=>hsync, vsync=>vsync,
             pixel_x=>pixel_x, pixel_y=>pixel_y);

  ball <= std_logic_vector(ball_reg);
  text_unit: entity work.pong_text
    port map(clk=>clk, reset=>reset,
             pixel_x=>pixel_x, pixel_y=>pixel_y,
             dig0=>dig0, dig1=>dig1, ball=>ball,
             text_on=>text_on, text_rgb=>text_rgb);
             
  graph_unit: entity work.pong_graph
    port map(clk=>clk, reset=>reset, btn=>btn,
            pixel_x=>pixel_x, pixel_y=>pixel_y,
            gra_still=>gra_still,hit=>hit, miss=>miss,
            graph_on=>graph_on,rgb=>graph_rgb);
            
  timer_tick <=  
    '1' when pixel_x="0000000000" and
             pixel_y="0000000000" else
    '0';
  timer_unit: entity work.timer
    port map(clk=>clk, reset=>reset,
             timer_tick=>timer_tick,
             timer_start=>timer_start,
             timer_up=>timer_up);
             
  counter_unit: entity work.m100_counter
    port map(clk=>clk, reset=>reset,
             d_inc=>d_inc, d_clr=>d_clr,
             dig0=>dig0, dig1=>dig1);
             
  process (clk,reset)
  begin
    if reset='1' then
       state_reg <= newgame;
       ball_reg <= (others=>'0');
       rgb_reg <= (others=>'0');
    elsif (clk'event and clk='1') then
       state_reg <= state_next;
       ball_reg <= ball_next;
       if (pixel_tick='1') then
         rgb_reg <= rgb_next;
       end if;
    end if;
  end process;

  process(btn,hit,miss,timer_up,state_reg,
         ball_reg,ball_next)
  begin
    gra_still <= '1';
    timer_start <='0';
    d_inc <= '0';
    d_clr <= '0';
    state_next <= state_reg;
    ball_next <= ball_reg;
    case state_reg is
       when newgame =>
          ball_next <= "11";
          d_clr <= '1';
          if (btn /= "00") then
             state_next <= play;
             ball_next <= ball_reg - 1;
          end if;
       when play =>
          gra_still <= '0';
          if hit='1' then
             d_inc <= '1';
          elsif miss='1' then
             if (ball_reg=0) then
                state_next <= over;
             else
                state_next <= newball;
             end if;
             timer_start <= '1';
             ball_next <= ball_reg - 1;
          end if;
       when newball =>
          if  timer_up='1' and (btn /= "00") then
            state_next <= play;
          end if;
       when over =>
          if timer_up='1' then
              state_next <= newgame;
          end if;
     end case;
  end process;

  process(state_reg,video_on,graph_on,graph_rgb,
         text_on,text_rgb)
  begin
    if video_on='0' then
       rgb_next <= "000";
    else
       if (text_on(3)='1') or
          (state_reg=newgame and text_on(1)='1') or
          (state_reg=over and text_on(0)='1') then
          rgb_next <= text_rgb;
       elsif graph_on='1'  then
         rgb_next <= graph_rgb;
       elsif text_on(2)='1'  then
         rgb_next <= text_rgb;
       else
         rgb_next <= "110";
       end if;
    end if;
  end process; 

end arch;
