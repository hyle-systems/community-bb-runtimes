--  With Stack_Guard = false the runtime must not touch the MPU: control
--  register at its reset value, regions 0 to 3 disabled.

with Ada.Text_IO;
with Interfaces; use Interfaces;
with System;

with Resident; pragma Unreferenced (Resident);

procedure Test is
   MPU_CTRL : Unsigned_32 with Volatile, Import,
     Address => System'To_Address (16#E000_ED94#);
   MPU_RNR  : Unsigned_32 with Volatile, Import,
     Address => System'To_Address (16#E000_ED98#);
   MPU_RASR : Unsigned_32 with Volatile, Import,
     Address => System'To_Address (16#E000_EDA0#);
begin
   Ada.Text_IO.Put_Line ("MPU_CTRL =" & Unsigned_32'Image (MPU_CTRL));
   for Region in Unsigned_32 range 0 .. 3 loop
      MPU_RNR := Region;
      Ada.Text_IO.Put_Line
        ("region" & Unsigned_32'Image (Region) & " enabled: "
         & Boolean'Image ((MPU_RASR and 1) = 1));
   end loop;
   Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
end Test;
