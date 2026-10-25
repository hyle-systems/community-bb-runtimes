--  S2: a 4 KB task under -fstack-check fails at its first checked frame - the probe
--  asks for about 4.4 KB of room below every frame on this target, so every stack
--  a checked frame runs on must hold its peak use plus that margin (the sizing rule).
--  The handler prints that the big frame never ran (its body sets Depth): a check
--  that let it run and fired later would print the same first two lines.

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
