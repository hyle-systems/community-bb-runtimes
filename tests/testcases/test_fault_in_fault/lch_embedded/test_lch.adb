with Ada.Text_IO;
with Interfaces; use Interfaces;
with System;

package body Test_LCH is

   Entries : Natural := 0 with Volatile;

   Nowhere : Unsigned_32 with Volatile, Import,
     Address => System'To_Address (16#D000_0000#);

   procedure Last_Chance_Handler
     (Except : Ada.Exceptions.Exception_Occurrence)
   is
      Text  : constant String := Ada.Exceptions.Exception_Message (Except);
      First : Positive := Text'First;
      Value : Unsigned_32;
   begin
      Entries := Entries + 1;
      for I in reverse Text'First .. Text'Last - 1 loop
         if Text (I) = ':' and then Text (I + 1) = ' ' then
            First := I + 2;
            exit;
         end if;
      end loop;
      Ada.Text_IO.Put_Line ("last chance: " & Text (First .. Text'Last));
      if Entries = 1 then
         Ada.Text_IO.Put_Line ("entry 1, faulting on purpose");
      else
         Ada.Text_IO.Put_Line ("entry 2: the report ran again");
      end if;
      Value := Nowhere;
      Ada.Text_IO.Put_Line ("the read returned" & Unsigned_32'Image (Value));
      loop
         null;
      end loop;
   end Last_Chance_Handler;

end Test_LCH;
