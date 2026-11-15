--  An interrupt handler overflows the interrupt stack under the MPU guard.
--  The memory management fault's handling must run on the fault stack the
--  trap switches to, not below the interrupt stack it just overflowed,
--  where the ECC words and .bss lie. Without the fault stack the MemManage
--  handler's first push lands in the window, the fault escalates, and
--  "hard fault" is reported from below the stack.

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
