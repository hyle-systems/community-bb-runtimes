--  Built only by test_negative_builds.py, as big_axisram's positive control:
--  Axi_Table's 200 KB of initialised .axisram is within the start-up's copy
--  count, so it must link against the default flash map; against the 128 KB
--  map it must be refused, since its initial values exceed the flash.

with Ada.Text_IO;
with Interfaces; use Interfaces;

with Axi_Table;

procedure Test is
   Idx : Integer := Axi_Table.Table'Last with Volatile;
begin
   Ada.Text_IO.Put_Line ("table word:" & Unsigned_32'Image (Axi_Table.Table (Idx)));
   Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
end Test;
