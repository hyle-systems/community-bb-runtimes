with Interfaces;

package Restart_Mark is

   Word : Interfaces.Unsigned_32 with Volatile, Linker_Section => ".sram4";
   --  In SRAM4: never zeroed by the start-up, kept across a system reset;
   --  a library-level object, as Linker_Section requires

end Restart_Mark;
