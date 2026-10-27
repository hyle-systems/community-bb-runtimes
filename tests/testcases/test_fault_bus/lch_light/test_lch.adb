with Interfaces; use Interfaces;
with Ada.Text_IO;
with System.Storage_Elements; use System.Storage_Elements;

package body Test_LCH is

   CFSR : constant Unsigned_32
     with Import, Convention => Asm, External_Name => "__gnat_fault_cfsr";
   BFAR : constant Unsigned_32
     with Import, Convention => Asm, External_Name => "__gnat_fault_bfar";

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
      Ada.Text_IO.Put_Line ("last chance: " & Text (First .. Last));
      --  The fault status the trap kept (PM0253 4.3.10, 4.3.14): a precise
      --  data bus error (PRECISERR, CFSR bit 9) with a valid address
      --  (BFARVALID, bit 15), the address read
      Ada.Text_IO.Put_Line
        ("fault status kept: PRECISERR " & Boolean'Image ((CFSR and 2 ** 9) /= 0)
         & " BFARVALID " & Boolean'Image ((CFSR and 2 ** 15) /= 0)
         & " BFAR = 16#D000_0000# " & Boolean'Image (BFAR = 16#D000_0000#));
      Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
      loop
         null;
      end loop;
   end Last_Chance_Handler;

end Test_LCH;
