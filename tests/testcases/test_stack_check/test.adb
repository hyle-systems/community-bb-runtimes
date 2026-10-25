--  S1: a task recurses under -fstack-check until the probe finds the frame below
--  the stack's limit: Storage_Error from System.BB.Threads.Stack_Checking into the
--  last-chance handler, no silent walk. The handler also prints whether the
--  check fired at a depth in band: a 16 KB stack, 4.4 KB of probe margin and
--  frames of about 280 bytes put it around the fortieth frame; a check that
--  fired on the first frame, or only at the real bottom, would print the
--  same two lines without the band.

with Ada.Text_IO;

with Digger; pragma Unreferenced (Digger);
with Test_LCH; pragma Unreferenced (Test_LCH);

procedure Test is
begin
   Ada.Text_IO.Put_Line ("main started");
   loop
      null;   --  the digger reports; main never prints the marker itself
   end loop;
end Test;
