--  A configurable fault raised while PRIMASK masks every configurable
--  exception escalates to HardFault (Armv7-M). The family still routes it
--  to the last-chance handler, but the name is "hard fault", not the
--  fault's own: the runtime's critical sections run with PRIMASK set, so
--  an overflow or bus error inside one reads this way.

with Ada.Text_IO;
with System.Machine_Code; use System.Machine_Code;

with Test_LCH; pragma Unreferenced (Test_LCH);

procedure Test is
begin
   Ada.Text_IO.Put_Line ("undefined instruction with PRIMASK set");
   Asm ("cpsid i", Volatile => True);
   Asm ("udf #0", Volatile => True);
   Ada.Text_IO.Put_Line ("returned from the undefined instruction");
   Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
end Test;
