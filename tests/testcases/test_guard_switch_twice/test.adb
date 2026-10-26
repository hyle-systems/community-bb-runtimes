--  The guard across a context switch requested twice (Z1 of the fourth
--  review). test_guard_switch proves the outgoing task's window survives
--  one request; here the alarm that wakes Waker lands inside a storm of a
--  device interrupt, whose handler finishes after the alarm, finds the
--  switch still pending (the running thread changes only in PendSV) and
--  requests it again - as does every storm entry after it. A runtime that
--  programs the incoming window on every request, alternating two
--  regions, overwrites the outgoing task's window on the second request;
--  the PendSV save then lands in it silently and Waker runs ("waker ran").
--  The window must be programmed where the switch is made, once.
--
--  The rest as test_guard_switch: the window of the task being switched
--  out must stay armed while the PendSV handler saves that task's registers
--  onto its stack. Digger, with the FPU in use, digs to between 104 and 200
--  bytes above its own window and spins; Waker, of higher priority, wakes
--  from a delay, which switches the processor to it from the alarm
--  interrupt: the alarm's exception frame (104 bytes with the FPU) still
--  fits above the window, the PendSV save of r4-r11 and s16-s31 (96 bytes)
--  does not, and must be reported at once as a memory management fault.
--  A runtime that moves its single guard region to Waker before that save
--  lets the save land in the window silently, runs Waker ("waker ran"), and
--  faults only when it switches back and unstacks from the window.

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
