with Ada.Interrupts.Names;
with System;
with System.Storage_Elements;

package Switch_Probe is

   task Digger with Priority => 100, Storage_Size => 4096;
   task Waker  with Priority => 200, Storage_Size => 2048;

   --  The storm: a device interrupt whose handler pends itself again until
   --  a time on the runtime's clock, longer than Waker's period, so the
   --  alarm that wakes Waker lands inside it. Its priority is one step above
   --  the lowest: at the lowest, the handler's effective level equals
   --  PendSV's and the core takes PendSV first by exception number, right
   --  after the one request (measured: one request, the save faulted at the
   --  window); one step higher, every pending storm entry is tail-chained
   --  ahead of PendSV, and each finds the switch still pending and requests
   --  it again, until the storm ends and PendSV runs.
   protected Storm
     with Interrupt_Priority => System.Interrupt_Priority'First + 1
   is
      procedure IRQ_Handler
        with Attach_Handler => Ada.Interrupts.Names.TIM1_CC_Interrupt;
   end Storm;

   Headroom : System.Storage_Elements.Integer_Address := 0 with Volatile;
   Storm_Entries : Natural := 0 with Volatile;
   --  How many times the storm's handler ran, for the last-chance handler
   --  Bytes between Digger's deepest frame and the top of its guard window,
   --  for the last-chance handler to report as in or out of the band.

end Switch_Probe;
