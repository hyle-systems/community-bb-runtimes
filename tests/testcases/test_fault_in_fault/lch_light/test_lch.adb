with Ada.Text_IO;
with Interfaces; use Interfaces;
with System.Storage_Elements; use System.Storage_Elements;

package body Test_LCH is

   Entries : Natural := 0 with Volatile;

   Nowhere : Unsigned_32 with Volatile, Import,
     Address => System'To_Address (16#D000_0000#);

   procedure Last_Chance_Handler (Msg : System.Address; Line : Integer) is
      pragma Unreferenced (Line);
      Text  : String (1 .. 200);
      Last  : Natural := 0;
      First : Positive := 1;
      Value : Unsigned_32;
   begin
      Entries := Entries + 1;
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
