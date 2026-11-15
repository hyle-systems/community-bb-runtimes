with System;

package Digger is

   --  Above the main program, which only loops: the digger runs first, and
   --  the last-chance handler, reached in its context, never lets main print.
   task Dig_Task with Priority => System.Default_Priority + 1, Storage_Size => 16384;

   Depth : Natural := 0 with Volatile;

end Digger;
