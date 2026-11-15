--  tests/support/lch_embedded's handler, but printing its entry number,
--  then faulting on purpose.

with Ada.Exceptions;

package Test_LCH is

   procedure Last_Chance_Handler
     (Except : Ada.Exceptions.Exception_Occurrence)
     with Export, Convention => C,
          External_Name => "__gnat_last_chance_handler", No_Return;

end Test_LCH;
