with Ada.Text_IO;
with Digger;

package body Test_LCH is

   procedure Last_Chance_Handler
     (Except : Ada.Exceptions.Exception_Occurrence)
   is
      Text  : constant String := Ada.Exceptions.Exception_Message (Except);
      First : Positive := Text'First;
      Last  : Natural := Text'Last;
   begin
      --  Keep what follows the last ": "
      for I in reverse Text'First .. Text'Last - 1 loop
         if Text (I) = ':' and then Text (I + 1) = ' ' then
            First := I + 2;
            exit;
         end if;
      end loop;
      --  A raise without text arrives as "unit.adb:line ...": keep the unit
      for I in First .. Last loop
         if Text (I) = ':' and then I > First + 4
           and then Text (I - 4 .. I - 1) in ".adb" | ".ads"
         then
            Last := I - 1;
            exit;
         end if;
      end loop;
      Ada.Text_IO.Put_Line ("last chance: " & Text (First .. Last));
      Ada.Text_IO.Put_Line ("check at a depth in band: " & Boolean'Image (Digger.Depth in 8 .. 20));
      Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
      loop
         null;
      end loop;
   end Last_Chance_Handler;

end Test_LCH;
