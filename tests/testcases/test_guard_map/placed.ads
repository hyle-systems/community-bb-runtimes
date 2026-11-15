--  Library-level objects, which Linker_Section requires: one in each RAM the
--  map declares besides the DTCM, and a table the linker keeps in flash.

with Interfaces;

package Placed is

   In_AXI    : Interfaces.Unsigned_32
     with Volatile, Linker_Section => ".axisram";
   In_SRAM12 : Interfaces.Unsigned_32
     with Volatile, Linker_Section => ".sram12";
   In_SRAM4  : Interfaces.Unsigned_32
     with Volatile, Linker_Section => ".sram4";

   In_Flash : constant array (0 .. 3) of Interfaces.Unsigned_32 :=
     (16#1111_0000#, 16#2222_0000#, 16#3333_0000#, 16#4444_0000#);

end Placed;
