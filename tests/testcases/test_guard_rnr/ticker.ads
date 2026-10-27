with System;

package Ticker is
   Ticks : Natural := 0 with Volatile;

   --  Two tasks above the environment task, at different periods: three
   --  threads share the guard's two task regions, so the switches keep
   --  reprogramming them (two threads alone would each keep a region)
   task Tick_A with Priority => System.Priority'Last;
   task Tick_B with Priority => System.Priority'Last - 1;
end Ticker;
