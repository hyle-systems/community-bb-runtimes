--  Built only by test_negative_builds.py.

with Ada.Text_IO;
with Interfaces; use Interfaces;

with Axi_Buffer;

procedure Test is
   Idx : Integer := Axi_Buffer.Buffer'Last with Volatile;
begin
   Ada.Text_IO.Put_Line ("buffer word:" & Unsigned_32'Image (Axi_Buffer.Buffer (Idx)));
   Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
end Test;
