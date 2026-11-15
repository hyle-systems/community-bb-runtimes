--  The test's last-chance handler for the embedded profile: it prints the
--  fault stack use (see test.adb) and the completion marker, then spins.

with Ada.Exceptions;

package Test_LCH is

   procedure Last_Chance_Handler
     (Except : Ada.Exceptions.Exception_Occurrence)
     with Export, Convention => C,
          External_Name => "__gnat_last_chance_handler", No_Return;

end Test_LCH;
