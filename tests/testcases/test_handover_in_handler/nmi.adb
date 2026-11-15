with System.Machine_Code; use System.Machine_Code;

package body NMI is

   procedure Handler is
   begin
      Asm ("b _start_rom", Volatile => True);
   end Handler;

end NMI;
