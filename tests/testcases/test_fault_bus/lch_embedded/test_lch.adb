with Interfaces; use Interfaces;
with Ada.Text_IO;

package body Test_LCH is

   CFSR : constant Unsigned_32
     with Import, Convention => Asm, External_Name => "__gnat_fault_cfsr";
   BFAR : constant Unsigned_32
     with Import, Convention => Asm, External_Name => "__gnat_fault_bfar";

   procedure Last_Chance_Handler
     (Except : Ada.Exceptions.Exception_Occurrence)
   is
      Text  : constant String := Ada.Exceptions.Exception_Message (Except);
      First : Positive := Text'First;
   begin
      --  Keep what follows the last ": "
      for I in reverse Text'First .. Text'Last - 1 loop
         if Text (I) = ':' and then Text (I + 1) = ' ' then
            First := I + 2;
            exit;
         end if;
      end loop;
      Ada.Text_IO.Put_Line ("last chance: " & Text (First .. Text'Last));
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
