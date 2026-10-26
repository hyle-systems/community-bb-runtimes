--  Lazy floating-point state across a stacking fault into the guard. Digger,
--  with the FPU in use, parks its stack pointer 48 bytes above its own window
--  and pends a device interrupt. The interrupt's entry frame, 104 bytes with
--  the FPU active, starts 56 bytes inside the window: the push of the integer
--  part faults (MSTKERR), a memory management fault taken at the fault
--  handlers' priority, with the lazily reserved FP area straddling the
--  window's top (LSPACT set, nothing written yet). The fault's handling must
--  then be free to use the FPU: the last-chance handler prints a Float.
--  The core itself settles the pending lazy state when its area meets the
--  window: that first FP instruction's save faults (MLSPERR), the core
--  abandons the save, pends the memory management fault behind the active
--  handler and completes the instruction - nothing is written into the
--  window, the report runs on. This test holds that measured behaviour;
--  the trap adds nothing to it.
--
--  The trigger is a device interrupt and not the SysTick alarm: the runtime
--  places the alarm at the fault handlers' priority, so a stacking fault on
--  its entry escalates to hard fault, where the MPU is off and the lazy
--  save lands silently.

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
