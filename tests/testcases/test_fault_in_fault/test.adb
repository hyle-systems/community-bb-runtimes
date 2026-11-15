--  A fault inside the last-chance handler itself: the test's handler
--  reports Main's bus fault, then reads the same unmapped address. That
--  second fault escalates to a hard fault and re-enters the fault report.
--  Without a guard the handler would report and fault again until the core
--  locks up; with it, the report parks on its second entry, on the fault
--  stack, printing nothing more (test.out has no completion marker: the
--  harness compares what arrived when its read timed out).

with Ada.Text_IO;
with Interfaces; use Interfaces;
with System;

with Test_LCH; pragma Unreferenced (Test_LCH);

procedure Test is
   Nowhere : Unsigned_32 with Volatile, Import,
     Address => System'To_Address (16#D000_0000#);
   Value : Unsigned_32;
begin
   Value := Nowhere;
   Ada.Text_IO.Put_Line ("the read returned" & Unsigned_32'Image (Value));
   Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
end Test;
