--  Ada.Interrupts.Interrupt_ID against the part's interrupts: the STM32G4
--  devices' interrupt lines end at 101, so the last identifier is 101. One
--  more would let Attach_Handler accept a line that does not exist.

with Ada.Interrupts;
with Ada.Text_IO;

procedure Test is
begin
   Ada.Text_IO.Put_Line
     ("last interrupt identifier:"
      & Integer'Image (Integer (Ada.Interrupts.Interrupt_ID'Last)));
   Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
end Test;
