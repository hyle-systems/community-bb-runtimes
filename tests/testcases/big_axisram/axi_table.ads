--  300 KB of initialised data placed in the AXI SRAM, more than 65 535 words, the most the start-up's copy loop can
--  count (upstream's start-rom.S loads the word count with a single movw):
--  the link must be refused by the family's linker script, not left to a
--  silent partial copy.
--  Built only by test_negative_builds.py.

with Interfaces;

package Axi_Table is

   pragma Static_Elaboration_Desired;

   Table : array (0 .. 76_799) of Interfaces.Unsigned_32 :=
     (others => 16#5A5A_A5A5#)
     with Linker_Section => ".axisram";

end Axi_Table;
