--  Z13 of the fourth review: the embedded profile's default last-chance
--  handler (a-elchha.adb: the exception's name and message through the
--  secondary stack, then System.Machine_Reset.Stop) running on the fault
--  stack after a bus fault, with no handler of the test's own. Expected:
--  the handler's text, then the reset it performs - the program runs
--  again, finds its mark in SRAM4 (kept across a system reset, never zeroed
--  by the start-up) and reports the restart, then parks. No completion
--  marker: the harness compares the whole output at its read deadline, as
--  for test_fault_in_fault. The traceback line is empty: the binder's
--  traceback switch is not set for the test programs.

with Ada.Text_IO;
with Interfaces; use Interfaces;
with System;
with System.Machine_Code; use System.Machine_Code;
with System.Storage_Elements; use System.Storage_Elements;

with Restart_Mark;

procedure Test is
   Magic : constant Unsigned_32 := 16#5245_5354#;   --  "REST"
   DCCMVAC : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_EF68#);
   Bad : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#D000_0000#);
   X : Unsigned_32 with Volatile;

   procedure Set (Value : Unsigned_32) is
   begin
      Restart_Mark.Word := Value;
      DCCMVAC := Unsigned_32 (To_Integer (Restart_Mark.Word'Address));   --  through to memory: the reset empties the cache
      Asm ("dsb" & ASCII.LF & ASCII.HT & "isb", Volatile => True);
   end Set;
begin
   if Restart_Mark.Word = Magic then
      Set (0);
      Ada.Text_IO.Put_Line ("restarted after the fault: TRUE");
      loop
         null;
      end loop;
   else
      Set (Magic);
      Ada.Text_IO.Put_Line ("faulting with the default last-chance handler on the fault stack");
      X := Bad;
      Ada.Text_IO.Put_Line ("not reached");
   end if;
end Test;
