--  The task and the interrupt handler of the alignment test (test.adb), the
--  handler pended through the NVIC as the shared STM32 interrupt test does.

with Ada.Interrupts.Names;
with Ada.Synchronous_Task_Control;
with Interfaces;
with System;

package Probes is

   function Current_SP return Interfaces.Unsigned_32;

   Task_SP    : Interfaces.Unsigned_32 := 1 with Volatile;
   Handler_SP : Interfaces.Unsigned_32 := 1 with Volatile;

   Task_Done : Ada.Synchronous_Task_Control.Suspension_Object;

   task Prober with Storage_Size => 4096;

   IRQ : constant Ada.Interrupts.Interrupt_ID :=
     Ada.Interrupts.Names.TIM1_CC_Interrupt;   -- 27: NVIC_ISPR0 bit 27

   protected Handler
     with Interrupt_Priority => System.Interrupt_Priority'First
   is
   private
      procedure Serve with Attach_Handler => IRQ;
   end Handler;

   procedure Trigger_IRQ;

end Probes;
