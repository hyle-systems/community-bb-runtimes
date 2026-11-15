--  Ada.Interrupts.Interrupt_ID must end at the part's last interrupt. RM0468
--  Table 140 numbers them 0 .. 162 (163 lines), so the last identifier is
--  162. One more would let Attach_Handler accept a line that does not exist
--  and write NVIC bits beyond the last.

with Ada.Interrupts;
with Ada.Text_IO;

procedure Test is
begin
   Ada.Text_IO.Put_Line
     ("last interrupt identifier:"
      & Integer'Image (Integer (Ada.Interrupts.Interrupt_ID'Last)));
   Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
end Test;
