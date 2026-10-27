--  A record with default components in .sram12: GNAT initialises it with
--  elaboration code, which writes SRAM1/SRAM2 before the main program runs -
--  so their clocks must be on by then (the start-up enables them when the
--  section is not empty).

with Interfaces; use Interfaces;

package Elaborated is

   type Defaulted is record
      A : Unsigned_32 := 16#1234_5678#;
      B : Unsigned_32 := 16#9ABC_DEF0#;
   end record;

   D12 : Defaulted with Linker_Section => ".sram12";

end Elaborated;
