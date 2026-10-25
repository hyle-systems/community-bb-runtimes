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
   Value      : Float := 0.0 with Volatile;
   Window_Top : Integer_Address := 0;

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

   --  One frame per level; the next level is taken only while it would stay
   --  at least 112 bytes above the window, so the deepest frame sits in
   --  [112, 112 + frame size) and the PendSV save (96 bytes below a 104-byte
   --  exception frame) crosses the window while the frame itself does not.
   procedure Dig (N : Natural; Prev : Integer_Address) with No_Inline;
   procedure Dig (N : Natural; Prev : Integer_Address) is
      Mark : Unsigned_32 with Volatile;
      Here : constant Integer_Address := To_Integer (Mark'Address);
      Step : constant Integer_Address := (if Prev = 0 then 0 else Prev - Here);
   begin
      Mark := Unsigned_32 (N);
      if N < 100_000 and then (Step = 0 or else Here - Step >= Window_Top + 112) then
         Dig (N + 1, Here);
      else
         Headroom := Here - Window_Top;
         Go := True;
         loop
            exit when Mark = 0;   --  never: spin until Waker takes the processor
         end loop;
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
