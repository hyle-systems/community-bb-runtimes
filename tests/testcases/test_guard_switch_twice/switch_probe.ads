with Ada.Interrupts.Names;
with System;
with System.Storage_Elements;

package Switch_Probe is

   task Digger with Priority => 100, Storage_Size => 4096;
   task Waker  with Priority => 200, Storage_Size => 2048;

   --  A device interrupt whose handler pends itself again for longer than
   --  Waker's period, so the alarm that wakes Waker lands inside the storm.
   --  One step above the lowest priority, every pending entry tail-chains
   --  ahead of PendSV and requests the switch again until the storm ends.
   --  At the lowest, its level equals PendSV's and the core takes PendSV
   --  first by exception number (measured on the board: one request, and
   --  the save faulted at the window).
   protected Storm
     with Interrupt_Priority => System.Interrupt_Priority'First + 1
   is
      procedure IRQ_Handler
        with Attach_Handler => Ada.Interrupts.Names.TIM1_CC_Interrupt;
   end Storm;

   Headroom : System.Storage_Elements.Integer_Address := 0 with Volatile;
   --  Bytes between Digger's stack pointer where it parks and the top of its
   --  guard window; the last-chance handler checks it against the band.

   Storm_Entries : Natural := 0 with Volatile;
   --  How many times the storm's handler ran, for the last-chance handler.

end Switch_Probe;
