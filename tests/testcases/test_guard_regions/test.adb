--  Stack_Guard = true, Stack_Guard_Bytes = 256: the MPU is on with the
--  background map (ENABLE + PRIVDEFENA = 5), and each guard region's base
--  lies in the documented window above the bottom of the stack it guards.

with Ada.Synchronous_Task_Control;
with Ada.Text_IO;
with Interfaces; use Interfaces;
with System;

with Guard_Probe;

procedure Test is
   MPU_CTRL : Unsigned_32 with Volatile, Import,
     Address => System'To_Address (16#E000_ED94#);

   --  The linker's symbols for the two stacks the runtime guards besides the
   --  tasks': the object's address is the symbol's value.
   Interrupt_Stack_Start : constant Character
     with Import, Convention => Asm, External_Name => "__interrupt_stack_start";
   Environment_Stack_Start : constant Character
     with Import, Convention => Asm, External_Name => "__stack_start";
begin
   Ada.Text_IO.Put_Line ("MPU_CTRL =" & Unsigned_32'Image (MPU_CTRL));
   Guard_Probe.Report (1, "interrupt stack", Interrupt_Stack_Start'Address, Exact => True);
   Guard_Probe.Report (2, "environment stack", Environment_Stack_Start'Address, Exact => True);
   Ada.Synchronous_Task_Control.Suspend_Until_True (Guard_Probe.Task_Done);
   Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
end Test;
