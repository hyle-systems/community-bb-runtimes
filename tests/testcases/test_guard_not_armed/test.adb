--  The tasking runtime checks at its start that the start-up armed the
--  stack guard (s-bbcppr.adb, Initialize_CPU) and reports a start-up that
--  did not as a fault, "stack guard not armed by the start-up" (embedded
--  parks instead: test_guard_not_armed_park). Linked with an 8-byte window
--  (opt.py), the start-up skips its guard block and leaves the MPU off;
--  the check must fire before the main program prints anything. Sleeper's
--  task makes this a tasking program.

with Ada.Text_IO;

with Sleeper; pragma Unreferenced (Sleeper);
with Test_LCH; pragma Unreferenced (Test_LCH);

procedure Test is
begin
   Ada.Text_IO.Put_Line ("the runtime started without its guard: not expected");
   Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
end Test;
