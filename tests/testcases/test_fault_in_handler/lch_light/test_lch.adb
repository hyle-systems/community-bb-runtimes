with Ada.Text_IO;
with System.Machine_Code; use System.Machine_Code;
with System.Storage_Elements; use System.Storage_Elements;

package body Test_LCH is

   Interrupt_Stack_End : constant Character
     with Import, Convention => Asm, External_Name => "__interrupt_stack_end";

   procedure Last_Chance_Handler (Msg : System.Address; Line : Integer) is
      pragma Unreferenced (Line);
      Text  : String (1 .. 200);
      Last  : Natural := 0;
      First : Positive := 1;
      SP    : System.Address;
   begin
      Asm ("mov %0, sp", Outputs => System.Address'Asm_Output ("=r", SP), Volatile => True);
      for I in Text'Range loop
         declare
            C : constant Character
              with Import, Address => Msg + Storage_Offset (I - 1);
         begin
            exit when C = ASCII.NUL;
            Text (I) := C;
            Last := I;
         end;
      end loop;
      for I in reverse 1 .. Last - 1 loop
         if Text (I) = ':' and then Text (I + 1) = ' ' then
            First := I + 2;
            exit;
         end if;
      end loop;
      Ada.Text_IO.Put_Line ("last chance: " & Text (First .. Last));
      if To_Integer (SP) > To_Integer (Interrupt_Stack_End'Address) then
         Ada.Text_IO.Put_Line ("reported above the interrupt stack: TRUE");
      else
         Ada.Text_IO.Put_Line ("reported above the interrupt stack: FALSE");
      end if;
      Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
      loop
         null;
      end loop;
   end Last_Chance_Handler;

end Test_LCH;
