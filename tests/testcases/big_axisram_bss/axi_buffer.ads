--  200 KB of zero-only buffer in .axisram_bss: not stored in the flash, so it
--  links on the 128 KB part, where 200 KB in .axisram would not.
--  Built only by test_negative_builds.py.

with Interfaces;

package Axi_Buffer is

   Buffer : array (0 .. 51_199) of Interfaces.Unsigned_32
     with Volatile, Linker_Section => ".axisram_bss";

end Axi_Buffer;
