--  An interrupt handler that digs with 256-byte frames until a store lands
--  in the interrupt stack's guard window, pended through the NVIC like
--  test_vector_last's (TIM24, interrupt 162, ISPR5 bit 2).

with Ada.Interrupts.Names;
with System;

package Overflow is

   IRQ : constant Ada.Interrupts.Interrupt_ID :=
     Ada.Interrupts.Names.TIM24_Interrupt;   -- 162

   --  The MemManage fault is taken while this handler runs, at its
   --  priority: the wrapper runs a handler with BASEPRI set and PRIMASK
   --  clear.
   protected Handler
     with Interrupt_Priority => System.Interrupt_Priority'First
   is
   private
      procedure Serve with Attach_Handler => IRQ;
   end Handler;

   procedure Pend;

   Depth : Natural := 0 with Volatile;

end Overflow;
