--  A stale cause byte must not rename an unrelated fault: a reset after a
--  deliberate fault's report leaves System.BB.Faults.Cause set in the DTCM
--  (1, "task stack below four guard windows"). Set by hand here, it must
--  not stop a bus fault being reported as "bus fault".

with Interfaces; use Interfaces;
with System;
with Ada.Text_IO;

with Test_LCH; pragma Unreferenced (Test_LCH);

procedure Test is
   Cause   : Unsigned_8 with Volatile, Import, Convention => Asm,
     External_Name => "__gnat_fault_cause";
   Nowhere : Unsigned_32 with Volatile, Import,
     Address => System'To_Address (16#D000_0000#);
   Value   : Unsigned_32 with Volatile;
begin
   Cause := 1;
   Ada.Text_IO.Put_Line ("the cause byte set, then a bus fault");
   Value := Nowhere;
   Ada.Text_IO.Put_Line ("no fault: not expected");
end Test;
