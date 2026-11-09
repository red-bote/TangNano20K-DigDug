---------------------------------------------------------------------------------
-- Basys 3 top level for Dig Dug
-- Source: TN20K-DigDug.vhd by pinballwiz.org
--   (https://github.com/pinballwizz/TangNano20K-DigDug). See that file for its
--   history.
-- Core: FPGA DigDug by MiSTer-X
---------------------------------------------------------------------------------
--
-- 11/06/2026: initial Basys 3 release by Red~Bote
--
---------------------------------------------------------------------------------
-- License:
--  - Basys 3 changes: MIT (see LICENSE)
--  - Code from TN20K-DigDug.vhd: no license stated
--  - Core (src/*.v): (c) 2017 MiSTer-X, terms as stated in the file headers
---------------------------------------------------------------------------------
--
-- Main features:
--  Connections:
--   VGA monitor, 31 kHz (scandoubler). 15 kHz RGB with sw13 up (not tested)
--   USB keyboard on the USB-HID host connector (MAME default keys)
--   Atari-type joystick on Pmod JA, pins 1/2/3/4/7 = right/left/down/up/fire
--   PmodAMP2 with speaker on Pmod JXADC, pins 1/2/4
--  Controls       keyboard       stick          button
--   move          arrows         stick
--   pump          Left Ctrl      fire
--   coin          5                             btnU, btnD
--   start1/2      1, 2                          btnL, btnR
--   reset                                       btnC
--  Switches:
--   sw15      audio off
--   sw14      scanlines
--   sw13      15 kHz RGB
--   sw12      test mode
--   sw0-sw9   DIP switches, down = default:
--    sw0-sw2   bonus life
--    sw3-sw4   lives
--    sw5-sw6   difficulty
--    sw7       allow continue
--    sw8       demo sounds
--    sw9       freeze
--   Coin A and coin B fixed at 1 coin 1 credit, cabinet fixed upright
--  Clock: 1 MMCM, 48, 24 and 12 MHz from 100 MHz (as the Tang Nano 20K clocks)
--
-- Other details: see basys3/README.md
---------------------------------------------------------------------------------
-- Keyboard inputs :
--   5 : Add coin
--   2 : Start 2 players
--   1 : Start 1 player
--   LEFT Ctrl   : Fire
--   RIGHT arrow : Move Right
--   LEFT arrow  : Move Left
--   UP arrow    : Move Up
--   DOWN arrow  : Move Down
---------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.ALL;
use ieee.numeric_std.all;
---------------------------------------------------------------------------------
entity digdug_basys3 is
port(
    clk         : in  std_logic;
    btnC        : in  std_logic;
    btnU        : in  std_logic;
    btnD        : in  std_logic;
    btnL        : in  std_logic;
    btnR        : in  std_logic;
    sw          : in  std_logic_vector(15 downto 0);
    vga_r       : out std_logic_vector(3 downto 0);
    vga_g       : out std_logic_vector(3 downto 0);
    vga_b       : out std_logic_vector(3 downto 0);
    hsync       : out std_logic;
    vsync       : out std_logic;
    ps2_clk     : in  std_logic;
    ps2_dat     : inout std_logic;
    JA          : in  std_logic_vector(4 downto 0);
    JXADC       : out std_logic_vector(3 downto 0);
    led         : out std_logic_vector(15 downto 0)
);
end digdug_basys3;
------------------------------------------------------------------------------
architecture struct of digdug_basys3 is

    signal clock_48        : std_logic;
    signal clock_24        : std_logic;
    signal clock_12        : std_logic;
    signal pll_lock        : std_logic;
    signal mmcm_reset      : std_logic := '0';
    --
    signal PCLK            : std_logic;
    signal HPOS            : std_logic_vector(8 downto 0);
    signal VPOS            : std_logic_vector(8 downto 0);
    signal oPIX            : std_logic_vector(7 downto 0);
    --
    signal iRGB            : std_logic_vector(11 downto 0);
    signal oRGB            : std_logic_vector(11 downto 0);
    --
    signal M_HSYNC         : std_logic;
    signal M_VSYNC         : std_logic;
    --
    signal video_r         : std_logic_vector(5 downto 0);
    signal video_g         : std_logic_vector(5 downto 0);
    signal video_b         : std_logic_vector(5 downto 0);
    signal video_r_x2      : std_logic_vector(5 downto 0);
    signal video_g_x2      : std_logic_vector(5 downto 0);
    signal video_b_x2      : std_logic_vector(5 downto 0);
    signal hsync_x2        : std_logic;
    signal vsync_x2        : std_logic;
    signal scanlines       : std_logic_vector(1 downto 0);
    --
    signal reset           : std_logic;
    --
    signal oSND            : std_logic_vector(7 downto 0);
    signal audio_pwm       : std_logic;
    --
    signal INP0            : std_logic_vector(7 downto 0);
    signal INP1            : std_logic_vector(7 downto 0);
    signal dsw0            : std_logic_vector(7 downto 0);
    signal dsw1            : std_logic_vector(7 downto 0);
    -- DIP defaults as upstream (MAME DSWA, DSWB bit values)
    constant DSW0_DEFAULT  : std_logic_vector(7 downto 0) := "10111001";
    constant DSW1_DEFAULT  : std_logic_vector(7 downto 0) := "00111100";
    --
    signal kbd_intr        : std_logic;
    signal kbd_scancode    : std_logic_vector(7 downto 0);
    signal kbd_joy         : std_logic_vector(8 downto 0);
    signal joy_BBBBFRLDU   : std_logic_vector(8 downto 0);
    signal ps2_clk_meta    : std_logic;
    signal ps2_clk_s       : std_logic;
    signal ps2_dat_meta    : std_logic;
    signal ps2_dat_s       : std_logic;
    signal btn_meta        : std_logic_vector(3 downto 0);
    signal btn_s           : std_logic_vector(3 downto 0);
    signal stick_meta      : std_logic_vector(4 downto 0);
    signal stick_s         : std_logic_vector(4 downto 0);
    attribute ASYNC_REG    : string;
    attribute ASYNC_REG of btn_meta, btn_s, stick_meta, stick_s : signal is "TRUE";
    attribute ASYNC_REG of ps2_clk_meta, ps2_clk_s, ps2_dat_meta, ps2_dat_s : signal is "TRUE";
    --
    constant CLOCK_FREQ    : integer := 27E6;
    signal counter_clk     : std_logic_vector(25 downto 0);
    signal clock_4hz       : std_logic;
    signal AD              : std_logic_vector(15 downto 0);
---------------------------------------------------------------------------
begin

    -- btnC reset, held until the MMCM locks
    reset <= btnC or not pll_lock;

    -- sw12 up: test mode (INP0 bit 7, SERVICE)
    INP0 <= sw(12) & "00" & joy_BBBBFRLDU(7) & not joy_BBBBFRLDU(6) & not joy_BBBBFRLDU(5) & joy_BBBBFRLDU(4) & joy_BBBBFRLDU(4);
    INP1 <= joy_BBBBFRLDU(2) & joy_BBBBFRLDU(1) & joy_BBBBFRLDU(3) & joy_BBBBFRLDU(0) & joy_BBBBFRLDU(2) & joy_BBBBFRLDU(1) & joy_BBBBFRLDU(3) & joy_BBBBFRLDU(0);

    -- DIP switches (switch list in the header), switch up inverts the default bit.
    -- dsw0 (DSWA): coin B 2:0, bonus life 5:3, lives 7:6.
    -- dsw1 (DSWB): difficulty 1:0, cabinet 2, continue 3, demo sounds 4, freeze 5,
    -- coin A 7:6.
    dsw0 <= DSW0_DEFAULT xor (sw(4 downto 3) & sw(2 downto 0) & "000");
    dsw1 <= DSW1_DEFAULT xor ("00" & sw(9) & sw(8) & sw(7) & '0' & sw(6 downto 5));

---------------------------------------------------------------------------
    -- Clock: one MMCM with the frequencies of the Tang Nano 20K clocks
    clk_wiz_0 : entity work.clk_wiz_0
    port map (
        reset    => mmcm_reset,
        clk_in1  => clk,
        clk_out1 => clock_48,
        clk_out2 => clock_24,
        clk_out3 => clock_12,
        locked   => pll_lock
    );

---------------------------------------------------------------------------
    -- Main

    digdug : entity work.FPGA_DIGDUG
    port map (
        MCLK  => clock_48,
        RESET => reset,
        INP0  => INP0,
        INP1  => INP1,
        DSW0  => dsw0,
        DSW1  => dsw1,
        PH    => HPOS,
        PV    => VPOS,
        PCLK  => PCLK,
        POUT  => oPIX,
        SOUT  => oSND,
        AD    => AD
    );

------------------------------------------------------------------------------
    -- Video Gen

    iRGB <= oPIX(7 downto 6) & "00" & oPIX(5 downto 3) & '0' & oPIX(2 downto 0) & '0';

    hvgen : entity work.HVGEN
    port map (
        HPOS => HPOS,
        VPOS => VPOS,
        PCLK => PCLK,
        iRGB => iRGB,
        oRGB => oRGB, -- video_b & video_g & video_r,
        HBLK => open,
        VBLK => open,
        HSYN => M_HSYNC,
        VSYN => M_VSYNC
    );

------------------------------------------------------------------------------
    -- scan doubler

    video_r <= oRGB(3 downto 0) & "00";
    video_g <= oRGB(7 downto 4) & "00";
    video_b <= oRGB(11 downto 8) & "00";

    -- sw14 up: scanlines, alternate lines at 50 % brightness (31 kHz output only)
    scanlines <= "10" when sw(14) = '1' else "00";

    dblscan : entity work.scandoubler
    port map (
        clk_sys   => clock_24,
        scanlines => scanlines,
        r_in      => video_r,
        g_in      => video_g,
        b_in      => video_b,
        hs_in     => M_HSYNC,
        vs_in     => M_VSYNC,
        r_out     => video_r_x2,
        g_out     => video_g_x2,
        b_out     => video_b_x2,
        hs_out    => hsync_x2,
        vs_out    => vsync_x2
    );

-------------------------------------------------------------------------
    -- vga outputs

    -- sw13 down: 31 kHz VGA (scandoubler), up: 15 kHz TV with composite sync on HS
    process(clock_24)
    begin
        if rising_edge(clock_24) then
            if sw(13) = '0' then
                vga_r <= video_r_x2(5 downto 2);
                vga_g <= video_g_x2(5 downto 2);
                vga_b <= video_b_x2(5 downto 2);
                hsync <= hsync_x2;
                vsync <= vsync_x2;
            else
                vga_r <= video_r(5 downto 2);
                vga_g <= video_g(5 downto 2);
                vga_b <= video_b(5 downto 2);
                hsync <= M_HSYNC and M_VSYNC; -- composite sync, active low
                vsync <= '1';
            end if;
        end if;
    end process;

------------------------------------------------------------------------------
    -- get scancode from keyboard

    process(clock_12)
    begin
        if rising_edge(clock_12) then
            ps2_clk_meta <= ps2_clk;
            ps2_clk_s    <= ps2_clk_meta;
            ps2_dat_meta <= ps2_dat;
            ps2_dat_s    <= ps2_dat_meta;
        end if;
    end process;

    keyboard : entity work.io_ps2_keyboard
    port map (
        clk       => clock_12,
        kbd_clk   => ps2_clk_s,
        kbd_dat   => ps2_dat_s,
        interrupt => kbd_intr,
        scancode  => kbd_scancode
    );

------------------------------------------------------------------------------
    -- translate scancode to joystick

    joystick : entity work.kbd_joystick
    port map (
        clk           => clock_12,
        kbdint        => kbd_intr,
        kbdscancode   => std_logic_vector(kbd_scancode),
        joy_BBBBFRLDU => kbd_joy
    );

------------------------------------------------------------------------------
    -- buttons and JA joystick (active low, pins 1/2/3/4/7 = R/L/D/U/fire):
    -- 2-FF synchronizers, ORed with the keyboard
    process(clock_12)
    begin
        if rising_edge(clock_12) then
            btn_meta   <= btnU & btnD & btnL & btnR;
            btn_s      <= btn_meta;
            stick_meta <= JA;
            stick_s    <= stick_meta;
        end if;
    end process;

    joy_BBBBFRLDU(0) <= kbd_joy(0) or not stick_s(3); -- up
    joy_BBBBFRLDU(1) <= kbd_joy(1) or not stick_s(2); -- down
    joy_BBBBFRLDU(2) <= kbd_joy(2) or not stick_s(1); -- left
    joy_BBBBFRLDU(3) <= kbd_joy(3) or not stick_s(0); -- right
    joy_BBBBFRLDU(4) <= kbd_joy(4) or not stick_s(4); -- fire
    joy_BBBBFRLDU(5) <= kbd_joy(5) or btn_s(1); -- start 1: btnL
    joy_BBBBFRLDU(6) <= kbd_joy(6) or btn_s(0); -- start 2: btnR
    joy_BBBBFRLDU(7) <= kbd_joy(7) or btn_s(3) or btn_s(2); -- coin: btnU, btnD
    joy_BBBBFRLDU(8) <= kbd_joy(8);

------------------------------------------------------------------------------
    -- Audio DAC: 1-bit output to the PmodAMP2

    u_dac : entity work.dac
    generic map (
        msbi_g => 7
    )
    port map (
        clk_i   => clock_12,
        res_n_i => '1',
        dac_i   => oSND,
        dac_o   => audio_pwm
    );

    JXADC(0) <= audio_pwm;
    JXADC(1) <= '1';        -- PmodAMP2 GAIN (JXADC2), active low: fixed low gain
    JXADC(2) <= '0';
    JXADC(3) <= not sw(15); -- PmodAMP2 SHUTD (JXADC4), active low: sw15 up = audio off

------------------------------------------------------------------------------
    -- debug

    led(15 downto 6) <= (others => '0');

    process(reset, clock_24)
    begin
        if reset = '1' then
            clock_4hz <= '0';
            counter_clk <= (others => '0');
        else
            if rising_edge(clock_24) then
                if counter_clk = CLOCK_FREQ/8 then
                    counter_clk <= (others => '0');
                    clock_4hz <= not clock_4hz;
                    led(5 downto 0) <= not AD(9 downto 4);
                else
                    counter_clk <= counter_clk + 1;
                end if;
            end if;
        end if;
    end process;

------------------------------------------------------------------------
end struct;
