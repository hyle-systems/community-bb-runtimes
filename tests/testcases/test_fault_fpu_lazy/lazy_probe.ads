--  Digger and the values the last-chance handler checks; test.adb says
--  what must follow.

with Ada.Interrupts.Names;
with System;
with System.Storage_Elements;

package Lazy_Probe is

   task Digger with Priority => 100, Storage_Size => 4096;

   Value : Float := 0.0 with Volatile;
   --  1.5, computed on the FPU by Digger so that FPCA is set, and printed
   --  through the FPU by the last-chance handler

   Window_Top : System.Storage_Elements.Integer_Address := 0 with Volatile;
   --  The top of Digger's guard window, for the handler's checks

   --  The interrupt whose entry meets the window. Its handler never runs,
   --  because the entry's stacking faults first. It is a device interrupt
   --  because the runtime places the SysTick alarm at the fault handlers'
   --  own priority (0): a stacking fault on the alarm's entry would escalate
   --  to a hard fault, where the MPU is off and the lazy save lands unseen.
   protected Handler
     with Interrupt_Priority => System.Interrupt_Priority'Last
   is
      procedure IRQ_Handler
        with Attach_Handler => Ada.Interrupts.Names.TIM1_CC_Interrupt;
   end Handler;

end Lazy_Probe;
