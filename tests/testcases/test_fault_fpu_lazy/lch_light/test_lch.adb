with Ada.Text_IO;
with Lazy_Probe;
with Interfaces; use Interfaces;
with System;
with System.Storage_Elements; use System.Storage_Elements;

package body Test_LCH is
   CFSR  : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_ED28#);
   HFSR  : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_ED2C#);
   SHCSR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_ED24#);
   FPCCR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_EF34#);
   FPCAR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_EF38#);

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
      --  Before any FP instruction here: the stacking fault, the lazy state
      --  pending, its area starting inside the window (FPCAR below its top)
      Ada.Text_IO.Put_Line ("stacking fault: " & Boolean'Image ((CFSR and 16#10#) /= 0));
      Ada.Text_IO.Put_Line ("lazy state pending: " & Boolean'Image ((FPCCR and 1) = 1));
      Ada.Text_IO.Put_Line ("lazy area in the window: "
                            & Boolean'Image (Integer_Address (FPCAR) < Lazy_Probe.Window_Top));
      Ada.Text_IO.Put_Line ("value:" & Float'Image (Lazy_Probe.Value));
      --  After the first FP instruction (inside Float'Image): what the core did
      --  with the lazy save that met the window - abandoned it (LSPACT clear,
      --  MLSPERR), the fault pended behind this handler, no escalation
      Ada.Text_IO.Put_Line ("lazy save abandoned: " & Boolean'Image ((FPCCR and 1) = 0 and (CFSR and 16#20#) /= 0));
      Ada.Text_IO.Put_Line ("fault pended, not escalated: "
                            & Boolean'Image ((SHCSR and 16#2000#) /= 0 and (HFSR and 16#4000_0000#) = 0));
      Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
      loop
         null;
      end loop;
   end Last_Chance_Handler;

end Test_LCH;
