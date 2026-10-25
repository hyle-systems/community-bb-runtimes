--  Lazy floating-point state across a fault into the guard. Digger, with the
--  FPU in use, digs to between 48 and 104 bytes above its own window and
--  writes into the window: a memory management fault whose exception frame
--  keeps its integer part above the window and reserves the lazily stacked
--  FP area inside it (LSPACT set, no write yet). The fault's handling must
--  then be free to use the FPU: the last-chance handler prints a Float.
--  A trap that leaves the lazy state pending lets that first FP instruction
--  save s0-s15 into the no-access window - a fault inside the fault
--  handler, an escalation to hard fault, a second entry into the report,
--  which parks: nothing after "last chance".

with Ada.Text_IO;

with Test_LCH;   pragma Unreferenced (Test_LCH);
with Lazy_Probe; pragma Unreferenced (Lazy_Probe);

procedure Test is
   pragma Priority (50);
begin
   loop
      null;
   end loop;
end Test;
