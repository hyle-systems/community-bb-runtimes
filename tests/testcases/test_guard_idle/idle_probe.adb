with Ada.Real_Time; use Ada.Real_Time;

package body Idle_Probe is

   task body Blocker is
      Next : Time := Clock;
   begin
      for I in 1 .. 50 loop
         Next := Next + Milliseconds (2);
         delay until Next;
      end loop;
      Done := True;
      loop
         Next := Next + Milliseconds (100);
         delay until Next;
      end loop;
   end Blocker;

end Idle_Probe;
