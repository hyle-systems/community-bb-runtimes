--  The largest window, 512 bytes, against the runtime's own idle task. Its
--  2 KB stack, aligned to 8, keeps at least 1 032 bytes above a 512-byte
--  window wherever the linker puts it; a 1 KB window could leave eight.
--  Every task blocks, fifty times, so the idle task runs under the guard
--  between the blocks. A pass prints "idle survived"; an idle task that
--  reached its window would fault before that line. The last line shows
--  that the guard was really on: the MPU enabled, and both task regions
--  (12 and 15) holding a 512-byte window that the switches programmed.

with Ada.Real_Time; use Ada.Real_Time;
with Ada.Text_IO;
with Interfaces; use Interfaces;
with System;

with Idle_Probe;

procedure Test is
   pragma Priority (50);
   Next : Time := Clock;

   MPU_CTRL : Unsigned_32 with Volatile, Import,
     Address => System'To_Address (16#E000_ED94#);
   MPU_RNR  : Unsigned_32 with Volatile, Import,
     Address => System'To_Address (16#E000_ED98#);
   MPU_RASR : Unsigned_32 with Volatile, Import,
     Address => System'To_Address (16#E000_EDA0#);

   function Window_512 (Region : Unsigned_32) return Boolean is
   begin
      MPU_RNR := Region;
      return (MPU_RASR and 16#3F#) = 8 * 2 + 1;   --  SIZE 8 (512 bytes), ENABLE
   end Window_512;
begin
   Ada.Text_IO.Put_Line ("blocking fifty times under a 512-byte guard");
   loop
      Next := Next + Milliseconds (1);
      delay until Next;
      exit when Idle_Probe.Done;
   end loop;
   Ada.Text_IO.Put_Line ("idle survived");
   Ada.Text_IO.Put_Line
     ("MPU on, both task regions holding a 512-byte window: "
      & Boolean'Image (MPU_CTRL = 5 and then Window_512 (12)
                       and then Window_512 (15)));
   Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
end Test;
