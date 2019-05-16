LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

-- Project Oberon, Revised Edition 2013

-- Book copyright (C)2013 Niklaus Wirth and Juerg Gutknecht;
-- software copyright (C)2013 Niklaus Wirth (NW), Juerg Gutknecht (JG), Paul
-- Reed (PR/PDR).

-- Permission to use, copy, modify, and/or distribute this software and its
-- accompanying documentation (the "Software") for any purpose with or
-- without fee is hereby granted, provided that the above copyright notice
-- and this permission notice appear in all copies.

-- THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHORS DISCLAIM ALL WARRANTIES
-- WITH REGARD TO THE SOFTWARE, INCLUDING ALL IMPLIED WARRANTIES OF
-- MERCHANTABILITY, FITNESS AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
-- AUTHORS BE LIABLE FOR ANY CLAIM, SPECIAL, DIRECT, INDIRECT, OR
-- CONSEQUENTIAL DAMAGES OR ANY DAMAGES OR LIABILITY WHATSOEVER, WHETHER IN
-- AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
-- CONNECTION WITH THE DEALINGS IN OR USE OR PERFORMANCE OF THE SOFTWARE.*/

-- PS/2 mouse PDR 14.10.2013 / 03.09.2015 / 01.10.2015
-- with Microsoft 3rd (scroll) button init magic

-- wheel support and rewritten to VHDL by EMARD 10.05.2019
-- https://isdaman.com/alsos/hardware/mouse/ps2interface.htm

entity mousem is
  generic
  (
    c_x_bits: integer range 9 to 11 := 11;
    c_y_bits: integer range 9 to 11 := 11;
    c_z_bits: integer range 5 to 11 := 11
  );
  port
  (
    clk, reset: in std_logic;
    msclk, msdat: inout std_logic;
    update: out std_logic;
    x: out std_logic_vector(c_x_bits-1 downto 0);
    y: out std_logic_vector(c_y_bits-1 downto 0);
    z: out std_logic_vector(c_z_bits-1 downto 0);
    btn: out std_logic_vector(2 downto 0)
  );
end;

architecture syn of mousem is
  signal r_x, x_next, dx: std_logic_vector(c_x_bits-1 downto 0);
  signal r_y, y_next, dy: std_logic_vector(c_y_bits-1 downto 0);
  signal r_z, z_next, dz: std_logic_vector(c_z_bits-1 downto 0);
  signal pad_dx: std_logic_vector(c_x_bits-9 downto 0);
  signal pad_dy: std_logic_vector(c_y_bits-9 downto 0);
  signal pad_dz: std_logic_vector(c_z_bits-5 downto 0);
  signal r_btn, btn_next : std_logic_vector(2 downto 0);
  signal sent, sent_next : std_logic_vector(2 downto 0);
  signal rx, rx_next : std_logic_vector(41 downto 0);
  signal tx, tx_next : std_logic_vector(9 downto 0);
  signal rx7, rx8 : std_logic_vector(7 downto 0);
  signal count, count_next : std_logic_vector(14 downto 0);
  signal filter : std_logic_vector(5 downto 0);
  signal req : std_logic;
  signal shift, endbit, endcount, done, run : std_logic;
  signal cmd : std_logic_vector(8 downto 0);  --including odd tx parity bit
begin
  -- 322222222221111111111 (scroll mouse z and rx parity p ignored)
  -- 0987654321098765432109876543210   X, Y = overflow
  -- -------------------------------   s, t = x, y sign bits
  -- yyyyyyyy01pxxxxxxxx01pYXts1MRL0   normal report
  -- p--ack---0Ap--cmd---01111111111   cmd + ack bit (A) & byte
  
  run <= '1' when sent = 7 else '0';
  -- enable reporting, rate 200,100,80
  cmd <= "0" & x"F4" when sent = 0 
    else "0" & x"C8" when sent = 2 -- 200
    else "0" & x"64" when sent = 4 -- 100
    else "1" & x"50" when sent = 6 --  50
    else "1" & x"F3";
  endcount <= '1' when count(14 downto 12) = "111" else '0'; -- more than 11*100uS @25MHz
  shift <= '1' when req = '0' and filter = "100000" else '0'; -- low for 200nS @25MHz
  endbit <= (not rx(0)) when run = '1' else (not rx(rx'high-20));
  done <= endbit and endcount and not req;
  rx7 <= x"00" when rx(7) = '1' else rx(19 downto 12);
  pad_dx <= (others => rx(5));
  dx <= pad_dx & rx7;
  rx8 <= x"00" when rx(8) = '1' else rx(30 downto 23);
  pad_dy <= (others => rx(6));
  dy <= pad_dy & rx8;
  pad_dz <= (others => rx(37));
  dz <= pad_dz & rx(37 downto 34);

  x <= r_x;
  y <= r_y;
  z <= r_z;
  btn <= r_btn;

  msclk <= '0' when req = '1' else 'Z'; -- bidir clk/request
  msdat <= '0' when tx(0) = '0' else 'Z'; -- bidir data

  count_next <= (others => '0') when (reset or shift or endcount) = '1' else count + 1;
  sent_next <= (others => '0') when reset = '1' 
        else sent + 1 when (done and not run) = '1'
        else sent;
  tx_next <= (others => '1') when (reset or run) = '1' 
        else cmd & "0" when req = '1'
        else "1" & tx(tx'high downto 1) when shift = '1'
        else tx;
  rx_next <= (others => '1') when (reset or done) = '1'
        else msdat & rx(rx'high downto 1) when (shift and not endbit) = '1'
        else rx;
  x_next <= (others => '0') when run = '0'
        else x + dx when done = '1'
        else x;
  y_next <= (others => '0') when run = '0'
        else y - dy when done = '1'
        else y;
  z_next <= (others => '0') when run = '0'
        else z + dz when done = '1'
        else z;
  btn_next <= (others => '0') when run = '0'
        else rx(3 downto 1) when done = '1'
        else btn;
  process(clk)
  begin
    if rising_edge(clk) then
      filter <= filter(filter'high-1 downto 0) & msclk;
      count <= count_next;
      req <= (not reset) and (not run) and (req xor endcount);
      sent <= sent_next;
      tx <= tx_next;
      rx <= rx_next;
      x <= x_next;
      y <= y_next;
      z <= z_next;
      btn <= btn_next;
      update <= done;      
    end if;
  end process;  
end syn;
