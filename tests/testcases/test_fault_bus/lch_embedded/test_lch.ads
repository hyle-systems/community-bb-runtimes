--  tests/support/lch_embedded's handler, also printing the bus fault status
--  the trap kept.

with Ada.Exceptions;

package Test_LCH is

   procedure Last_Chance_Handler
     (Except : Ada.Exceptions.Exception_Occurrence)
     with Export, Convention => C,
          External_Name => "__gnat_last_chance_handler", No_Return;

end Test_LCH;
