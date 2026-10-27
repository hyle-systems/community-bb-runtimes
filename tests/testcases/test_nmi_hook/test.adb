--  An application's own NMI handler: the vector table's NMI entry is a
--  weak name the application can define (__gnat_nmi_trap); undefined, it is
--  the fault report (test_fault_nmi). The NMI is raised by software through
--  ICSR.NMIPENDSET (PM0253 4.3.3, 0xE000_ED04 bit 31); the handler counts
--  it and returns, and the program carries on.

with Ada.Text_IO;
with Interfaces; use Interfaces;
with System;
with System.Machine_Code; use System.Machine_Code;

with NMI;

procedure Test is
   ICSR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_ED04#);
begin
   Ada.Text_IO.Put_Line ("raising the NMI");
   ICSR := 2 ** 31;
   Asm ("dsb" & ASCII.LF & "isb", Volatile => True);
   Ada.Text_IO.Put_Line ("the application's handler ran once: " & Boolean'Image (NMI.Taken = 1));
   Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
end Test;
