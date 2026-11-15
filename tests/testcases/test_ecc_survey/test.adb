--  A survey of the RAM ECC monitors: which memories the start-up leaves
--  with a valid ECC in every word, and which it leaves to the application.
--  test.out is the output of the first run after a POWER CYCLE: a reset
--  keeps the SRAM contents and their ECC bits, so a word an earlier program
--  wrote reads as clean. opt.py therefore skips the test unless
--  ECC_SURVEY=1, so that an unattended gate does not fail on history.

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
   Heap_Block_1 : constant Byte_Array_Access := new Byte_Array;
   Heap_Block_2 : constant Byte_Array_Access := new Byte_Array;
   --  Two kilobytes of the DTCM heap. Of the gate's other programs only
   --  heap_alloc allocates, one Integer, so after a power cycle these words
   --  are as the power-up left them (that Integer aside), even though the
   --  previously flashed program ran once before the harness took the
   --  board. A stack block would not do: every program's environment stack
   --  covers the same addresses.
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
   ECC_Probe.Touch (Heap_Block_1.all'Address, Byte_Array'Length);
   ECC_Probe.Touch (Heap_Block_2.all'Address, Byte_Array'Length);
   ECC_Probe.Touch (SRAM1_First, 1024);
   ECC_Probe.Clean_Data_Cache (SRAM1_First, 1024);
   ECC_Probe.Touch (SRAM2_First, 1024);
   ECC_Probe.Clean_Data_Cache (SRAM2_First, 1024);
   ECC_Probe.Touch (SRAM4_First, 1024);
   ECC_Probe.Clean_Data_Cache (SRAM4_First, 1024);

   --  Measured after a power cycle on the NUCLEO-H723ZG: test.out. The DTCM
   --  raises nothing on a sub-word first touch, so the stack and heap area
   --  needs no initialisation; SRAM1, SRAM2 and SRAM4 read 3 (single error
   --  corrected and double error detected), so a program must write them
   --  whole-word before any sub-word use after power-up.
   ECC_Probe.Report ("AXI SRAM (initialised by the start-up)", ECC_Probe.D1_AXI_SRAM);
   ECC_Probe.Report ("ITCM (initialised by the start-up)", ECC_Probe.D1_ITCM);
   ECC_Probe.Report ("shared AXI/ITCM", ECC_Probe.D1_Shared);
   ECC_Probe.Report ("D0TCM (heap)", ECC_Probe.D1_D0TCM);
   ECC_Probe.Report ("D1TCM (heap)", ECC_Probe.D1_D1TCM);
   ECC_Probe.Report ("SRAM1 (application's)", ECC_Probe.D2_SRAM1);
   ECC_Probe.Report ("SRAM2 (application's)", ECC_Probe.D2_SRAM2);
   ECC_Probe.Report ("SRAM4 (application's)", ECC_Probe.D3_SRAM4);
   ECC_Probe.Report ("backup RAM (not written)", ECC_Probe.D3_Backup);
   Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
end Test;
