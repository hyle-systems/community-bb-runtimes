--  Double-precision context across task switches and interrupts. Two
--  tasks each run a long double-precision chain whose result is known,
--  yielding to each other every step through delays, while an interrupt
--  handler that uses the FPU is pended at every step from the main program.
--  A register not preserved across a switch, or lazy stacking gone wrong,
--  shows as a wrong result in one of the chains.

with Ada.Interrupts.Names;
with Ada.Synchronous_Task_Control;
with Interfaces;
with System;

package Chains is

   Steps : constant := 200;

   type Result is record
      Value : Long_Float := 0.0;
      Done  : Boolean := False;
   end record with Volatile;

   Result_A, Result_B : Result;
   Done_A, Done_B : Ada.Synchronous_Task_Control.Suspension_Object;

   function Expected_A return Long_Float;
   function Expected_B return Long_Float;

   task Chain_A with Priority => System.Default_Priority + 1, Storage_Size => 8192;
   task Chain_B with Priority => System.Default_Priority + 1, Storage_Size => 8192;

   --  The handler's own chain, one term per interrupt
   Handler_Sum : Long_Float := 0.0 with Volatile;
   Handler_Count : Interfaces.Unsigned_32 := 0 with Volatile;

   IRQ : constant Ada.Interrupts.Interrupt_ID :=
     Ada.Interrupts.Names.TIM1_CC_Interrupt;   -- 27: NVIC_ISPR0 bit 27

   protected Handler
     with Interrupt_Priority => System.Interrupt_Priority'First
   is
   private
      procedure Serve with Attach_Handler => IRQ;
   end Handler;

   procedure Trigger_IRQ;

end Chains;
