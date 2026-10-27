--  The asynchronous half of the FPU context test: a task holds live values
--  in all sixteen double registers inside one assembly loop, which checks
--  them on every round, while a higher task preempts it every millisecond
--  (the tick's alarm, then PendSV: the core stacks d0-d7 lazily into the
--  preempted task's frame, PendSV saves d8-d15) and blocks again with other
--  values live in d0-d15, and a timer interrupt every 100 microseconds lands on it with a
--  handler that uses the FPU and loads other values into d0-d7 (the core's
--  lazy stacking alone keeps the task's). The voluntary switches of the
--  chains never have a live caller-saved register at the switch; these do.

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
