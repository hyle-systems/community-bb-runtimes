with System;
with Interfaces;
with Ada.Text_IO;

package body Test_LCH is

   CFSR : Interfaces.Unsigned_32 with Volatile, Import,
     Address => System'To_Address (16#E000_ED28#);
   use type Interfaces.Unsigned_32;

   procedure Last_Chance_Handler
     (Except : Ada.Exceptions.Exception_Occurrence)
   is
      Text  : constant String := Ada.Exceptions.Exception_Message (Except);
      First : Positive := Text'First;
      Last  : constant Natural := Text'Last;
   begin
      --  Keep what follows the last ": "
      for I in reverse Text'First .. Text'Last - 1 loop
         if Text (I) = ':' and then Text (I + 1) = ' ' then
            First := I + 2;
            exit;
         end if;
      end loop;
      Ada.Text_IO.Put_Line ("last chance: " & Text (First .. Last));
      --  CFSR (0xE000ED28) bit 4, MSTKERR, flags a fault in the exception
      --  entry's stacking
      Ada.Text_IO.Put_Line
        ("the core's own stacking faulted (MSTKERR): "
         & Boolean'Image ((CFSR and 16) = 16));
      Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
      loop
         null;
      end loop;
   end Last_Chance_Handler;

end Test_LCH;
