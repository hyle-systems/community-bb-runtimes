--  The last entry of the family's vector table: TIM24, interrupt 162, the
--  end of the table and of Number_Of_Interrupts (163). Pended through the
--  NVIC (ISPR5 bit 2), as the shared STM32 interrupt test pends its own.

with Ada.Interrupts.Names;
with System;

package Last_Vector is

   IRQ : constant Ada.Interrupts.Interrupt_ID :=
     Ada.Interrupts.Names.TIM24_Interrupt;   -- 162

   protected Handler
     with Interrupt_Priority => System.Interrupt_Priority'First
   is
   private
      procedure Serve with Attach_Handler => IRQ;
   end Handler;

   procedure Trigger_IRQ;

end Last_Vector;
