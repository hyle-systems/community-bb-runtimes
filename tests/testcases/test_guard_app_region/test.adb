--  An application that uses the MPU itself, in the regions the runtime
--  leaves it: region 11 programmed over the whole DTCM, read-write for
--  everyone (a typical attribute or hardening region). The guard's windows
--  lie inside the DTCM, so the two overlap, and PM0253 4.6 says "When memory
--  regions overlap, a memory access is affected by the attributes of the
--  region with the highest number": the guard must sit above every region
--  an application is offered, or the application's region silently disarms
--  it. A store into the environment stack's window must still be a memory
--  management fault.
--  MPU registers (PM0253 4.6): RNR 0xE000_ED98, RBAR 0xE000_ED9C, RASR
--  0xE000_EDA0; RASR = XN | AP 011 (full access) | TEX 001 C 1 B 1 (normal,
--  write-back) | SIZE 16 (128 KB) | ENABLE.

with Ada.Text_IO;
with Interfaces; use Interfaces;
with System;
with System.Machine_Code; use System.Machine_Code;

with Test_LCH; pragma Unreferenced (Test_LCH);

procedure Test is
   MPU_RNR  : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_ED98#);
   MPU_RBAR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_ED9C#);
   MPU_RASR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_EDA0#);
   Window : Unsigned_32 with Volatile, Import, Convention => Asm, External_Name => "__stack_start";
begin
   MPU_RNR  := 11;
   MPU_RASR := 0;
   MPU_RBAR := 16#2000_0000#;
   MPU_RASR := 16#1000_0000# or 16#0300_0000# or 16#000B_0000# or 16 * 2 or 1;
   Asm ("dsb" & ASCII.LF & "isb", Volatile => True);
   Ada.Text_IO.Put_Line ("region 11 over the DTCM; writing into the environment stack's guard window");
   Window := 16#DEAD_0000#;
   Ada.Text_IO.Put_Line ("the write landed");
   Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
end Test;
