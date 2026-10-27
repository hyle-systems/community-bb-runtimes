--  What a bootloader leaves in RCC_CFGR beyond the
--  clock switch (TIMPRE here; MCO and RTCPRE the same way) and in the MPU.
--  The start-up re-establishes the reset state it computes from: the whole
--  CFGR at its reset value, the MPU off when the stack guard is off.

with Ada.Text_IO;
with Interfaces; use Interfaces;
with System;
with System.Machine_Code; use System.Machine_Code;
with System.Storage_Elements; use System.Storage_Elements;

with Handover;

procedure Test is
   RCC_CFGR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#5802_4410#);
   MPU_CTRL : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_ED94#);
   MPU_RNR  : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_ED98#);
   MPU_RBAR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_ED9C#);
   MPU_RASR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_EDA0#);
   FPCCR    : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_EF34#);
   Stack_Start : constant Character
     with Import, Convention => Asm, External_Name => "__stack_start";
   Stack_End : constant Character
     with Import, Convention => Asm, External_Name => "__stack_end";
   BASEPRI, SP, PRIMASK : Unsigned_32;
begin
   if Handover.Second_Pass then
      Ada.Text_IO.Put_Line ("second pass, after a hand-over with TIMPRE set and the MPU on");
      Ada.Text_IO.Put_Line ("TIMPRE at its reset value: " & Boolean'Image ((RCC_CFGR and 2 ** 15) = 0));
      Ada.Text_IO.Put_Line ("MPU off, the guard being off: " & Boolean'Image (MPU_CTRL = 0));
      Ada.Text_IO.Put_Line
        ("lazy floating-point stacking re-established: "
         & Boolean'Image ((FPCCR and 16#C000_0000#) = 16#C000_0000#));
      Asm ("mrs %0, basepri", Outputs => Unsigned_32'Asm_Output ("=r", BASEPRI), Volatile => True);
      Asm ("mov %0, sp", Outputs => Unsigned_32'Asm_Output ("=r", SP), Volatile => True);
      Asm ("mrs %0, primask", Outputs => Unsigned_32'Asm_Output ("=r", PRIMASK), Volatile => True);
      Ada.Text_IO.Put_Line
        ("on the environment stack, not the bootloader's, BASEPRI at zero: "
         --  Which stack pointer is not the property: the embedded profile
         --  runs the environment task on the process stack by design
         & Boolean'Image (SP >= Unsigned_32 (To_Integer (Stack_Start'Address))
                          and then SP < Unsigned_32 (To_Integer (Stack_End'Address))
                          and then BASEPRI = 0));
      Ada.Text_IO.Put_Line
        ("interrupts unmasked, the bootloader having jumped with PRIMASK set: "
         & Boolean'Image (PRIMASK = 0));
      Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
   else
      Ada.Text_IO.Put_Line ("first pass: TIMPRE set, an MPU region over unused SRAM4 and the MPU on, then the hand-over");
      RCC_CFGR := RCC_CFGR or 2 ** 15;
      MPU_RNR  := 3;
      MPU_RBAR := 16#3800_3000#;                 --  32 bytes, no access, execute never
      MPU_RASR := 16#1000_0000# or (4 * 2) or 1;
      --  The ITCM read-only (AP 110, PM0253 Table 93), as code protection
      --  might leave it: the start-up's ECC zeroing writes it
      MPU_RNR  := 4;
      MPU_RBAR := 16#0000_0000#;
      MPU_RASR := 16#0600_0000# or (15 * 2) or 1; --  64 KB
      MPU_CTRL := 5;                             --  ENABLE, PRIVDEFENA
      Handover.Mark;
      Handover.Restart;
   end if;
end Test;
