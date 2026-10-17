--  A survey of every RAM ECC monitor after sub-word writes into each RAM:
--  which memories the start-up leaves with valid ECC everywhere, and which
--  it leaves to the application. Meaningful only on the first run after a
--  POWER CYCLE: a reset keeps the SRAM contents and their ECC bits, so a
--  word written by an earlier program stays valid. The expected output is
--  the prediction for the power-cycled case; the survey is skipped unless
--  ECC_SURVEY=1 is in the environment (opt.py), so an unattended gate does
--  not fail on history. The backup RAM is read, never written.

with Ada.Text_IO;
with Interfaces; use Interfaces;
with System;
with System.Storage_Elements; use System.Storage_Elements;

with ECC_Probe;

procedure Test is
   RCC_AHB2ENR : Unsigned_32 with Volatile, Import,
     Address => System'To_Address (16#5802_44DC#);   -- RM0468 8.7.41
   RCC_AHB4ENR : Unsigned_32 with Volatile, Import,
     Address => System'To_Address (16#5802_44E0#);   -- RM0468 8.7.42

   AXI_Last_KB  : constant System.Address := System'To_Address (16#2404_FC00#);
   ITCM_Last_KB : constant System.Address := System'To_Address (16#0000_FC00#);
   SRAM1_First  : constant System.Address := System'To_Address (16#3000_0000#);
   SRAM2_First  : constant System.Address := System'To_Address (16#3000_4000#);
   SRAM4_First  : constant System.Address := System'To_Address (16#3800_0000#);

   type Byte_Array is array (1 .. 1024) of Unsigned_8;
   type Byte_Array_Access is access Byte_Array;
   Heap_Block : constant Byte_Array_Access := new Byte_Array;

   Stack_Block : Byte_Array with Volatile;
   --  On the environment stack, below everything written so far in this run
begin
   RCC_AHB2ENR := RCC_AHB2ENR or 2#11# * 2 ** 29;   -- SRAM1EN, SRAM2EN
   RCC_AHB4ENR := RCC_AHB4ENR or 2 ** 28;           -- BKPRAMEN

   for M of ECC_Probe.Address_List'(ECC_Probe.D1_AXI_SRAM, ECC_Probe.D1_ITCM,
                                    ECC_Probe.D1_D0TCM, ECC_Probe.D1_D1TCM,
                                    ECC_Probe.D1_Shared, ECC_Probe.D2_SRAM1,
                                    ECC_Probe.D2_SRAM2, ECC_Probe.D3_SRAM4,
                                    ECC_Probe.D3_Backup)
   loop
      ECC_Probe.Clear (M);
   end loop;

   ECC_Probe.Touch (AXI_Last_KB, 1024);
   ECC_Probe.Clean_Data_Cache (AXI_Last_KB, 1024);
   ECC_Probe.Touch (ITCM_Last_KB, 1024);
   ECC_Probe.Touch (Stack_Block'Address, Stack_Block'Length);
   ECC_Probe.Touch (Heap_Block.all'Address, Byte_Array'Length);
   ECC_Probe.Touch (SRAM1_First, 1024);
   ECC_Probe.Clean_Data_Cache (SRAM1_First, 1024);
   ECC_Probe.Touch (SRAM2_First, 1024);
   ECC_Probe.Clean_Data_Cache (SRAM2_First, 1024);
   ECC_Probe.Touch (SRAM4_First, 1024);
   ECC_Probe.Clean_Data_Cache (SRAM4_First, 1024);

   ECC_Probe.Report ("AXI SRAM (initialised by the start-up)", ECC_Probe.D1_AXI_SRAM);
   ECC_Probe.Report ("ITCM (initialised by the start-up)", ECC_Probe.D1_ITCM);
   ECC_Probe.Report ("shared AXI/ITCM", ECC_Probe.D1_Shared);
   ECC_Probe.Report ("D0TCM (stack and heap)", ECC_Probe.D1_D0TCM);
   ECC_Probe.Report ("D1TCM (stack and heap)", ECC_Probe.D1_D1TCM);
   ECC_Probe.Report ("SRAM1 (application's)", ECC_Probe.D2_SRAM1);
   ECC_Probe.Report ("SRAM2 (application's)", ECC_Probe.D2_SRAM2);
   ECC_Probe.Report ("SRAM4 (application's)", ECC_Probe.D3_SRAM4);
   ECC_Probe.Report ("backup RAM (not written)", ECC_Probe.D3_Backup);
   Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
end Test;
