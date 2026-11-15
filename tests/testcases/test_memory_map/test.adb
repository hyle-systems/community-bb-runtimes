--  The memory map's placements: one object each in .axisram (AXI SRAM),
--  .sram12 (SRAM1/SRAM2, D2) and .sram4 (SRAM4, D3), the last two the RAMs
--  a DMA can reach (not the DTCM, where everything else lives). Each is
--  checked for its placement and the initial value the start-up copied,
--  and the DMA RAMs for a whole-word write read back. The initial values
--  catch a start-up that forgets the SRAM1 and SRAM2 clocks (off after
--  reset, RM0468 8.7.41): the copy runs before the data cache is on and is
--  lost, while a write and read-back alone would pass on dead RAM, the
--  cache serving both once it is on (seen on the board).

with Ada.Text_IO;
with Interfaces; use Interfaces;
with System;
with System.Storage_Elements; use System.Storage_Elements;

with Placed; use Placed;

procedure Test is
   function Within (A : System.Address; First, Last : Integer_Address)
     return Boolean
   is (To_Integer (A) in First .. Last);

   AXI_OK    : constant Boolean :=
     Within (In_AXI'Address, 16#2400_0000#, 16#2404_FFFF#);
   SRAM12_OK : constant Boolean :=
     Within (In_SRAM12'Address, 16#3000_0000#, 16#3000_7FFF#);
   SRAM4_OK  : constant Boolean :=
     Within (In_SRAM4'Address, 16#3800_0000#, 16#3800_3FFF#);
   Value_12, Value_4, Read_12, Read_4 : Boolean := False;
begin
   Ada.Text_IO.Put_Line
     (".axisram: in region " & Boolean'Image (AXI_OK)
      & " value ok " & Boolean'Image (In_AXI = 16#A51C_0FFE#));

   --  Only touch the two if the linker put them where a DMA can reach:
   --  a write to a misplaced variable could land in flash.
   if SRAM12_OK then
      Value_12 := In_SRAM12 = 16#5A12_0012#;
      In_SRAM12 := 16#1234_5678#;
      Read_12 := In_SRAM12 = 16#1234_5678#;
   end if;
   if SRAM4_OK then
      Value_4 := In_SRAM4 = 16#5A04_0004#;
      In_SRAM4 := 16#8765_4321#;
      Read_4 := In_SRAM4 = 16#8765_4321#;
   end if;
   Ada.Text_IO.Put_Line
     (".sram12: in region " & Boolean'Image (SRAM12_OK)
      & " value ok " & Boolean'Image (Value_12)
      & " read back " & Boolean'Image (Read_12));
   Ada.Text_IO.Put_Line
     (".sram4: in region " & Boolean'Image (SRAM4_OK)
      & " value ok " & Boolean'Image (Value_4)
      & " read back " & Boolean'Image (Read_4));
   Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
end Test;
