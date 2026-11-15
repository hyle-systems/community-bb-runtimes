with Interfaces;

package Axi_Table is

   pragma Static_Elaboration_Desired;

   Table : array (0 .. 76_799) of Interfaces.Unsigned_32 :=
     (others => 16#5A5A_A5A5#)
     with Linker_Section => ".axisram";

end Axi_Table;
