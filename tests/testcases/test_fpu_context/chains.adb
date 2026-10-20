with Ada.Real_Time; use Ada.Real_Time;
with System.Machine_Code; use System.Machine_Code;

package body Chains is

   use Interfaces;

   NVIC_ISPR0 : Unsigned_32 with Volatile, Import,
     Address => System'To_Address (16#E000_E200#);
   NVIC_ICPR0 : Unsigned_32 with Volatile, Import,
     Address => System'To_Address (16#E000_E280#);
   IRQ_Mask : constant Unsigned_32 := Shift_Left (1, Natural (IRQ));

   --  Chain A: x <- x * 1.000001 + 0.5 from 1.0; chain B: x <- x / 1.000002 + 0.25
   --  from 2.0. Each step keeps several doubles live across a delay, so a
   --  switch must preserve d0-d15 (caller) and d16-d31 (callee-saved).

   function Step_A (X : Long_Float) return Long_Float is (X * 1.000001 + 0.5);
   function Step_B (X : Long_Float) return Long_Float is (X / 1.000002 + 0.25);

   function Expected_A return Long_Float is
      X : Long_Float := 1.0;
   begin
      for I in 1 .. Steps loop
         X := Step_A (X);
      end loop;
      return X;
   end Expected_A;

   function Expected_B return Long_Float is
      X : Long_Float := 2.0;
   begin
      for I in 1 .. Steps loop
         X := Step_B (X);
      end loop;
      return X;
   end Expected_B;

   task body Chain_A is
      X : Long_Float := 1.0;
      Y : Long_Float := 3.0;   -- a second live double, checked at the end
      Next : Time := Clock;
   begin
      for I in 1 .. Steps loop
         X := Step_A (X);
         Y := Y * 1.0;
         Next := Next + Milliseconds (1);
         delay until Next;
      end loop;
      Result_A := (Value => (if Y = 3.0 then X else -1.0), Done => True);
      Ada.Synchronous_Task_Control.Set_True (Done_A);
   end Chain_A;

   task body Chain_B is
      X : Long_Float := 2.0;
      Y : Long_Float := 7.0;
      Next : Time := Clock;
   begin
      for I in 1 .. Steps loop
         X := Step_B (X);
         Y := Y * 1.0;
         Next := Next + Milliseconds (1);
         delay until Next;
      end loop;
      Result_B := (Value => (if Y = 7.0 then X else -1.0), Done => True);
      Ada.Synchronous_Task_Control.Set_True (Done_B);
   end Chain_B;

   protected body Handler is
      procedure Serve is
      begin
         NVIC_ICPR0 := IRQ_Mask;
         Handler_Sum := Handler_Sum + 0.125;   -- the FPU inside the handler
         Handler_Count := Handler_Count + 1;
      end Serve;
   end Handler;

   procedure Trigger_IRQ is
   begin
      NVIC_ISPR0 := IRQ_Mask;
      Asm ("dsb" & ASCII.LF & "isb", Volatile => True);
   end Trigger_IRQ;

end Chains;
