--  A task whose stack is smaller than four guard windows. The window's base
--  is rounded up to its alignment, so in a stack this small it can lie over
--  whatever follows, and a neighbour would fault later instead of this
--  task. The runtime must report the offender at its first switch, its
--  activation, before the main procedure runs, and in the fault path's
--  context, which the handler prints.

with Test_LCH; pragma Unreferenced (Test_LCH);
with Small;    pragma Unreferenced (Small);

procedure Test is
   pragma Priority (50);
begin
   loop
      null;
   end loop;
end Test;
