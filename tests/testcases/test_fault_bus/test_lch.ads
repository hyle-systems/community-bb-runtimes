--  The test's own last-chance handler: prints the message it receives and
--  the completion marker, then stays. It replaces the runtime's at link
--  time (same external name), so a fault routed by the runtime ends in
--  readable text instead of a reset.

with System;

package Test_LCH is

   procedure Last_Chance_Handler (Msg : System.Address; Line : Integer)
     with Export, Convention => C,
          External_Name => "__gnat_last_chance_handler", No_Return;

end Test_LCH;
