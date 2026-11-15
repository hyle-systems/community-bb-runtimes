--  AdaCore's BSP verification testsuite, its units copied unchanged from
--  bb-runtimes/tests/bsp_verification. This main is its bsp_verifier.adb
--  making a single pass, not looping forever, before the completion marker.
--  A pass is the suite's report with every check passed.

with Ada.Text_IO;
with Report_IO;
with Last_Wishes; pragma Unreferenced (Last_Wishes);
with Delays_Nontasking;
with Clock_Tests;
with Basic_Tasking;

procedure Test is
begin
   Report_IO.Put_Line ("BSP Verification Testsuite");
   Delays_Nontasking.Test;
   Clock_Tests.Test;
   Basic_Tasking.Test;
   Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
end Test;
