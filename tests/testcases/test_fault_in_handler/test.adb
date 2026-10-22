--  An interrupt handler overflows the interrupt stack under the MPU guard.
--  The memory management fault's handling must run on a stack of its own -
--  the fault stack the trap switches to - not below the interrupt stack it
--  just overflowed, where the ECC words and .bss lie. Before the fault
--  stack, the MemManage handler's own first push landed in the window, the
--  fault escalated, and "hard fault" was reported from below the stack. The
--  test's handler prints the report and whether it runs above the
--  interrupt stack's end.

with Ada.Real_Time; use Ada.Real_Time;
with Ada.Text_IO;

with Overflow;
with Test_LCH; pragma Unreferenced (Test_LCH);

procedure Test is
begin
   Ada.Text_IO.Put_Line ("pending the interrupt");
   Overflow.Pend;
   delay until Clock + Milliseconds (500);
   Ada.Text_IO.Put_Line ("the handler returned at depth" & Natural'Image (Overflow.Depth));
   Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
end Test;
