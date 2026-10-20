--  Linked for the RAM loader (LOADER=RAM, the build argument in opt.py):
--  code and constants in the AXI SRAM, data in the DTCM, loaded by the
--  debugger and started from the image's own vector table. The start-up
--  must initialise the ECC of the AXI SRAM *above* the image, not from its
--  start, or the program erases itself before this line runs.

with Ada.Text_IO;
with Interfaces; use Interfaces;
with System;
with System.Storage_Elements; use System.Storage_Elements;

procedure Test is
   Here : constant Integer_Address := To_Integer (Test'Address);
begin
   Ada.Text_IO.Put_Line
     ("running from the AXI SRAM: "
      & Boolean'Image (Here in 16#2400_0000# .. 16#2404_FFFF#));
   Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
end Test;
