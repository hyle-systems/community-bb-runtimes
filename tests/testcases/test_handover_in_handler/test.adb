--  An image entered from inside an exception handler: the test's NMI handler
--  branches to the reset entry, as a bootloader that starts the application
--  from its own handler would. The start-up must not run the program in
--  handler mode, where no PendSV, SVC or SysTick could preempt it; it parks
--  at __gnat_handover_in_handler. Expected: the first line once, then nothing
--  (no completion marker: the harness compares what arrived when its read
--  timed out), and the runner finds the core in the NMI's handler mode. A
--  start-up that runs on prints the first line again.

with Ada.Text_IO;
with Interfaces; use Interfaces;
with System;
with System.Machine_Code; use System.Machine_Code;

with NMI; pragma Unreferenced (NMI);

procedure Test is
   ICSR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_ED04#);
begin
   Ada.Text_IO.Put_Line ("entering the image again from an NMI handler");
   ICSR := 2 ** 31;   --  NMIPENDSET
   Asm ("dsb" & ASCII.LF & "isb", Volatile => True);
   Ada.Text_IO.Put_Line ("returned from the NMI: not expected");
end Test;
