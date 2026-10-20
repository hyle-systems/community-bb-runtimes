--  AAPCS: the stack pointer is a multiple of 8 at every public interface.
--  Read in the main program (the environment task's stack, which the
--  runtime set up), in a task (its initial stack pointer, the runtime's),
--  and in an interrupt handler (exception entry on the interrupt stack).

with Ada.Synchronous_Task_Control;
with Ada.Text_IO;
with Interfaces; use Interfaces;

with Probes;

procedure Test is
   Main_SP : constant Unsigned_32 := Probes.Current_SP;
begin
   Ada.Text_IO.Put_Line ("main SP mod 8 =" & Unsigned_32'Image (Main_SP mod 8));
   Probes.Trigger_IRQ;
   Ada.Text_IO.Put_Line
     ("handler SP mod 8 =" & Unsigned_32'Image (Probes.Handler_SP mod 8)
      & " (served " & Boolean'Image (Probes.Handler_SP /= 1) & ")");
   Ada.Synchronous_Task_Control.Suspend_Until_True (Probes.Task_Done);
   Ada.Text_IO.Put_Line
     ("task SP mod 8 =" & Unsigned_32'Image (Probes.Task_SP mod 8)
      & " (ran " & Boolean'Image (Probes.Task_SP /= 1) & ")");
   Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
end Test;
