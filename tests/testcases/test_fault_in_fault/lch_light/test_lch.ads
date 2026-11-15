--  tests/support/lch_light's handler, but printing its entry number, then
--  faulting on purpose.

with System;

package Test_LCH is

   procedure Last_Chance_Handler (Msg : System.Address; Line : Integer)
     with Export, Convention => C,
          External_Name => "__gnat_last_chance_handler", No_Return;

end Test_LCH;
