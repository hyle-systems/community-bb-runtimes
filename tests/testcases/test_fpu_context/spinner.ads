--  The asynchronous half of the FPU context test (test.adb).

with Ada.Interrupts.Names;
with Ada.Synchronous_Task_Control;
with Interfaces;
with System;

package Spinner is

   --  One suspension object per waiter (Ravenscar: one task queued at most)
   Go_Spin, Go_Poke, Done : Ada.Synchronous_Task_Control.Suspension_Object;

   Rounds_Failed : Interfaces.Unsigned_32 := 0 with Volatile;
   Preemptions   : Interfaces.Unsigned_32 := 0 with Volatile;
   Interrupts    : Interfaces.Unsigned_32 := 0 with Volatile;
   Finished      : Boolean := False with Volatile;

   --  Spin checks its values in d0-d15 on every round of one assembly loop.
   --  Poke preempts it every millisecond (the tick's alarm, then PendSV:
   --  the core stacks d0-d7 lazily into Spin's frame and PendSV saves
   --  d8-d15) and blocks again with other values live in d0-d15. Every
   --  100 microseconds TIM2 lands on Spin with a handler that uses the FPU
   --  and loads other values into d0-d7, so only the core's lazy stacking
   --  keeps Spin's. Unlike the chains' voluntary switches, these find live
   --  caller-saved registers.
   task Spin with Priority => System.Default_Priority, Storage_Size => 4096;
   task Poke with Priority => System.Default_Priority + 3, Storage_Size => 4096;

   protected Timer
     with Interrupt_Priority => System.Interrupt_Priority'First + 1
   is
   private
      procedure Serve with Attach_Handler => Ada.Interrupts.Names.TIM2_Interrupt;
   end Timer;

   procedure Start_Timer;
   procedure Stop_Timer;

end Spinner;
