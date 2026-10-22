--  The test's own last-chance handler for the embedded profile, whose
--  handler receives the exception occurrence: counts its entries, prints the
--  message's last part and the entry number, then faults on purpose.

with Ada.Exceptions;

package Test_LCH is

   procedure Last_Chance_Handler
     (Except : Ada.Exceptions.Exception_Occurrence)
     with Export, Convention => C,
          External_Name => "__gnat_last_chance_handler", No_Return;

end Test_LCH;
