--  The guard reprograms its windows at every context switch, from PendSV,
--  which can fall between a program's write of MPU_RNR and its writes of
--  RBAR and RASR (PM0253 4.6.8). A switch that left MPU_RNR on a guard
--  region would make those writes disable or move the guard and never set
--  the program's own region: the runtime must leave MPU_RNR as it found
--  it. The environment task selects region 5 and reads it back after
--  twenty preemptions by the two Ticker tasks (every 5 and 7 ms).

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
