--  Z8 of the fourth review: a task whose stack is smaller than four guard
--  windows. The window's base is rounded up to the window's alignment; in a
--  stack this small the window would lie over whatever follows the stack,
--  and the fault would come from a neighbour, some time, instead of from
--  this task. The runtime must report it at the offender, at the first
--  switch to the task, which happens at its activation - before the main
--  procedure runs.

with Test_LCH; pragma Unreferenced (Test_LCH);
with Small;    pragma Unreferenced (Small);

procedure Test is
   pragma Priority (50);
begin
   loop
      null;
   end loop;
end Test;
