--  tests/support/lch_light's handler, also printing whether it runs on the
--  fault stack and whether the faulting SP lay in the interrupt stack.

with System;

package Test_LCH is

   procedure Last_Chance_Handler (Msg : System.Address; Line : Integer)
     with Export, Convention => C,
          External_Name => "__gnat_last_chance_handler", No_Return;

end Test_LCH;
