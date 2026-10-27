with System;
with Interfaces;
with Ada.Text_IO;
with Switch_Probe;
with System.Storage_Elements; use System.Storage_Elements;

package body Test_LCH is

   CFSR : Interfaces.Unsigned_32 with Volatile, Import,
     Address => System'To_Address (16#E000_ED28#);
   use type Interfaces.Unsigned_32;

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
            Ada.Text_IO.Put_Line ("headroom in band: " & Boolean'Image (Switch_Probe.Headroom in 104 .. 199));
      --  CFSR (0xE000ED28): DACCVIOL (bit 1) is the PendSV save's store into
      --  the window; MSTKERR (bit 4) would be an exception entry's own
      --  stacking, a fault before any switch, which proves nothing here.
      Ada.Text_IO.Put_Line
        ("fault at the save (a data access), not at an exception entry: "
         & Boolean'Image ((CFSR and 2) = 2 and then (CFSR and 16) = 0));
      Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
      loop
         null;
      end loop;
   end Last_Chance_Handler;

end Test_LCH;
