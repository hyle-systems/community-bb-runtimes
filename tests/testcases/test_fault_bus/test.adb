--  A precise bus fault, a read of 0xD000_0000 that no memory or peripheral
--  answers, must reach the last-chance handler as "bus fault" with its
--  fault status kept (PRECISERR, BFARVALID, BFAR); the generator's default
--  handler would park the core in a silent loop.

with Ada.Text_IO;
with Interfaces; use Interfaces;
with System;

with Test_LCH; pragma Unreferenced (Test_LCH);

procedure Test is
   Nowhere : Unsigned_32 with Volatile, Import,
     Address => System'To_Address (16#D000_0000#);
   Value : Unsigned_32;
begin
   Ada.Text_IO.Put_Line ("reading an unmapped address");
   Value := Nowhere;
   Ada.Text_IO.Put_Line ("the read returned" & Unsigned_32'Image (Value));
   Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
end Test;
