--  The placed objects, at library level as Linker_Section requires, each
--  with an initial value that the start-up must copy into its RAM.

with Interfaces;

package Placed is

   In_AXI    : Interfaces.Unsigned_32 := 16#A51C_0FFE#
     with Linker_Section => ".axisram";
   In_SRAM12 : Interfaces.Unsigned_32 := 16#5A12_0012#
     with Volatile, Linker_Section => ".sram12";
   In_SRAM4  : Interfaces.Unsigned_32 := 16#5A04_0004#
     with Volatile, Linker_Section => ".sram4";

end Placed;
