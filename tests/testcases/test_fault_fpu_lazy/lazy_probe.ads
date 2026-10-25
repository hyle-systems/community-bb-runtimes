--  The probe behind test_fault_fpu_lazy: a task that parks its stack pointer
--  48 bytes above its own guard window with the FPU in use and pends a
--  device interrupt there. See test.adb for what must follow.

with Ada.Interrupts.Names;
with System;
with System.Storage_Elements;

package Lazy_Probe is

   task Digger with Priority => 100, Storage_Size => 4096;

   Value : Float := 0.0 with Volatile;
   --  Computed on the FPU by Digger (so that FPCA is set), printed by the
   --  last-chance handler with the FPU: 1.5

   Window_Top : System.Storage_Elements.Integer_Address := 0 with Volatile;
   --  The top of Digger's guard window, for the handler's checks

   --  The interrupt whose entry meets the window. Its handler never runs:
   --  the entry's stacking faults first. A device interrupt and not the
   --  SysTick alarm, which the runtime places at the fault handlers' own
   --  priority (0): a stacking fault on its entry would escalate to hard
   --  fault, where the MPU is off and the lazy state lands unseen.
   protected Handler
     with Interrupt_Priority => System.Interrupt_Priority'Last
   is
      procedure IRQ_Handler
        with Attach_Handler => Ada.Interrupts.Names.TIM1_CC_Interrupt;
   end Handler;

end Lazy_Probe;
