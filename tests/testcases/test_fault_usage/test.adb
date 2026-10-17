--  An undefined instruction is a usage fault (the runtime enables the
--  usage, bus and memory-management fault exceptions at start-up). The
--  family routes it to the last-chance handler as "usage fault".

with Ada.Text_IO;
with System.Machine_Code; use System.Machine_Code;

with Test_LCH; pragma Unreferenced (Test_LCH);

procedure Test is
begin
   Ada.Text_IO.Put_Line ("executing an undefined instruction");
   Asm ("udf #0", Volatile => True);
   Ada.Text_IO.Put_Line ("returned from the undefined instruction");
   Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
end Test;
