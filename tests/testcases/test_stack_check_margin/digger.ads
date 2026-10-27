--  The margin case: a stack that holds the task body's frame plus the
--  probe's margin, and one procedure whose frame holds 5 KB. With
--  -fstack-check its prologue probes the margin below the frame (about 4.4 KB
--  on light-tasking, 12.2 KB on embedded, whose code carries exception
--  tables), so the single call asks for more than the stack holds and the
--  check raises Storage_Error at once: every stack a checked frame runs on
--  must hold its peak use plus the probe's margin (the sizing rule). The
--  stack's size per profile is in Sizes (lch_light, lch_embedded).

with System;
with Sizes;

package Digger is

   --  Above the main program, which only loops: the digger runs first and the
   --  last-chance handler, reached in its context, never lets main print.
   task Dig_Task with Priority => System.Default_Priority + 1, Storage_Size => Sizes.Task_Stack;

   Depth : Natural := 0 with Volatile;

end Digger;
