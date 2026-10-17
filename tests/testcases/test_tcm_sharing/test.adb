--  The start-up reads the TCM_AXI_SHARED option byte (RM0468 4.9.24: 00 =
--  64 KB ITCM / 320 KB AXI SRAM, 01 = 128 / 256, 10 = 192 / 192, 11 = 256 /
--  128) and initialises the ECC of exactly the ITCM and AXI SRAM the device
--  has, leaving the two sizes in two words for inspection. On the
--  NUCLEO-H723ZG the option byte is at its default.

with Ada.Text_IO;
with Interfaces; use Interfaces;
with System;

procedure Test is
   FLASH_OPTSR2_CUR : Unsigned_32 with Volatile, Import,
     Address => System'To_Address (16#5200_2070#);

   --  The start-up's two words: the number of bytes it initialised
   ITCM_Bytes : Unsigned_32
     with Import, Convention => Asm, External_Name => "__ecc_itcm_bytes";
   AXI_SRAM_Bytes : Unsigned_32
     with Import, Convention => Asm, External_Name => "__ecc_axisram_bytes";
begin
   Ada.Text_IO.Put_Line
     ("TCM_AXI_SHARED =" & Unsigned_32'Image (FLASH_OPTSR2_CUR and 3));
   Ada.Text_IO.Put_Line
     ("ITCM initialised:" & Unsigned_32'Image (ITCM_Bytes));
   Ada.Text_IO.Put_Line
     ("AXI SRAM initialised:" & Unsigned_32'Image (AXI_SRAM_Bytes));
   Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
end Test;
