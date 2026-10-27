--  Three interrupts at three Ada priorities around a protected object's
--  ceiling, and the object: inside its action, an interrupt above the
--  ceiling must run at once, one at the ceiling and one below it must wait
--  until the action ends (ceiling locking, RM D.3; on this core BASEPRI
--  set from the ceiling, PM0253 2.1.3, with 4 priority bits). TIM3 (IRQ
--  29), TIM4 (30) and TIM5 (50), pended by software; the timers do not run.

with Ada.Interrupts.Names;
with System;

package Probes is

   Ceiling : constant System.Interrupt_Priority := System.Interrupt_Priority'First + 5;

   --  Counted by the handlers; read without a protected call, since reading
   --  through an object of a lower ceiling from inside the guarded action
   --  would itself break ceiling locking
   Below_N, At_Ceiling_N, Above_N : Natural := 0 with Atomic;

   protected Below with Interrupt_Priority => Ceiling - 4 is
   private
      procedure Handler with Attach_Handler => Ada.Interrupts.Names.TIM3_Interrupt;
   end Below;

   protected At_Ceiling with Interrupt_Priority => Ceiling is
   private
      procedure Handler with Attach_Handler => Ada.Interrupts.Names.TIM4_Interrupt;
   end At_Ceiling;

   protected Above with Interrupt_Priority => Ceiling + 1 is
   private
      procedure Handler with Attach_Handler => Ada.Interrupts.Names.TIM5_Interrupt;
   end Above;

   type Seen is record
      Below, At_Ceiling, Above : Natural := 0;
   end record;

   protected Guarded with Interrupt_Priority => Ceiling is
      procedure Pend_All_And_Look (Inside : out Seen);
   end Guarded;

end Probes;
