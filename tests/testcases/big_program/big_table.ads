with Interfaces;

package Big_Table is

   --  Static data in flash: without the pragma GNAT elaborates the
   --  aggregate with a loop into .bss, and the DTCM overflows.
   pragma Static_Elaboration_Desired;

   Table : constant array (0 .. 49_151) of Interfaces.Unsigned_32 :=
     (others => 16#5A5A_A5A5#);

end Big_Table;
