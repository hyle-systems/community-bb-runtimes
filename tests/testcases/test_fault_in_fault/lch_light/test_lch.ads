--  The test's own last-chance handler for the light and light-tasking
--  profiles: counts its entries, prints the message's last part and the
--  entry number, then faults on purpose. It replaces the runtime's at link
--  time (same external name).

with System;

package Test_LCH is

   procedure Last_Chance_Handler (Msg : System.Address; Line : Integer)
     with Export, Convention => C,
          External_Name => "__gnat_last_chance_handler", No_Return;

end Test_LCH;
