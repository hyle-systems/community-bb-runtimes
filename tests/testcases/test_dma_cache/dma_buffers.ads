--  The default memory map makes the AXI SRAM write-back cacheable. The
--  buffers are aligned to the 32-byte cache line so that maintenance
--  touches no neighbour, and at library level as Linker_Section requires.

with Interfaces; use Interfaces;

package Dma_Buffers is

   Words : constant := 256;  --  1 KB per buffer

   type Word_Buffer is array (1 .. Words) of Unsigned_32
     with Volatile_Components;

   Source : Word_Buffer
     with Alignment => 32, Linker_Section => ".axisram";
   Destination : Word_Buffer
     with Alignment => 32, Linker_Section => ".axisram";

end Dma_Buffers;
