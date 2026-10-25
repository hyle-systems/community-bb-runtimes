--  The largest window, 512 bytes, against the runtime's own idle task: its
--  2 KB stack, aligned to 8, keeps at least 1 032 bytes above a 512-byte
--  window wherever the linker puts it (a 1 KB window could leave eight).
--  Every task blocks, fifty times, so the idle task runs under the guard
--  between the blocks.

with Ada.Real_Time; use Ada.Real_Time;
with Ada.Text_IO;

with Idle_Probe;

procedure Test is
   pragma Priority (50);
   Next : Time := Clock;
begin
   Ada.Text_IO.Put_Line ("blocking fifty times under a 512-byte guard");
   loop
      Next := Next + Milliseconds (1);
      delay until Next;
      exit when Idle_Probe.Done;
   end loop;
   Ada.Text_IO.Put_Line ("idle survived");
   Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
end Test;
