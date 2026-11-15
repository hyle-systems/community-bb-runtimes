--  The test's last-chance handler for the embedded profile; test.adb says
--  what it prints and why.

with Ada.Exceptions;

package Test_LCH is

   procedure Last_Chance_Handler
     (Except : Ada.Exceptions.Exception_Occurrence)
     with Export, Convention => C,
          External_Name => "__gnat_last_chance_handler", No_Return;

end Test_LCH;
