--  The supply configuration (RM0468 Table 30) is the board's, set by the
--  crate option Supply_Configuration and written once by the start-up into
--  the lower byte of PWR_CR3 before anything touches RAM. The five bits
--  read back: BYPASS (0), LDOEN (1), SDEN (2), SDEXTHP (3), SDLEVEL (5:4).
--  The NUCLEO-H723ZG is an LDO board: LDOEN alone, 2#000010# = 2. The
--  register is reset only by a power-on reset, so a changed option takes
--  effect after a power cycle.
--
--  What the read-back proves: the bits the crate asked for are in the
--  register and the voltage levels are valid (ACTVOSRDY). What it cannot
--  prove: that this image wrote them. The harness resets the board with
--  system resets, never a power cycle, so a value left by an earlier image
--  built with the same option survives into this run; only a run after a
--  power cycle shows the start-up's own write.

with Ada.Text_IO;
with Interfaces; use Interfaces;
with System;

procedure Test is
   PWR_CR3  : Unsigned_32 with Volatile, Import,
     Address => System'To_Address (16#5802_480C#);
   PWR_CSR1 : Unsigned_32 with Volatile, Import,
     Address => System'To_Address (16#5802_4804#);
begin
   Ada.Text_IO.Put_Line
     ("PWR_CR3 supply bits =" & Unsigned_32'Image (PWR_CR3 and 16#3F#));
   Ada.Text_IO.Put_Line
     ("ACTVOSRDY =" & Unsigned_32'Image (Shift_Right (PWR_CSR1, 13) and 1));
   Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
end Test;
