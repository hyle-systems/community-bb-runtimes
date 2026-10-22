--  An interrupt handler that overflows the interrupt stack: it digs with
--  256-byte frames until a store lands in the stack's guard window. The
--  MemManage fault is taken at the handler's priority (the wrapper runs a
--  handler with BASEPRI set and PRIMASK clear); before the fault stack,
--  the MemManage handler's own first push landed in the window and the
--  fault escalated to a hard fault reported from below the stack. Pended
--  through the NVIC like the last-vector test (TIM24, interrupt 162, ISPR5
--  bit 2).

with Ada.Interrupts.Names;
with System;

package Overflow is

   IRQ : constant Ada.Interrupts.Interrupt_ID :=
     Ada.Interrupts.Names.TIM24_Interrupt;   -- 162

   protected Handler
     with Interrupt_Priority => System.Interrupt_Priority'First
   is
   private
      procedure Serve with Attach_Handler => IRQ;
   end Handler;

   procedure Pend;

   Depth : Natural := 0 with Volatile;

end Overflow;
