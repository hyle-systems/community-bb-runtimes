--  test_guard_taskless_hit's window write, with the smallest interrupt
--  stack the crate accepts (1 KB) and a 256-byte guard window: the report
--  must still be the memory management fault, given from the fault stack.
--  On the interrupt stack, embedded's path (the raise, the unwinder and the
--  last-chance handler) needs more than the 768 bytes left beside the
--  window: it faults again inside the MemManage handler and the report
--  reads "hard fault"; with the guard off it walks below the stack silently.

with Ada.Text_IO;
with Interfaces; use Interfaces;

with Test_LCH; pragma Unreferenced (Test_LCH);

procedure Test is
   Window : Unsigned_32 with Volatile, Import, Convention => Asm, External_Name => "__stack_start";
begin
   Ada.Text_IO.Put_Line ("writing into the environment stack's guard window");
   --  With the report on the interrupt stack and room for it to run, the
   --  escalated fault shows CFSR DACCVIOL + MMARVALID, MMFAR = the window.
   Window := 16#DEAD_0000#;
   Ada.Text_IO.Put_Line ("the write landed");
   Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
end Test;
