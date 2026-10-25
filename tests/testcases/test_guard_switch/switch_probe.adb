with Ada.Real_Time; use Ada.Real_Time;
with Ada.Text_IO;
with Interfaces; use Interfaces;
with System;
with System.Storage_Elements; use System.Storage_Elements;

package body Switch_Probe is

   MPU_RNR  : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_ED98#);
   MPU_RBAR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_ED9C#);
   MPU_RASR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_EDA0#);

   Go         : Boolean := False with Volatile;
   Value      : Float := 0.0 with Volatile;
   Window_Top : Integer_Address := 0;

   --  Region 0 is the running task's window: its end from the MPU
   --  (RASR SIZE field: a region of 2 ** (SIZE + 1) bytes).
   function Window_End return Integer_Address is
      RBAR, RASR : Unsigned_32;
   begin
      MPU_RNR := 0;
      RBAR := MPU_RBAR;
      RASR := MPU_RASR;
      return Integer_Address (RBAR and not 16#1F#)
        + 2 ** (Natural (Shift_Right (RASR, 1) and 16#1F#) + 1);
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
