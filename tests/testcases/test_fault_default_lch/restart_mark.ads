--  The restart mark: one word in SRAM4, which the start-up neither loads
--  nor zeroes and which a system reset keeps.

with Interfaces;

package Restart_Mark is

   Word : Interfaces.Unsigned_32 with Volatile, Linker_Section => ".sram4_noinit";
   --  A library-level object, as Linker_Section requires

end Restart_Mark;
