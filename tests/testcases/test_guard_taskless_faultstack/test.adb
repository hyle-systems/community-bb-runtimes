--  A light-tasking program with no tasking unit has an empty interrupt
--  stack; the start-up's region 1, "at the interrupt stack's start", would
--  then sit on the fault stack that follows it. With a 512-byte window and a
--  512-byte fault stack the whole fault stack is no-access: the report's
--  first push faults and the write below is reported as a hard fault. The
--  expectation is the plain one: a memory management fault.
--
--  Stack_Guard = true in a program with no tasking unit: a store into the
--  environment stack's guard window (its first word, at __stack_start) must
--  be a memory management fault, routed to the last-chance handler. Without
--  the guard the store lands - the window is far below the stack in use -
--  and the program prints so (light-tasking did, before the start-up
--  programmed the static guards).

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
