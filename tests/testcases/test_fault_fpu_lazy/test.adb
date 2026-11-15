--  Lazy floating-point state across a stacking fault into the guard. The
--  task Digger (see Lazy_Probe), with the FPU in use, parks its stack
--  pointer 48 bytes above its own window and pends a device interrupt: the
--  entry's integer push faults (MSTKERR) while the lazily reserved FP area
--  straddles the window's top (LSPACT set, nothing written yet). The
--  fault's handling must still be free to use the FPU: the last-chance
--  handler prints a Float, then what the core did with the lazy save.

with Ada.Text_IO;

with Test_LCH;   pragma Unreferenced (Test_LCH);
with Lazy_Probe; pragma Unreferenced (Lazy_Probe);

procedure Test is
   pragma Priority (50);

   --  Measured: the core itself settles the pending lazy state. The first
   --  FP instruction of the handling saves it, the save meets the window
   --  and faults (MLSPERR), and the core abandons the save, pends the
   --  memory management fault behind the active handler and completes the
   --  instruction. Nothing is written into the window and the report runs
   --  on. The test holds that behaviour; the trap adds nothing to it.
begin
   loop
      null;
   end loop;
end Test;
