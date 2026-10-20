--  The memory map's placements: a variable with an initial value in
--  `.axisram` (AXI SRAM, copied by the start-up: placement and value), and
--  one each in `.sram12` (SRAM1/SRAM2, D2) and `.sram4` (SRAM4, D3), the
--  DMA-reachable RAMs, which the application clocks and writes whole-word
--  first. A DMA cannot reach the DTCM, where everything else lives.

with Ada.Text_IO;
with Interfaces; use Interfaces;
with System;
with System.Storage_Elements; use System.Storage_Elements;

with Placed; use Placed;

procedure Test is
   RCC_AHB2ENR : Unsigned_32 with Volatile, Import,
     Address => System'To_Address (16#5802_44DC#);   -- RM0468 8.7.41

   function Within (A : System.Address; First, Last : Integer_Address)
     return Boolean
   is (To_Integer (A) in First .. Last);

   AXI_OK    : constant Boolean :=
     Within (In_AXI'Address, 16#2400_0000#, 16#2404_FFFF#);
   SRAM12_OK : constant Boolean :=
     Within (In_SRAM12'Address, 16#3000_0000#, 16#3000_7FFF#);
   SRAM4_OK  : constant Boolean :=
     Within (In_SRAM4'Address, 16#3800_0000#, 16#3800_3FFF#);
   Read_12, Read_4 : Boolean := False;
begin
   Ada.Text_IO.Put_Line
     (".axisram: in region " & Boolean'Image (AXI_OK)
      & " value ok " & Boolean'Image (In_AXI = 16#A51C_0FFE#));

   --  Only touch the two if the linker put them where a DMA can reach:
   --  a write to a misplaced variable could land in flash.
   if SRAM12_OK then
      RCC_AHB2ENR := RCC_AHB2ENR or 2#11# * 2 ** 29;   -- SRAM1EN, SRAM2EN
      In_SRAM12 := 16#1234_5678#;
      Read_12 := In_SRAM12 = 16#1234_5678#;
   end if;
   if SRAM4_OK then
      In_SRAM4 := 16#8765_4321#;
      Read_4 := In_SRAM4 = 16#8765_4321#;
   end if;
   Ada.Text_IO.Put_Line
     (".sram12: in region " & Boolean'Image (SRAM12_OK)
      & " read back " & Boolean'Image (Read_12));
   Ada.Text_IO.Put_Line
     (".sram4: in region " & Boolean'Image (SRAM4_OK)
      & " read back " & Boolean'Image (Read_4));
   Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
end Test;
