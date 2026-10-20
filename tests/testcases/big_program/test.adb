--  A program larger than the 128 KB flash map. Built only by
--  test_negative_builds.py: against the 128 KB map the link must fail with
--  a region overflow, against the default map it must link.

with Ada.Text_IO;
with Interfaces; use Interfaces;

with Big_Table;

procedure Test is
   Idx : Integer := Big_Table.Table'Last with Volatile;
begin
   Ada.Text_IO.Put_Line ("table word:" & Unsigned_32'Image (Big_Table.Table (Idx)));
   Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
end Test;
