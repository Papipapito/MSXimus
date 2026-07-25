LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

-- Simple USB -> MSX keyboard matrix mapper
-- Matrix: 11 rows (0..10), 8 columns (bit7..bit0) according to your table.

ENTITY usb_keyboard_msx IS
    PORT (
        CLK      : IN  STD_LOGIC;
        RESET    : IN  STD_LOGIC;

        -- key vector from USB module; '1' = key pressed
        keyboard : IN  STD_LOGIC_VECTOR(127 DOWNTO 0);

        -- matrix row number selected by CPU (0..10)
        A        : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);

        -- column state in selected row, active low '0'
        DO       : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);

        -- function keys line (F1..F12), active high '1'
        FN       : OUT STD_LOGIC_VECTOR(1 TO 12)
    );
END usb_keyboard_msx;

ARCHITECTURE rtl OF usb_keyboard_msx IS

    TYPE key_matrix IS ARRAY (10 DOWNTO 0) OF STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL keys : key_matrix;

BEGIN

    -------------------------------------------------------------------------
    -- Matrix row MUX according to A(3..0)
    -------------------------------------------------------------------------
    PROCESS (A, keys)
    BEGIN
        CASE A IS
            WHEN "0000" => DO <= keys(0);
            WHEN "0001" => DO <= keys(1);
            WHEN "0010" => DO <= keys(2);
            WHEN "0011" => DO <= keys(3);
            WHEN "0100" => DO <= keys(4);
            WHEN "0101" => DO <= keys(5);
            WHEN "0110" => DO <= keys(6);
            WHEN "0111" => DO <= keys(7);
            WHEN "1000" => DO <= keys(8);
            WHEN "1001" => DO <= keys(9);
            WHEN "1010" => DO <= keys(10);
            WHEN OTHERS => DO <= (OTHERS => '1');  -- nothing selected
        END CASE;
    END PROCESS;

    -------------------------------------------------------------------------
    -- Main USB -> MSX matrix decoding
    -------------------------------------------------------------------------
    PROCESS (CLK, RESET)
    BEGIN
        IF RESET = '1' THEN
            -- all keys released
            FOR r IN 0 TO 10 LOOP
                keys(r) <= (OTHERS => '1');
            END LOOP;
            FN <= (OTHERS => '0');

        ELSIF CLK'EVENT AND CLK = '1' THEN

            -- default: no keys pressed
            FOR r IN 0 TO 10 LOOP
                keys(r) <= (OTHERS => '1');
            END LOOP;
            FN <= (OTHERS => '0');

            -----------------------------------------------------------------
            -- Modifiers (SHIFT, CTRL etc. – extended codes E0..E7)
            -- Assuming:
            --  keyboard(105) = Left Shift (E1)
            --  keyboard(109) = Right Shift (E5)
            --  keyboard(104) = Left Ctrl (E0 / E4)
            -----------------------------------------------------------------
            IF keyboard(105) = '1' OR keyboard(109) = '1' THEN
                -- SHIFT -> row 6, bit0
                keys(6)(0) <= '0';
            END IF;

            IF keyboard(104) = '1' THEN
                -- CTRL -> row 6, bit1
                keys(6)(1) <= '0';
            END IF;

            -----------------------------------------------------------------
            -- Other keys – standard HID codes 0..99
            -----------------------------------------------------------------
            FOR i IN 0 TO 127 LOOP
                IF keyboard(i) = '1' THEN
                    CASE i IS
                        -- Letters (according to table, rows 2..5)
                        WHEN 4 => keys(2)(6) <= '0'; -- A
                        WHEN 5 => keys(2)(7) <= '0'; -- B
                        WHEN 6 => keys(3)(0) <= '0'; -- C
                        WHEN 7 => keys(3)(1) <= '0'; -- D
                        WHEN 8 => keys(3)(2) <= '0'; -- E
                        WHEN 9 => keys(3)(3) <= '0'; -- F
                        WHEN 10 => keys(3)(4) <= '0'; -- G
                        WHEN 11 => keys(3)(5) <= '0'; -- H
                        WHEN 12 => keys(3)(6) <= '0'; -- I
                        WHEN 13 => keys(3)(7) <= '0'; -- J
                        WHEN 14 => keys(4)(0) <= '0'; -- K
                        WHEN 15 => keys(4)(1) <= '0'; -- L
                        WHEN 16 => keys(4)(2) <= '0'; -- M
                        WHEN 17 => keys(4)(3) <= '0'; -- N
                        WHEN 18 => keys(4)(4) <= '0'; -- O
                        WHEN 19 => keys(4)(5) <= '0'; -- P
                        WHEN 20 => keys(4)(6) <= '0'; -- Q
                        WHEN 21 => keys(4)(7) <= '0'; -- R
                        WHEN 22 => keys(5)(0) <= '0'; -- S
                        WHEN 23 => keys(5)(1) <= '0'; -- T
                        WHEN 24 => keys(5)(2) <= '0'; -- U
                        WHEN 25 => keys(5)(3) <= '0'; -- V
                        WHEN 26 => keys(5)(4) <= '0'; -- W
                        WHEN 27 => keys(5)(5) <= '0'; -- X
                        WHEN 28 => keys(5)(6) <= '0'; -- Y
                        WHEN 29 => keys(5)(7) <= '0'; -- Z

                        -- Top row digits (rows 0 and 1)
                        WHEN 30 => keys(0)(1) <= '0'; -- 1 !
                        WHEN 31 => keys(0)(2) <= '0'; -- 2 @
                        WHEN 32 => keys(0)(3) <= '0'; -- 3 #
                        WHEN 33 => keys(0)(4) <= '0'; -- 4 $
                        WHEN 34 => keys(0)(5) <= '0'; -- 5 %
                        WHEN 35 => keys(0)(6) <= '0'; -- 6 ^
                        WHEN 36 => keys(0)(7) <= '0'; -- 7 &
                        WHEN 37 => keys(1)(0) <= '0'; -- 8 *
                        WHEN 38 => keys(1)(1) <= '0'; -- 9 (
                        WHEN 39 => keys(0)(0) <= '0'; -- 0 )

                        -- Characters on row 1
                        WHEN 45 => keys(1)(2) <= '0'; -- - _
                        WHEN 46 => keys(1)(3) <= '0'; -- = +
                        WHEN 49 => keys(1)(4) <= '0'; -- \ ¦
                        WHEN 47 => keys(1)(5) <= '0'; -- [ {
                        WHEN 48 => keys(1)(6) <= '0'; -- ] }
                        WHEN 51 => keys(1)(7) <= '0'; -- ; :

                        -- Row 2: punctuation, DEAD key
                        WHEN 52 => keys(2)(0) <= '0'; -- ' "
                        WHEN 53 => keys(2)(1) <= '0'; -- ` ~
                        WHEN 54 => keys(2)(2) <= '0'; -- , 
                        WHEN 55 => keys(2)(3) <= '0'; -- . >
                        WHEN 56 => keys(2)(4) <= '0'; -- / ?
                        WHEN 50 => keys(2)(5) <= '0'; -- DEAD (accent key)

                        -- CapsLock as CAPS key (row 6, bit3)
                        WHEN 57 => keys(6)(3) <= '0'; -- CAPS

                        -- GRAPH (row6,bit2) and CODE/KANA (row6,bit4): not mapped in stock
                        -- nano. Mapped to the Alt keys (firmware remap: LAlt=106, RAlt=110).
                        -- CODE (international BIOS) and KANA (Japanese BIOS) are the SAME MSX
                        -- matrix key (row6 bit4) -> one key, region decides its meaning.
                        WHEN 110 => keys(6)(2) <= '0'; -- GRAPH      (Right Alt)
                        WHEN 106 => keys(6)(4) <= '0'; -- CODE/KANA  (Left Alt)

                        -- SPACE / ENTER / ESC / TAB / BS / STOP / SELECT
                        WHEN 44 => keys(8)(0) <= '0'; -- SPACE  (row 8, bit0)
                        WHEN 40 => keys(7)(7) <= '0'; -- RET    (row 7, bit7)
                        WHEN 41 => keys(7)(2) <= '0'; -- ESC    (row 7, bit2)
                        WHEN 43 => keys(7)(3) <= '0'; -- TAB    (row 7, bit3)
                        WHEN 42 => keys(7)(5) <= '0'; -- BS     (row 7, bit5)
                        WHEN 71 => keys(7)(4) <= '0'; -- STOP   (here: ScrollLock)
                        WHEN 77 => keys(7)(6) <= '0'; -- SELECT (here: End)

                        -- Arrow keys + HOME / INS / DEL (row 8)
                        -- row 8: bit7→,6↓,5↑,4←,3DEL,2INS,1HOME,0SPACE
                        WHEN 79 => keys(8)(7) <= '0'; -- RIGHT
                        WHEN 81 => keys(8)(6) <= '0'; -- DOWN
                        WHEN 82 => keys(8)(5) <= '0'; -- UP
                        WHEN 80 => keys(8)(4) <= '0'; -- LEFT
                        WHEN 76 => keys(8)(3) <= '0'; -- DEL
                        WHEN 73 => keys(8)(2) <= '0'; -- INS
                        WHEN 74 => keys(8)(1) <= '0'; -- HOME

                        -- Numeric keypad (rows 9 and 10)
                        -- row 9: 7 NUM4,6 NUM3,5 NUM2,4 NUM1,3 NUM0,2 NUM/,1 NUM+,0 NUM*
                        WHEN 92 => keys(9)(7) <= '0'; -- NUM4
                        WHEN 91 => keys(9)(6) <= '0'; -- NUM3
                        WHEN 90 => keys(9)(5) <= '0'; -- NUM2
                        WHEN 89 => keys(9)(4) <= '0'; -- NUM1
                        WHEN 98 => keys(9)(3) <= '0'; -- NUM0
                        WHEN 84 => keys(9)(2) <= '0'; -- NUM/
                        WHEN 87 => keys(9)(1) <= '0'; -- NUM+
                        WHEN 85 => keys(9)(0) <= '0'; -- NUM*

                        -- row 10: 7 NUM.,6 NUM,,5 NUM-,4 NUM9,3 NUM8,2 NUM7,1 NUM6,0 NUM5
                        WHEN 99 => keys(10)(7) <= '0'; -- NUM.
                        WHEN 86 => keys(10)(5) <= '0'; -- NUM-
                        WHEN 97 => keys(10)(4) <= '0'; -- NUM9
                        WHEN 96 => keys(10)(3) <= '0'; -- NUM8
                        WHEN 95 => keys(10)(2) <= '0'; -- NUM7
                        WHEN 94 => keys(10)(1) <= '0'; -- NUM6
                        WHEN 93 => keys(10)(0) <= '0'; -- NUM5

                        -----------------------------------------------------------------
                        -- Function keys: F1..F5 additionally marked on FN output
                        -- and written to matrix according to your table:
                        -- row 6: bit7 F3, bit6 F2, bit5 F1
                        -- row 7: bit1 F5, bit0 F4
                        -----------------------------------------------------------------
                        WHEN 58 =>  -- F1
                            keys(6)(5) <= '0';  -- row 6, bit5
                            FN(1)      <= '1';
                        WHEN 59 =>  -- F2
                            keys(6)(6) <= '0';  -- row 6, bit6
                            FN(2)      <= '1';
                        WHEN 60 =>  -- F3
                            keys(6)(7) <= '0';  -- row 6, bit7
                            FN(3)      <= '1';
                        WHEN 61 =>  -- F4
                            keys(7)(0) <= '0';  -- row 7, bit0
                            FN(4)      <= '1';
                        WHEN 62 =>  -- F5
                            keys(7)(1) <= '0';  -- row 7, bit1
                            FN(5)      <= '1';

                        -----------------------------------------------------------------
                        -- Physical F6..F10 -> synthetic SHIFT + F1..F5
                        --
                        -- The MSX matrix only has five function keys; F6..F10 are
                        -- obtained on a real machine by holding SHIFT while pressing
                        -- F1..F5. A USB keyboard, however, does have physical F6..F10
                        -- keys, so we make each of them assert BOTH its F(n-5) matrix
                        -- bit AND the SHIFT bit (row 6, bit0) - exactly the combination
                        -- the user would otherwise type by hand.
                        --
                        -- Why this cannot break the real SHIFT: the SHIFT bit is active
                        -- low and is only ever driven to '0' here. The single place that
                        -- drives it to '1' is the "all released" default at the top of
                        -- this clocked process, which runs BEFORE both the real-SHIFT
                        -- block (keyboard(105)/(109)) and this loop. Because in a VHDL
                        -- process the last assignment wins, and every later assignment
                        -- to keys(6)(0) is a '0', real SHIFT and synthetic SHIFT simply
                        -- OR together - neither can cancel the other. Manual SHIFT+F1..F5
                        -- therefore keeps working exactly as before.
                        --
                        -- Known side effect (identical to a real MSX): while F6..F10 is
                        -- held down the SHIFT bit is active, so any OTHER key pressed at
                        -- the same time is read as shifted. Accepted by design.
                        --
                        -- FN(6)..FN(10) are still asserted as before, so any internal
                        -- core function hanging off the FN bus is unaffected.
                        --
                        -- F11/F12 have no MSX matrix equivalent -> FN only, unchanged.
                        -----------------------------------------------------------------
                        WHEN 63 =>  -- F6 = SHIFT + F1
                            keys(6)(5) <= '0';  -- F1    (row 6, bit5)
                            keys(6)(0) <= '0';  -- SHIFT (row 6, bit0)
                            FN(6)      <= '1';
                        WHEN 64 =>  -- F7 = SHIFT + F2
                            keys(6)(6) <= '0';  -- F2    (row 6, bit6)
                            keys(6)(0) <= '0';  -- SHIFT (row 6, bit0)
                            FN(7)      <= '1';
                        WHEN 65 =>  -- F8 = SHIFT + F3
                            keys(6)(7) <= '0';  -- F3    (row 6, bit7)
                            keys(6)(0) <= '0';  -- SHIFT (row 6, bit0)
                            FN(8)      <= '1';
                        WHEN 66 =>  -- F9 = SHIFT + F4
                            keys(7)(0) <= '0';  -- F4    (row 7, bit0)
                            keys(6)(0) <= '0';  -- SHIFT (row 6, bit0)
                            FN(9)      <= '1';
                        WHEN 67 =>  -- F10 = SHIFT + F5
                            keys(7)(1) <= '0';  -- F5    (row 7, bit1)
                            keys(6)(0) <= '0';  -- SHIFT (row 6, bit0)
                            FN(10)     <= '1';

                        -- F11/F12 stay on the FN bus only (no MSX matrix key)
                        WHEN 68 => FN(11) <= '1';  -- F11
                        WHEN 69 => FN(12) <= '1';  -- F12

                        WHEN OTHERS =>
                            NULL;
                    END CASE;
                END IF;
            END LOOP;
        END IF;
    END PROCESS;

END rtl;