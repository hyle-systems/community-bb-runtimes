with Ada.Text_IO;
with System.Machine_Code;
with System.Storage_Elements; use System.Storage_Elements;

package body ECC_Probe is

   use Interfaces;

   -----------
   -- Clear --
   -----------

   procedure Clear (Monitor : System.Address) is
      SR : Word with Volatile, Import, Address => Monitor;
   begin
      SR := 0;
   end Clear;

   -----------
   -- Flags --
   -----------

   function Flags (Monitor : System.Address) return Word is
      SR : Word with Volatile, Import, Address => Monitor;
   begin
      return SR and 7;
   end Flags;

   -----------
   -- Touch --
   -----------

   procedure Touch (First : System.Address; Bytes : Positive) is
      Offset : Storage_Offset := 0;
      Sink   : Word with Volatile;
   begin
      while Offset + 8 <= Storage_Offset (Bytes) loop
         declare
            B  : Unsigned_8  with Volatile, Import, Address => First + Offset;
            H  : Unsigned_16 with Volatile, Import, Address => First + Offset + 4;
            W0 : Word        with Volatile, Import, Address => First + Offset;
            W1 : Word        with Volatile, Import, Address => First + Offset + 4;
         begin
            B := 16#5A#;
            H := 16#A55A#;
            Sink := W0;
            Sink := W1;
         end;
         Offset := Offset + 8;
      end loop;
   end Touch;

   ----------------------
   -- Clean_Data_Cache --
   ----------------------

   procedure Clean_Data_Cache (First : System.Address; Bytes : Positive) is
      DCCMVAC : Word with Volatile, Import,
        Address => System'To_Address (16#E000_EF68#);
      Line    : Integer_Address := To_Integer (First) and not 31;
      Last    : constant Integer_Address := To_Integer (First) + Integer_Address (Bytes) - 1;
   begin
      System.Machine_Code.Asm ("dsb", Volatile => True);
      while Line <= Last loop
         DCCMVAC := Word (Line);
         Line := Line + 32;
      end loop;
      System.Machine_Code.Asm ("dsb" & ASCII.LF & "isb", Volatile => True);
   end Clean_Data_Cache;

   ------------
   -- Report --
   ------------

   procedure Report (Name : String; Monitor : System.Address) is
   begin
      Ada.Text_IO.Put_Line (Name & ":" & Word'Image (Flags (Monitor)));
   end Report;

end ECC_Probe;
