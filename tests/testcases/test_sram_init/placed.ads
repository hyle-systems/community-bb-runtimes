--  Objects with initial values in the RAMs a DMA reaches, which GNAT emits
--  as static data - no elaboration code (the restriction below), so nothing
--  but the start-up's copy of the section's image can give them their
--  values: a null access by default, a table, a record aggregate.

pragma Restrictions (No_Elaboration_Code);

with Interfaces; use Interfaces;

package Placed is

   type Int_Ptr is access all Integer;

   type Rec is record
      A : Unsigned_32;
      P : Int_Ptr;
   end record;

   type Table is array (0 .. 3) of Unsigned_32;

   type Buffer is array (0 .. 255) of Unsigned_32;

   Target : aliased Integer := 0;   --  a non-null access for the overwrite

   P12 : Int_Ptr with Volatile, Linker_Section => ".sram12";
   T12 : Table := (1, 2, 3, 4) with Volatile, Linker_Section => ".sram12";
   R4  : Rec := (A => 16#1234_5678#, P => null) with Linker_Section => ".sram4";
   Z   : Buffer with Volatile, Linker_Section => ".axisram_bss";

end Placed;
