--  The guard reprograms its windows at every context switch, from PendSV,
--  which can preempt thread code between any two instructions. A program
--  that uses the MPU itself selects a region in MPU_RNR and then writes
--  RBAR and RASR (PM0253 4.6.8): if a switch in between leaves MPU_RNR
--  pointing at a guard region, the program's next write lands on the guard
--  - disabling or moving it - and its own region is never set. The runtime
--  must leave MPU_RNR as it found it. Here the environment task selects
--  region 5, two higher tasks preempt it every 5 and 7 ms (three threads
--  in the two task regions, so the switches reprogram them), and the
--  selection is read back after twenty preemptions.

with Ada.Text_IO;
with Interfaces; use Interfaces;
with System;

with Ticker;

procedure Test is
   MPU_RNR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_ED98#);
   Start   : Natural;
   Seen    : Unsigned_32;
begin
   Ada.Text_IO.Put_Line ("region 5 selected, then twenty preemptions");
   Start := Ticker.Ticks;
   MPU_RNR := 5;
   loop
      exit when Ticker.Ticks - Start >= 20;
   end loop;
   Seen := MPU_RNR;
   Ada.Text_IO.Put_Line ("MPU_RNR kept across the switches: " & Boolean'Image (Seen = 5));
   Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
end Test;
