--  test_dma_cache's buffers, in SRAM1/SRAM2: the start-up enables their
--  clocks, and the default memory map makes them write-back cacheable.

with Interfaces; use Interfaces;

package Dma_Buffers is

   Words : constant := 256;  --  1 KB per buffer

   type Word_Buffer is array (1 .. Words) of Unsigned_32
     with Volatile_Components;

   Source : Word_Buffer
     with Alignment => 32, Linker_Section => ".sram12";
   Destination : Word_Buffer
     with Alignment => 32, Linker_Section => ".sram12";

end Dma_Buffers;
