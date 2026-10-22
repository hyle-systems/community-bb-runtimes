--  The test's own last-chance handler for the light and light-tasking
--  profiles: prints the message's last part (after the final ": ") and
--  whether it runs above the interrupt stack's end (on the fault stack),
--  then the completion marker, then stays.

with System;

package Test_LCH is

   procedure Last_Chance_Handler (Msg : System.Address; Line : Integer)
     with Export, Convention => C,
          External_Name => "__gnat_last_chance_handler", No_Return;

end Test_LCH;
