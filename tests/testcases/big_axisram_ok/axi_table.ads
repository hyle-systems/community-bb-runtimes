--  200 KB of initialised data placed in the AXI SRAM, fewer than 65 535 words: the positive control, it must link.
--  Built only by test_negative_builds.py.

with Interfaces;

package Axi_Table is

   pragma Static_Elaboration_Desired;

   Table : array (0 .. 51_199) of Interfaces.Unsigned_32 :=
     (others => 16#5A5A_A5A5#)
     with Linker_Section => ".axisram";

end Axi_Table;
