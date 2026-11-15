--  The test's last-chance handler for the light and light-tasking profiles,
--  which pass a C string and a line. It overrides the runtime's by name,
--  prints the message after its last ": " (without the "Unit.Subprogram: "
--  prefix) and the completion marker, then spins.

with System;

package Test_LCH is

   procedure Last_Chance_Handler (Msg : System.Address; Line : Integer)
     with Export, Convention => C,
          External_Name => "__gnat_last_chance_handler", No_Return;

end Test_LCH;
