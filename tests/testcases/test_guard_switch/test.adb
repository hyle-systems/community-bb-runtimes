--  The outgoing task's guard window must stay armed while the PendSV handler
--  saves its registers. Digger, using the FPU, parks 104-199 bytes above its
--  window; Waker, of higher priority, wakes from a delay and the alarm
--  interrupt switches to it. The alarm's exception frame (104 bytes with the
--  FPU) fits above the window, the PendSV save of s16-s31 below it (64 bytes)
--  does not, and must be reported at once as a memory management fault. A
--  runtime that moves its one guard region to Waker before the save lets it
--  land, prints "waker ran", and faults later, unstacking from the window.

with Ada.Text_IO;

with Test_LCH;     pragma Unreferenced (Test_LCH);
with Switch_Probe; pragma Unreferenced (Switch_Probe);

procedure Test is
   pragma Priority (50);
begin
   loop
      null;   --  the environment task: Digger and Waker run above it
   end loop;
end Test;
