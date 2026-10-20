--  192 KB of constants the program reads, so the linker keeps them: larger
--  than the 128 KB flash map, smaller than the 512 KB and 1 MB maps. Without
--  the pragma GNAT elaborates an aggregate this large with a loop into RAM
--  (.bss, and the DTCM overflows instead); with it the table is static data
--  in flash.

with Interfaces;

package Big_Table is

   pragma Static_Elaboration_Desired;

   Table : constant array (0 .. 49_151) of Interfaces.Unsigned_32 :=
     (others => 16#5A5A_A5A5#);

end Big_Table;
