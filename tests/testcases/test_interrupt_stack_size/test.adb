--  Interrupt_Stack_Size = 8192 (opt.py) must be the size the linker gives
--  the interrupt stack. The stack exists only when the interrupt support is
--  linked, so a handler is attached (and pended once, to use it).

with Ada.Text_IO;
with Interfaces; use Interfaces;
with System.Storage_Elements; use System.Storage_Elements;

with Probes;

procedure Test is
   Interrupt_Stack_Start : constant Character
     with Import, Convention => Asm, External_Name => "__interrupt_stack_start";
   Interrupt_Stack_End : constant Character
     with Import, Convention => Asm, External_Name => "__interrupt_stack_end";
   Size : constant Integer_Address :=
     To_Integer (Interrupt_Stack_End'Address) - To_Integer (Interrupt_Stack_Start'Address);
begin
   Probes.Trigger_IRQ;
   Ada.Text_IO.Put_Line
     ("interrupt stack size =" & Integer_Address'Image (Size)
      & " (handler served " & Boolean'Image (Probes.Handler_SP /= 1) & ")");
   Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
end Test;
