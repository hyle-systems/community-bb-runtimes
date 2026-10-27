--  Two 1 KB buffers in SRAM4 (section .sram4, in the D3 domain, the only
--  RAM the BDMA reaches), which the data cache holds as write-back memory
--  under the default memory map, aligned
--  to the 32-byte cache line so that cleaning or invalidating them touches
--  no neighbour. Library level, as Linker_Section requires.

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
