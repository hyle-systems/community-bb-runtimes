--  test_dma_cache's buffers, in SRAM4 (the D3 domain, the only RAM the
--  BDMA reaches), write-back cacheable under the default memory map.

with Interfaces; use Interfaces;

package Dma_Buffers is

   Words : constant := 256;  --  1 KB per buffer

   type Word_Buffer is array (1 .. Words) of Unsigned_32
     with Volatile_Components;

   Source : Word_Buffer
     with Alignment => 32, Linker_Section => ".sram4";
   Destination : Word_Buffer
     with Alignment => 32, Linker_Section => ".sram4";

end Dma_Buffers;
