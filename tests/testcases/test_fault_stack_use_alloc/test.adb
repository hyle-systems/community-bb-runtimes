--  test_fault_stack_use's measurement WITH A HANDLER THAT ALLOCATES, as the
--  default one does: before it measures, it builds the exception's name
--  and message on the secondary stack and prints them. This is what a
--  program that keeps the default handler, or writes an ordinary one, needs
--  the fault stack to hold. The secondary stack is the interrupted task's;
--  the calls' frames are on the fault stack. The figure is this
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
