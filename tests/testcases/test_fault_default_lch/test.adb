--  The embedded profile's default last-chance handler (a-elchha.adb), run
--  on the fault stack after a bus fault: it prints the exception's name and
--  message through the secondary stack, then resets through
--  System.Machine_Reset.Stop. The second run finds its mark in SRAM4 with
--  RCC_RSR SFTRSTF set and parks. There is no completion marker: the
--  harness compares the whole output at its read deadline, as for
--  test_fault_in_fault.

with Ada.Text_IO;
with Interfaces; use Interfaces;
with System;
with System.Machine_Code; use System.Machine_Code;
with System.Storage_Elements; use System.Storage_Elements;

with Restart_Mark;

procedure Test is
   Magic : constant Unsigned_32 := 16#5245_5354#;   --  "REST"
   DCCMVAC : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_EF68#);
   RCC_RSR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#5802_44D0#);
   --  RCC_RSR's flag for a system reset the CPU requested (RM0468)
   SFTRSTF : constant Unsigned_32 := 2 ** 24;
   Bad : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#D000_0000#);
   X : Unsigned_32 with Volatile;

   procedure Set (Value : Unsigned_32) is
   begin
      Restart_Mark.Word := Value;
      --  Clean the line to memory: the reset empties the cache
      DCCMVAC := Unsigned_32 (To_Integer (Restart_Mark.Word'Address));
      Asm ("dsb" & ASCII.LF & ASCII.HT & "isb", Volatile => True);
   end Set;
begin
   --  A mark without SFTRSTF is stale (a run died after marking, then the
   --  harness's pin reset), and this run starts afresh rather than fail.
   if Restart_Mark.Word = Magic and then (RCC_RSR and SFTRSTF) /= 0 then
      Set (0);
      Ada.Text_IO.Put_Line ("restarted after the fault: TRUE");
      loop
         null;
      end loop;
   else
      --  RMVF clears the reset flags: those set from here on are this run's
      RCC_RSR := RCC_RSR or 2 ** 16;
      Set (Magic);
      --  In test.out the handler's lines end in LF (System.IO) and ours in
      --  CRLF (Ada.Text_IO). The message carries the raising unit's name, as
      --  the embedded runtime forms it. The traceback line is empty because
      --  the binder's traceback switch is not set for the test programs.
      Ada.Text_IO.Put_Line ("faulting with the default last-chance handler on the fault stack");
      X := Bad;
      Ada.Text_IO.Put_Line ("not reached");
   end if;
end Test;
