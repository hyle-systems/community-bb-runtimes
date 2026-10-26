with Ada.Interrupts.Names;
with System;
with System.Storage_Elements;

package Switch_Probe is

   task Digger with Priority => 100, Storage_Size => 4096;
   task Waker  with Priority => 200, Storage_Size => 2048;

   --  The storm: a device interrupt whose handler pends itself again while
   --  a count lasts, so the alarm that wakes Waker lands inside a handler
   --  of lower priority than the alarm and higher than PendSV. That handler
   --  finishes after the alarm, finds the switch still pending and requests
   --  it a second time - and so does every storm entry that follows, until
   --  the count runs out and PendSV runs.
   protected Storm with Interrupt_Priority => System.Interrupt_Priority'First is
      procedure IRQ_Handler
        with Attach_Handler => Ada.Interrupts.Names.TIM1_CC_Interrupt;
   end Storm;

   Headroom : System.Storage_Elements.Integer_Address := 0 with Volatile;
   --  Bytes between Digger's deepest frame and the top of its guard window,
   --  for the last-chance handler to report as in or out of the band.

end Switch_Probe;
