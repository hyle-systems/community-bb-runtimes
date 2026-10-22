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
