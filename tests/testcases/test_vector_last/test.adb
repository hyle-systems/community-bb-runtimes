--  The table's last vector is reachable: a handler attached to interrupt
--  162 (TIM24) runs when that interrupt is pended.

with Ada.Text_IO;

with Last_Vector;

procedure Test is
begin
   Ada.Text_IO.Put_Line ("pending interrupt 162");
   Last_Vector.Trigger_IRQ;
   Ada.Text_IO.Put_Line ("back in main");
   Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
end Test;
