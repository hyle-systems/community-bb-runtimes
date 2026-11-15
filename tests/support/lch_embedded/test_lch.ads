--  The test's last-chance handler for the embedded profile, which passes the
--  exception occurrence. It overrides the runtime's by name, prints the
--  message after its last ": " and the completion marker, then spins.

with Ada.Exceptions;

package Test_LCH is

   procedure Last_Chance_Handler
     (Except : Ada.Exceptions.Exception_Occurrence)
     with Export, Convention => C,
          External_Name => "__gnat_last_chance_handler", No_Return;

end Test_LCH;
