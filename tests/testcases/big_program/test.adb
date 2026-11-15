--  Built only by test_negative_builds.py: Big_Table's 192 KB of constants,
--  which the program reads so that the linker keeps them, must overflow the
--  128 KB flash map at the link and link against the default map (they fit
--  the 512 KB and 1 MB maps too).

with Ada.Text_IO;
with Interfaces; use Interfaces;

with Big_Table;

procedure Test is
   Idx : Integer := Big_Table.Table'Last with Volatile;
begin
   Ada.Text_IO.Put_Line ("table word:" & Unsigned_32'Image (Big_Table.Table (Idx)));
   Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
end Test;
