with Ada.Text_IO;
with System.Storage_Elements; use System.Storage_Elements;

package body Test_LCH is

   procedure Last_Chance_Handler (Msg : System.Address; Line : Integer) is
      Text : String (1 .. 80);
      Last : Natural := 0;
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
      Ada.Text_IO.Put_Line ("last chance: " & Text (1 .. Last)
                            & (if Line /= 0 then ":" & Integer'Image (Line) else ""));
      Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
      loop
         null;
      end loop;
   end Last_Chance_Handler;

end Test_LCH;
