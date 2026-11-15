--  test_guard_switch with the switch requested many times. The alarm that
--  wakes Waker lands inside a storm of a device interrupt; every storm entry
--  after it finds the switch still pending (the running thread changes only
--  in PendSV) and requests it again. The window must be programmed once,
--  where the switch is made. A runtime that programs it on every request,
--  alternating two regions, overwrites the outgoing window on the second
--  request; the save then lands silently and Waker prints "waker ran".
--  Otherwise as test_guard_switch, with Digger 136 bytes above its window.

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
