--  The cause byte must name only the undefined instruction it was set for:
--  __gnat_stack_below_windows and __gnat_guard_not_armed store the cause,
--  then execute UDF, and an interrupt taken between the two that raises a
--  usage fault of its own must be reported as that fault. The test stands
--  in for that interrupt: it sets the cause by hand (1, "task stack below
--  four guard windows"), then divides by zero with CCR.DIV_0_TRP set.

with Ada.Text_IO;
with Interfaces; use Interfaces;
with System;
with System.Machine_Code; use System.Machine_Code;

with Test_LCH; pragma Unreferenced (Test_LCH);

procedure Test is
   Cause : Unsigned_8 with Volatile, Import, Convention => Asm,
     External_Name => "__gnat_fault_cause";
   CCR   : Unsigned_32 with Volatile, Import,
     Address => System'To_Address (16#E000_ED14#);
begin
   CCR := CCR or 2 ** 4;   --  DIV_0_TRP
   Ada.Text_IO.Put_Line ("the cause byte set, then a division by zero");
   Cause := 1;
   Asm ("movs r0, #1" & ASCII.LF & ASCII.HT
        & "movs r1, #0" & ASCII.LF & ASCII.HT
        & "udiv r0, r0, r1",
        Volatile => True, Clobber => "r0,r1");
   Ada.Text_IO.Put_Line ("no fault: not expected");
end Test;
