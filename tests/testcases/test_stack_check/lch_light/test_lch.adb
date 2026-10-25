with Ada.Text_IO;
with Digger;
with System.Storage_Elements; use System.Storage_Elements;

package body Test_LCH is

   procedure Last_Chance_Handler (Msg : System.Address; Line : Integer) is
      pragma Unreferenced (Line);
      Text  : String (1 .. 200);
      Last  : Natural := 0;
      First : Positive := 1;
   begin
      --  Msg is a NUL-terminated string
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
      --  Keep what follows the last ": "
      for I in reverse 1 .. Last - 1 loop
         if Text (I) = ':' and then Text (I + 1) = ' ' then
            First := I + 2;
            exit;
         end if;
      end loop;
      --  A raise without text arrives as "unit.adb:line": keep the unit
      for I in First .. Last loop
         if Text (I) = ':' and then I > First + 4
           and then Text (I - 4 .. I - 1) in ".adb" | ".ads"
         then
            Last := I - 1;
            exit;
         end if;
      end loop;
      Ada.Text_IO.Put_Line ("last chance: " & Text (First .. Last));
      Ada.Text_IO.Put_Line ("check at a depth in band: " & Boolean'Image (Digger.Depth in 25 .. 52));
      Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
      loop
         null;
      end loop;
   end Last_Chance_Handler;

end Test_LCH;
