with Interfaces;

package Axi_Buffer is

   Buffer : array (0 .. 51_199) of Interfaces.Unsigned_32
     with Volatile, Linker_Section => ".axisram_bss";

end Axi_Buffer;
