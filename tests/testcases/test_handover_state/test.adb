--  Z9 of the fourth review: what a bootloader leaves in RCC_CFGR beyond the
--  clock switch (TIMPRE here; MCO and RTCPRE the same way) and in the MPU.
--  The start-up re-establishes the reset state it computes from: the whole
--  CFGR at its reset value, the MPU off when the stack guard is off.

with Ada.Text_IO;
with Interfaces; use Interfaces;
with System;

with Handover;

procedure Test is
   RCC_CFGR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#5802_4410#);
   MPU_CTRL : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_ED94#);
   MPU_RNR  : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_ED98#);
   MPU_RBAR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_ED9C#);
   MPU_RASR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_EDA0#);
begin
   if Handover.Second_Pass then
      Ada.Text_IO.Put_Line ("second pass, after a hand-over with TIMPRE set and the MPU on");
      Ada.Text_IO.Put_Line ("TIMPRE at its reset value: " & Boolean'Image ((RCC_CFGR and 2 ** 15) = 0));
      Ada.Text_IO.Put_Line ("MPU off, the guard being off: " & Boolean'Image (MPU_CTRL = 0));
      Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
   else
      Ada.Text_IO.Put_Line ("first pass: TIMPRE set, an MPU region over unused SRAM4 and the MPU on, then the hand-over");
      RCC_CFGR := RCC_CFGR or 2 ** 15;
      MPU_RNR  := 3;
      MPU_RBAR := 16#3800_3000#;                 --  32 bytes, no access, execute never
      MPU_RASR := 16#1000_0000# or (4 * 2) or 1;
      MPU_CTRL := 5;                             --  ENABLE, PRIVDEFENA
      Handover.Mark;
      Handover.Restart;
   end if;
end Test;
