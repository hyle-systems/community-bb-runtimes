with Ada.Real_Time; use Ada.Real_Time;

package body Ticker is
   task body Tick_A is
      Next : Time := Clock;
   begin
      loop
         Next := Next + Milliseconds (5);
         delay until Next;
         Ticks := Ticks + 1;
      end loop;
   end Tick_A;

   task body Tick_B is
      Next : Time := Clock;
   begin
      loop
         Next := Next + Milliseconds (7);
         delay until Next;
         Ticks := Ticks + 1;
      end loop;
   end Tick_B;
end Ticker;
