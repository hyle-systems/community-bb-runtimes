--  How much of the fault stack embedded's fault path uses WITH A HANDLER THAT
--  ALLOCATES - the embedded default handler's pattern: the exception's name
--  and message through the secondary stack, concatenated, printed - before
--  it measures. test_fault_stack_use measures the path alone with a handler
--  of fixed buffers; this one measures what a user who keeps the default
--  handler, or writes an ordinary one, needs the fault stack to hold. The
--  secondary stack it uses is the interrupted task's, not the fault stack's;
--  the frames of the calls are the fault stack's.
--
--  The mechanism, as there: the fault trap
--  switches to the fault stack, and System.BB.Faults.Report's raise, the
--  unwinder and the last-chance handler run there. Main fills the whole
--  8 KB fault stack with a pattern (nothing runs on it before a fault),
--  reads an unmapped address, and the handler finds the lowest word the
--  path touched. The finding behind it: when the path still ran on the
--  interrupt stack, its default 1 KB with a 256-byte guard window at the
--  bottom overflowed into the window, faulted again inside the MemManage
--  handler and escalated to a hard fault; with the guard off the overflow
--  walked below the stack silently. The number printed is this
--  toolchain's (gnat_arm_elf 16.1.0); a change in it is worth a look.

with Ada.Text_IO;
with Interfaces; use Interfaces;
with System;
with System.Storage_Elements; use System.Storage_Elements;

with Test_LCH; pragma Unreferenced (Test_LCH);

procedure Test is
   Stack_Start : constant Character
     with Import, Convention => Asm, External_Name => "__fault_stack_start";
   Stack_End : constant Character
     with Import, Convention => Asm, External_Name => "__fault_stack_end";
   Nowhere : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#D000_0000#);
   Value : Unsigned_32;
   A : Integer_Address := To_Integer (Stack_Start'Address);
   Last : constant Integer_Address := To_Integer (Stack_End'Address);
begin
   while A < Last loop
      declare
         W : Unsigned_32 with Volatile, Import, Address => To_Address (A);
      begin
         W := 16#5AFE_5AFE#;
      end;
      A := A + 4;
   end loop;
   Ada.Text_IO.Put_Line ("fault stack filled; reading an unmapped address");
   Value := Nowhere;
   Ada.Text_IO.Put_Line ("the read returned" & Unsigned_32'Image (Value));
   Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
end Test;
