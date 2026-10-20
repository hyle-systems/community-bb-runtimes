--  Stack_Guard = true in a program with no tasking unit at all: is the
--  environment stack guarded? The guard is programmed by the tasking
--  runtime's CPU initialisation; a program that withs no tasking unit on
--  light-tasking never links or runs it, so the MPU stays off (MPU_CTRL = 0)
--  and the option protects nothing - found 2026-10-21 (finding 6), the
--  decision pending. On embedded the tasking runtime initialises for every
--  program and the guard is on (5).

with Ada.Text_IO;
with Interfaces; use Interfaces;
with System;

procedure Test is
   MPU_CTRL : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_ED94#);
begin
   Ada.Text_IO.Put_Line ("MPU_CTRL =" & Unsigned_32'Image (MPU_CTRL));
   Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
end Test;
