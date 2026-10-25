--  S3: the compiler's check and the MPU guard together - the check fires first, the
--  guard is the net behind it. The depth band of test_stack_check applies.

with Ada.Text_IO;

with Digger; pragma Unreferenced (Digger);
with Test_LCH; pragma Unreferenced (Test_LCH);

procedure Test is
begin
   Ada.Text_IO.Put_Line ("main started");
   loop
      null;   --  the digger reports; main never prints the marker itself
   end loop;
end Test;
