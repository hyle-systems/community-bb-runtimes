--  A load from an address no memory or peripheral answers is a precise bus
--  fault. The family routes it to the last-chance handler as "bus fault";
--  the generator's default parks the core in a silent loop.

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
