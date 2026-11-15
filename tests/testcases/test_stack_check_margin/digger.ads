--  The margin case: a task whose stack holds its body's frame plus the
--  probe's margin, and one procedure with a 5 KB frame. Under -fstack-check
--  that frame's prologue probes the margin below it, so the single call asks
--  for more than the stack holds and the check raises Storage_Error at once.

with System;
with Sizes;

package Digger is

   --  Above the main program, as in test_stack_check. The stack's size per
   --  profile is in Sizes (lch_light, lch_embedded).
   task Dig_Task with Priority => System.Default_Priority + 1, Storage_Size => Sizes.Task_Stack;

   Depth : Natural := 0 with Volatile;

end Digger;
