--  tests/support/lch_light's last-chance handler, also printing the
--  headroom check and CFSR's fault kind.

with System;

package Test_LCH is

   procedure Last_Chance_Handler (Msg : System.Address; Line : Integer)
     with Export, Convention => C,
          External_Name => "__gnat_last_chance_handler", No_Return;

end Test_LCH;
