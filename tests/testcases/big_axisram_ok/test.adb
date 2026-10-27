--  Built only by test_negative_builds.py.

with Ada.Text_IO;
with Interfaces; use Interfaces;

with Axi_Table;

procedure Test is
   Idx : Integer := Axi_Table.Table'Last with Volatile;
begin
   Ada.Text_IO.Put_Line ("table word:" & Unsigned_32'Image (Axi_Table.Table (Idx)));
   Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
end Test;
