--  Library-level objects, which Linker_Section requires: one with an initial
--  value in `.axisram`, two without in `.sram12` and `.sram4`.

with Interfaces;

package Placed is

   In_AXI    : Interfaces.Unsigned_32 := 16#A51C_0FFE#
     with Linker_Section => ".axisram";
   In_SRAM12 : Interfaces.Unsigned_32
     with Volatile, Linker_Section => ".sram12";
   In_SRAM4  : Interfaces.Unsigned_32
     with Volatile, Linker_Section => ".sram4";

end Placed;
