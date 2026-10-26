with Ada.Interrupts.Names;
with Ada.Real_Time; use Ada.Real_Time;
with Ada.Text_IO;
with Interfaces; use Interfaces;
with System;
with System.Machine_Code; use System.Machine_Code;
with System.Storage_Elements; use System.Storage_Elements;

package body Switch_Probe is

   MPU_RNR  : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_ED98#);
   MPU_RBAR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_ED9C#);
   MPU_RASR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_EDA0#);

   Go         : Boolean := False with Volatile;
   Stop_At    : Time := Time_First with Volatile;
   --  The storm lasts until Stop_At on the runtime's clock, longer than
   --  Waker's period, so an alarm falls inside it whatever an entry costs.
   Value      : Float := 0.0 with Volatile;
   Window_Top : Integer_Address := 0;

   NVIC_ISPR0 : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_E200#);
   TIM1_CC_Bit : constant Unsigned_32 :=
     Shift_Left (1, Natural (Ada.Interrupts.Names.TIM1_CC_Interrupt));

   protected body Storm is
      procedure IRQ_Handler is
      begin
         Storm_Entries := Storm_Entries + 1;
         if Clock < Stop_At then
            NVIC_ISPR0 := TIM1_CC_Bit;   --  back to back, until the time is up
         end if;
      end IRQ_Handler;
   end Storm;

   --  The running task's window is in region 0 or 3 (the runtime alternates
   --  them across context switches): the enabled one whose base is below
   --  the stack pointer and nearest to it.
   function Window_End return Integer_Address is
      SP   : Unsigned_32;
      Best : Integer_Address := 0;
   begin
      Asm ("mov %0, sp", Outputs => Unsigned_32'Asm_Output ("=r", SP), Volatile => True);
      for Region in Unsigned_32'(0) .. 3 loop
         if Region = 0 or else Region = 3 then
            MPU_RNR := Region;
            declare
               RBAR : constant Unsigned_32 := MPU_RBAR;
               RASR : constant Unsigned_32 := MPU_RASR;
               Base : constant Integer_Address := Integer_Address (RBAR and not 16#1F#);
               Size : constant Integer_Address := 2 ** (Natural (Shift_Right (RASR, 1) and 16#1F#) + 1);
            begin
               if (RASR and 1) = 1 and then Base <= Integer_Address (SP) and then Base > Best then
                  Best := Base + Size;   --  the window's end
               end if;
            end;
         end if;
      end loop;
      return Best;
   end Window_End;

   --  The exact placement, instead of test_guard_switch's band: a stack
   --  array sized so that the stack pointer inside the block sits Target
   --  bytes above the window. An exception entry's frame (104 bytes with
   --  the FPU in use) then fits above the window with 32 bytes to spare,
   --  and the PendSV save of s16-s31, 64 bytes below that frame, crosses it.
   --  Nothing is called inside the block: a call's frames would reach the
   --  window first. The storm starts here and the task spins.
   Target : constant := 136;

   procedure Park_And_Storm with No_Inline;
   procedure Park_And_Storm is
      SP : Integer_Address;
   begin
      Stop_At := Clock + Milliseconds (25);   --  before the placement: a call
      Asm ("mov %0, sp", Outputs => Integer_Address'Asm_Output ("=r", SP), Volatile => True);
      declare
         Gap : constant Integer_Address := SP - (Window_Top + Target);
         Pad : array (1 .. Natural (Gap)) of Unsigned_8 with Volatile;
         Now : Integer_Address;
      begin
         Pad (Pad'First) := 1;
         Pad (Pad'Last)  := 2;
         Asm ("mov %0, sp", Outputs => Integer_Address'Asm_Output ("=r", Now), Volatile => True);
         Headroom := Now - Window_Top;
         Go := True;
         NVIC_ISPR0 := TIM1_CC_Bit;     --  the storm's first entry
         loop
            exit when Pad (Pad'First) = 0;   --  never: spin until Waker takes the processor
         end loop;
      end;
   end Park_And_Storm;

   --  One frame per level, down to 512 bytes above the window, where
   --  Park_And_Storm takes over with the exact placement. The recursion
   --  keeps the frames plain so that nothing below Park_And_Storm's frame
   --  depends on the compiler's layout.
   procedure Dig (N : Natural; Prev : Integer_Address) with No_Inline;
   procedure Dig (N : Natural; Prev : Integer_Address) is
      Mark : Unsigned_32 with Volatile;
      Here : constant Integer_Address := To_Integer (Mark'Address);
      Step : constant Integer_Address := (if Prev = 0 then 0 else Prev - Here);
   begin
      Mark := Unsigned_32 (N);
      if N < 100_000 and then (Step = 0 or else Here - Step >= Window_Top + 512) then
         Dig (N + 1, Here);
      else
         Ada.Text_IO.Put_Line ("storm started");   --  before the placement: Put_Line's frames need room
         Park_And_Storm;
      end if;
   end Dig;

   task body Digger is
   begin
      Value := Float (Window_End mod 7) * 1.5;   --  the FPU in use: FPCA set from here on
      Window_Top := Window_End;
      Ada.Text_IO.Put_Line ("digging towards the window with the FPU in use");
      Dig (1, 0);
   end Digger;

   task body Waker is
      Next : Time := Clock;
   begin
      loop
         Next := Next + Milliseconds (20);
         delay until Next;
         if Go then
            Ada.Text_IO.Put_Line ("waker ran");
            Go := False;
         end if;
      end loop;
   end Waker;

end Switch_Probe;
