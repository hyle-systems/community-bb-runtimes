--  The window write of test_guard_taskless_hit with the default interrupt
--  stack (1 KB) and a 256-byte guard window at its bottom. The expected
--  outcome is the memory management fault; on embedded the fault path - the
--  raise, the unwinder and the last-chance handler, all in handler mode on
--  the interrupt stack - needed more than the 768 bytes left, faulted again
--  inside the MemManage handler and escalated to a hard fault (finding 7,
--  2026-10-21; the registers: CFSR DACCVIOL + MMARVALID, MMFAR = the
--  window, once the stack was 8 KB). With the guard off the same overflow
--  walks below the interrupt stack silently. Light-tasking's path, a direct
--  call of the handler, fits.

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
