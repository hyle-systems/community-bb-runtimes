--  Stack_Guard = true: the MPU is on with ENABLE + PRIVDEFENA (MPU_CTRL = 5)
--  and only the guard regions programmed, so the background map must still
--  cover everything else. Every memory the map declares, and a peripheral,
--  is written and read back without a fault: the DTCM (a local variable),
--  the AXI SRAM (`.axisram`), SRAM1/SRAM2 (`.sram12`, clocked first through
--  RCC_AHB2ENR), SRAM4 (`.sram4`), the backup SRAM (clocked through
--  RCC_AHB4ENR BKPRAMEN, written after PWR_CR1 DBP opens the backup domain),
--  flash (a constant table) and TIM2's ARR (clocked through RCC_APB1LENR);
--  then the RAMs again from a task. A guard that left PRIVDEFENA clear, or a
--  region that covered more than its window, would fault here. RM0468:
--  8.7.41 RCC_AHB2ENR, 8.7.42 RCC_AHB4ENR (BKPRAMEN bit 28), 8.7.44
--  RCC_APB1LENR, 6.8.1 PWR_CR1 (DBP bit 8), Table 6 (backup SRAM at
--  0x3880_0000).

with Ada.Synchronous_Task_Control;
with Ada.Text_IO;
with Interfaces; use Interfaces;
with System;
with System.Storage_Elements; use System.Storage_Elements;

with Placed; use Placed;
with Worker;

procedure Test is
   MPU_CTRL     : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_ED94#);
   RCC_AHB2ENR  : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#5802_44DC#);
   RCC_AHB4ENR  : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#5802_44E0#);
   RCC_APB1LENR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#5802_44E8#);
   PWR_CR1      : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#5802_4800#);
   Backup_Word  : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#3880_0000#);
   TIM2_ARR     : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4000_002C#);

   function Within (A : System.Address; First, Last : Integer_Address)
     return Boolean
   is (To_Integer (A) in First .. Last);

   In_DTCM : Unsigned_32 with Volatile;
   Dummy   : Unsigned_32 with Volatile;
   Idx     : Integer := 2 with Volatile;
begin
   Ada.Text_IO.Put_Line ("MPU_CTRL =" & Unsigned_32'Image (MPU_CTRL));

   In_DTCM := 16#D7C3_0001#;
   Ada.Text_IO.Put_Line
     ("DTCM: in region " & Boolean'Image (Within (In_DTCM'Address, 16#2000_0000#, 16#2001_FFFF#))
      & " write/read " & Boolean'Image (In_DTCM = 16#D7C3_0001#));

   In_AXI := 16#A51C_0002#;
   Ada.Text_IO.Put_Line
     ("AXI SRAM: in region " & Boolean'Image (Within (In_AXI'Address, 16#2400_0000#, 16#2404_FFFF#))
      & " write/read " & Boolean'Image (In_AXI = 16#A51C_0002#));

   RCC_AHB2ENR := RCC_AHB2ENR or 2#11# * 2 ** 29;   -- SRAM1EN, SRAM2EN
   Dummy := RCC_AHB2ENR;
   In_SRAM12 := 16#5112_0003#;
   Ada.Text_IO.Put_Line
     ("SRAM1/2: in region " & Boolean'Image (Within (In_SRAM12'Address, 16#3000_0000#, 16#3000_7FFF#))
      & " write/read " & Boolean'Image (In_SRAM12 = 16#5112_0003#));

   In_SRAM4 := 16#5400_0004#;
   Ada.Text_IO.Put_Line
     ("SRAM4: in region " & Boolean'Image (Within (In_SRAM4'Address, 16#3800_0000#, 16#3800_3FFF#))
      & " write/read " & Boolean'Image (In_SRAM4 = 16#5400_0004#));

   RCC_AHB4ENR := RCC_AHB4ENR or 2 ** 28;           -- BKPRAMEN
   Dummy := RCC_AHB4ENR;
   PWR_CR1 := PWR_CR1 or 2 ** 8;                    -- DBP
   Dummy := PWR_CR1;
   Backup_Word := 16#BAC0_0005#;
   Ada.Text_IO.Put_Line
     ("backup SRAM: write/read " & Boolean'Image (Backup_Word = 16#BAC0_0005#));

   Ada.Text_IO.Put_Line
     ("flash: in region " & Boolean'Image (Within (In_Flash'Address, 16#0800_0000#, 16#080F_FFFF#))
      & " read " & Boolean'Image (In_Flash (Idx) = 16#3333_0000#));

   RCC_APB1LENR := RCC_APB1LENR or 1;               -- TIM2EN
   Dummy := RCC_APB1LENR;
   TIM2_ARR := 16#0000_1234#;
   Ada.Text_IO.Put_Line
     ("peripheral (TIM2_ARR): write/read " & Boolean'Image (TIM2_ARR = 16#0000_1234#));

   Ada.Synchronous_Task_Control.Suspend_Until_True (Worker.Done);
   Ada.Text_IO.Put_Line ("from a task: write/read " & Boolean'Image (Worker.OK));

   Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
end Test;
