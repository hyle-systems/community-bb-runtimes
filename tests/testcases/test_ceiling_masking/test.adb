--  Ceiling locking against the interrupts: see Probes.

with Ada.Text_IO;

with Probes; use Probes;

procedure Test is
   Inside : Seen;
begin
   Guarded.Pend_All_And_Look (Inside);
   Ada.Text_IO.Put_Line
     ("inside the action: the interrupt above the ceiling ran " & Boolean'Image (Inside.Above = 1)
      & ", the one at the ceiling waited " & Boolean'Image (Inside.At_Ceiling = 0)
      & ", the one below waited " & Boolean'Image (Inside.Below = 0));
   Ada.Text_IO.Put_Line
     ("after the action: each ran once "
      & Boolean'Image (Below_N = 1 and then At_Ceiling_N = 1 and then Above_N = 1));
   Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
end Test;
