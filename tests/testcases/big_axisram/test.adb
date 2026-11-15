--  Built only by test_negative_builds.py, which expects the link to be
--  refused: Axi_Table's 300 KB of initialised .axisram is more than the
--  65 535 words the start-up's copy loop can count (upstream's start-rom.S
--  loads the count with one movw), which would copy part of it silently.
--  Reading the table keeps it in the link; the program is never run.

with Ada.Text_IO;
with Interfaces; use Interfaces;

with Axi_Table;

procedure Test is
   Idx : Integer := Axi_Table.Table'Last with Volatile;
begin
   Ada.Text_IO.Put_Line ("table word:" & Unsigned_32'Image (Axi_Table.Table (Idx)));
   Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
end Test;
