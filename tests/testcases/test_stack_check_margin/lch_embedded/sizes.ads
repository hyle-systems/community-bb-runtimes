--  The task's stack on embedded: its body's frame and output plus the
--  probe's margin (about 12.2 KB with exception tables), not the 5 KB frame.

package Sizes is
   Task_Stack : constant := 16384;
end Sizes;
