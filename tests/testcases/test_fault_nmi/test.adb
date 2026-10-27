--  The NMI with no handler of the application's: the vector's weak name
--  falls back to the fault trap, and the NMI is reported like a fault
--  (Program_Error "non-maskable interrupt") into the last-chance handler.
--  Raised by software through ICSR.NMIPENDSET (PM0253 4.3.3).

with Ada.Text_IO;
with Interfaces; use Interfaces;
with System;
with System.Machine_Code; use System.Machine_Code;

with Test_LCH; pragma Unreferenced (Test_LCH);

procedure Test is
   ICSR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_ED04#);
begin
   Ada.Text_IO.Put_Line ("raising the NMI");
   ICSR := 2 ** 31;
   Asm ("dsb" & ASCII.LF & "isb", Volatile => True);
   Ada.Text_IO.Put_Line ("the NMI returned");
   Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
end Test;
