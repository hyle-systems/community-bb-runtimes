--  How much of the interrupt stack embedded's fault path uses: the fault
--  handler, System.BB.Faults.Report's raise, the unwinder and the
--  last-chance handler all run in handler mode on the interrupt stack. Main
--  fills the lower 7 KB of an 8 KB interrupt stack with a pattern (the top
--  kilobyte left alone), reads an unmapped address, and the handler finds
--  the lowest word the path touched. Finding 7 (2026-10-21): with the
--  default 1 KB and a 256-byte guard window at its bottom the path
--  overflowed into the window, faulted again inside the MemManage handler
--  and escalated to a hard fault; with the guard off the overflow walks
--  below the stack silently. The number printed is this toolchain's
--  (gnat_arm_elf 16.1.0); a change in it is worth a look.

with Ada.Text_IO;
with Interfaces; use Interfaces;
with System;
with System.Storage_Elements; use System.Storage_Elements;

with Test_LCH; pragma Unreferenced (Test_LCH);

procedure Test is
   Stack_Start : constant Character
     with Import, Convention => Asm, External_Name => "__interrupt_stack_start";
   Stack_End : constant Character
     with Import, Convention => Asm, External_Name => "__interrupt_stack_end";
   Nowhere : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#D000_0000#);
   Value : Unsigned_32;
   A : Integer_Address := To_Integer (Stack_Start'Address);
   Last : constant Integer_Address := To_Integer (Stack_End'Address) - 1024;
begin
   while A < Last loop
      declare
         W : Unsigned_32 with Volatile, Import, Address => To_Address (A);
      begin
         W := 16#5AFE_5AFE#;
      end;
      A := A + 4;
   end loop;
   Ada.Text_IO.Put_Line ("interrupt stack filled; reading an unmapped address");
   Value := Nowhere;
   Ada.Text_IO.Put_Line ("the read returned" & Unsigned_32'Image (Value));
   Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
end Test;
