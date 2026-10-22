--  The margin case: an 8 KB stack, and one procedure whose frame holds 5 KB.
--  With -fstack-check its prologue probes about 4.4 KB below the frame, so
--  the single call asks for more than the stack holds and the check raises
--  Storage_Error at once: every stack a checked frame runs on must hold its
--  peak use plus the probe's margin (the manifest's sizing rule).

with System;

package Digger is

   --  Above the main program, which only loops: the digger runs first and the
   --  last-chance handler, reached in its context, never lets main print.
   task Dig_Task with Priority => System.Default_Priority + 1, Storage_Size => 8192;

   Depth : Natural := 0 with Volatile;

end Digger;
