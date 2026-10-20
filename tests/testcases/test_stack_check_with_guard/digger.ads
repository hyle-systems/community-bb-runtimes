--  A task that digs: each frame holds 256 bytes and calls itself until the
--  compiler's stack check (-fstack-check on this unit, the harness's
--  compiler_switches) finds the frame below the task's stack limit and
--  raises Storage_Error, which ends in the last-chance handler.

with System;

package Digger is

   --  Above the main program, which only loops: the digger runs first and the
   --  last-chance handler, reached in its context, never lets main print.
   task Dig_Task with Priority => System.Default_Priority + 1, Storage_Size => 16384;

   Depth : Natural := 0 with Volatile;

end Digger;
