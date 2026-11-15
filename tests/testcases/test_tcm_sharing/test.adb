--  The start-up reads the TCM_AXI_SHARED option byte (RM0468 4.9.24: 00 =
--  64 KB ITCM / 320 KB AXI SRAM, 01 = 128 / 256, 10 = 192 / 192, 11 = 256 /
--  128) and initialises the ECC of exactly the ITCM and AXI SRAM the device
--  has, leaving the two sizes in two words for inspection. The expectation
--  follows the field the test reads, so the test holds on a device with any
--  sharing and fails only when the start-up's sizes disagree with the option
--  byte. On the NUCLEO-H723ZG the option byte is at its default.

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

   Field         : constant Unsigned_32 := FLASH_OPTSR2_CUR and 3;
   ITCM_Expected : constant Unsigned_32 := 65_536 * (Field + 1);
   AXI_Expected  : constant Unsigned_32 := 327_680 - 65_536 * Field;
begin
   Ada.Text_IO.Put_Line
     ("ITCM initialised as the option byte says: "
      & Boolean'Image (ITCM_Bytes = ITCM_Expected));
   Ada.Text_IO.Put_Line
     ("AXI SRAM initialised as the option byte says: "
      & Boolean'Image (AXI_SRAM_Bytes = AXI_Expected));
   Ada.Text_IO.Put_Line
     ("the two sizes sum to 384 KB: "
      & Boolean'Image (ITCM_Bytes + AXI_SRAM_Bytes = 393_216));
   Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
end Test;
