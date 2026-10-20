--  AdaCore's BSP verification testsuite (bb-runtimes/tests/bsp_verification),
--  the units copied unchanged: the non-tasking delay semantics, the clock's
--  granularity, the basic tasking constructs, and a task-termination
--  fallback handler installed at elaboration. One pass instead of the
--  original's endless loop, then the completion marker.

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
