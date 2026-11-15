--  Checks that the crate enables PLL1's Q output (PLL_Q_Enable) with its
--  divider (PLL_Q_Div = 4), read back from RCC_PLLCFGR DIVQ1EN (bit 17) and
--  RCC_PLL1DIVR DIVQ1 (bits 22:16, the divider minus one), and leaves the
--  unused R output off with its divider at zero (RM0468 8.5.5, 8.7.11,
--  8.7.12). The frequency itself is not measured.

with Ada.Text_IO;
with Interfaces; use Interfaces;
with System;

procedure Test is
   PLLCFGR  : Unsigned_32 with Volatile, Import,
     Address => System'To_Address (16#5802_442C#);
   PLL1DIVR : Unsigned_32 with Volatile, Import,
     Address => System'To_Address (16#5802_4430#);
   Q_En : constant Boolean := (PLLCFGR and 2 ** 17) /= 0;
   R_En : constant Boolean := (PLLCFGR and 2 ** 18) /= 0;
   DIVQ : constant Unsigned_32 := Shift_Right (PLL1DIVR, 16) and 16#7F#;
   DIVR : constant Unsigned_32 := Shift_Right (PLL1DIVR, 24) and 16#7F#;
begin
   Ada.Text_IO.Put_Line ("Q enabled: " & Boolean'Image (Q_En));
   Ada.Text_IO.Put_Line ("Q divider:" & Unsigned_32'Image (DIVQ + 1));
   Ada.Text_IO.Put_Line
     ("R off, its divider at zero: " & Boolean'Image (not R_En and DIVR = 0));
   Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
end Test;
