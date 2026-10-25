with Ada.Text_IO;
with Interfaces; use Interfaces;
with System;
with System.Storage_Elements; use System.Storage_Elements;

package body Lazy_Probe is

   MPU_RNR  : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_ED98#);
   MPU_RBAR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_ED9C#);
   MPU_RASR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_EDA0#);

   Window_Top : Integer_Address := 0;

   function Window_End return Integer_Address is
      RBAR, RASR : Unsigned_32;
   begin
      MPU_RNR := 0;
      RBAR := MPU_RBAR;
      RASR := MPU_RASR;
      return Integer_Address (RBAR and not 16#1F#)
        + 2 ** (Natural (Shift_Right (RASR, 1) and 16#1F#) + 1);
   end Window_End;

   --  The deepest frame sits in [48, 48 + frame size) above the window: an
   --  exception frame's integer part (32 bytes) fits above it, its FP area
   --  (72 bytes below that) does not.
   procedure Dig (N : Natural; Prev : Integer_Address) with No_Inline;
   procedure Dig (N : Natural; Prev : Integer_Address) is
      Mark : Unsigned_32 with Volatile;
      Here : constant Integer_Address := To_Integer (Mark'Address);
      Step : constant Integer_Address := (if Prev = 0 then 0 else Prev - Here);
   begin
      Mark := Unsigned_32 (N);
      if N < 100_000 and then (Step = 0 or else Here - Step >= Window_Top + 48) then
         Dig (N + 1, Here);
      else
         Headroom := Here - Window_Top;
         declare
            Poke : Unsigned_32 with Volatile, Import, Address => To_Address (Window_Top - 4);
         begin
            Poke := 16#DEAD_0000#;   --  into the window: the fault
         end;
         Mark := 0;
      end if;
   end Dig;

   task body Digger is
   begin
      Value := 1.5;   --  the FPU in use: FPCA set from here on
      Window_Top := Window_End;
      Ada.Text_IO.Put_Line ("digging to just above the window with the FPU in use");
      Dig (1, 0);
      Ada.Text_IO.Put_Line ("the write landed");
   end Digger;

end Lazy_Probe;
