--  The test's own last-chance handler for the light and light-tasking
--  profiles, whose handler receives a C string and a line: prints the
--  message's last part (after the final ": ", so that the compiler's
--  "Unit.Subprogram: " prefix does not matter) and the completion marker,
--  then stays. It replaces the runtime's at link time (same external name).

with System;

package Test_LCH is

   procedure Last_Chance_Handler (Msg : System.Address; Line : Integer)
     with Export, Convention => C,
          External_Name => "__gnat_last_chance_handler", No_Return;

end Test_LCH;
