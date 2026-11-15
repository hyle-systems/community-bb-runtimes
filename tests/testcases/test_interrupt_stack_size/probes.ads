--  An interrupt handler that records its stack pointer, pended through the
--  NVIC as the shared STM32 interrupt test does.

with Ada.Interrupts.Names;
with Interfaces;
with System;

package Probes is

   function Current_SP return Interfaces.Unsigned_32;

   Handler_SP : Interfaces.Unsigned_32 := 1 with Volatile;

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
