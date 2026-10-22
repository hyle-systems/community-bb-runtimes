--  The window write of test_guard_taskless_hit with the default stacks and
--  a 256-byte guard window. The expected outcome is the memory management
--  fault, reported from the fault stack. The history: while a fault's
--  handling ran on the interrupt stack, embedded's path - the raise, the
--  unwinder and the last-chance handler - needed more than the 768 bytes a
--  1 KB interrupt stack left beside the window, faulted again inside the
--  MemManage handler and escalated to a hard fault (CFSR DACCVIOL +
--  MMARVALID, MMFAR = the window, once there was room); with the guard off
--  the same overflow walked below the interrupt stack silently. The fault
--  stack ends both.

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
