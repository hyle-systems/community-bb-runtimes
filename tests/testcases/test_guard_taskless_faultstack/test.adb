--  test_guard_taskless_hit's store, on light-tasking, where a program with
--  no tasking unit has an empty interrupt stack. The start-up's region 13
--  at its start would sit on the fault stack that follows: with a 512-byte
--  window over a 512-byte fault stack, all of it no-access, the report's
--  first push would fault and the store would show as a hard fault. It
--  must be reported as a memory management fault instead.

with Ada.Text_IO;
with Interfaces; use Interfaces;

with Test_LCH; pragma Unreferenced (Test_LCH);

procedure Test is
   Window : Unsigned_32 with Volatile, Import, Convention => Asm, External_Name => "__stack_start";
begin
   Ada.Text_IO.Put_Line ("writing into the environment stack's guard window");
   Window := 16#DEAD_0000#;
   Ada.Text_IO.Put_Line ("the write landed");
   Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
end Test;
