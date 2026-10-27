with Interfaces;

package Dcache_Lines is

   Words : array (0 .. 63) of Interfaces.Unsigned_32
     with Volatile, Linker_Section => ".sram4_noinit", Alignment => 32;
   --  Eight cache lines in SRAM4, which the start-up neither loads nor
   --  zeroes; a
   --  library-level object, as Linker_Section requires

end Dcache_Lines;
