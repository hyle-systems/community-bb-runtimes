--  The runtime makes no supervisor calls, so an SVC must be trapped like a
--  fault: on the fault stack, under the latch, and to the last-chance
--  handler as "unhandled trap". Otherwise light would loop silently, and
--  the tasking runtimes' handler would raise off the fault path.

with System.Machine_Code; use System.Machine_Code;
with Ada.Text_IO;

with Test_LCH; pragma Unreferenced (Test_LCH);

procedure Test is
begin
   Ada.Text_IO.Put_Line ("before the svc");
   Asm ("svc #0", Volatile => True);
   Ada.Text_IO.Put_Line ("after the svc: not expected");
end Test;
