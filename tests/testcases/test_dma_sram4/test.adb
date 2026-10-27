--  test_dma_cache's measurement in SRAM4 with the BDMA (RM0468 16): channel
--  0, memory to memory, between two buffers in .sram4. Without cache
--  maintenance the CPU
--  reads stale data (the destination's lines are in the cache, the source's
--  writes sit in the cache); with the source cleaned before the transfer and
--  the destination invalidated after it, with the barriers of errata ES0491
--  2.1.4 (DSB before, DSB-DMB-ISB after), every word arrives. The same
--  measurement as the family's row 8 (1 000 of 1 000 stale, 0 errors in
--  100 000), shortened to 10 000 maintained transfers for the gate.
--  Registers: RCC_AHB4ENR (0x5802_44E0) bit 21 BDMAEN; the BDMA at
--  0x5802_5400 (RM0468 Table 7): ISR 0x00 (TCIF0 bit 1), IFCR 0x04 (CGIF0
--  bit 0), CCR0 0x08 (EN 0, DIR 4, PINC 6, MINC 7, PSIZE 9:8, MSIZE 11:10,
--  MEM2MEM 14), CNDTR0 0x0C, CPAR0 0x10, CM0AR0 0x14 (RM0468 16.6); with
--  DIR = 0 in memory-to-memory mode the source is CPAR, the destination CM0AR;
--  DCCMVAC 0xE000_EF68, DCIMVAC 0xE000_EF5C (PM0253).

with Ada.Text_IO;         use Ada.Text_IO;
with Interfaces;          use Interfaces;
with System;
with System.Machine_Code; use System.Machine_Code;
with System.Storage_Elements;

with Dma_Buffers; use Dma_Buffers;

procedure Test is
   RCC_AHB4ENR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#5802_44E0#);
   BDMA_ISR    : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#5802_5400#);
   BDMA_IFCR   : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#5802_5404#);
   BDMA_CCR0   : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#5802_5408#);
   BDMA_CNDTR0 : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#5802_540C#);
   BDMA_CPAR0  : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#5802_5410#);
   BDMA_CM0AR0 : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#5802_5414#);
   DCIMVAC     : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_EF5C#);
   DCCMVAC     : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_EF68#);
   SCB_CCR     : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_ED14#);

   BDMA_Enable : constant Unsigned_32 := Shift_Left (1, 21);
   C_EN        : constant Unsigned_32 := 1;
   C_PINC      : constant Unsigned_32 := Shift_Left (1, 6);
   C_MINC      : constant Unsigned_32 := Shift_Left (1, 7);
   C_PSIZE_32  : constant Unsigned_32 := Shift_Left (2#10#, 8);
   C_MSIZE_32  : constant Unsigned_32 := Shift_Left (2#10#, 10);
   C_MEM2MEM   : constant Unsigned_32 := Shift_Left (1, 14);
   CGIF0       : constant Unsigned_32 := 1;
   TCIF0       : constant Unsigned_32 := Shift_Left (1, 1);
   CCR_DC      : constant Unsigned_32 := Shift_Left (1, 16);

   Line_Bytes : constant := 32;
   Lines      : constant := Words * 4 / Line_Bytes;

   function Addr (B : Word_Buffer) return Unsigned_32 is
     (Unsigned_32 (System.Storage_Elements.To_Integer (B'Address)));

   function Pattern (Round, K : Natural) return Unsigned_32 is
     (Unsigned_32 (Round) * 16#0101_0101# + Unsigned_32 (K) * 16#1_0001#);

   procedure Clean (B : Word_Buffer) is
      A : constant Unsigned_32 := Addr (B);
   begin
      for L in 0 .. Lines - 1 loop
         DCCMVAC := A + Unsigned_32 (L * Line_Bytes);
      end loop;
      Asm ("dsb" & ASCII.LF & "isb", Volatile => True);
   end Clean;

   procedure Invalidate (B : Word_Buffer) is
      A : constant Unsigned_32 := Addr (B);
   begin
      for L in 0 .. Lines - 1 loop
         DCIMVAC := A + Unsigned_32 (L * Line_Bytes);
      end loop;
      Asm ("dsb" & ASCII.LF & "dmb" & ASCII.LF & "isb", Volatile => True);
   end Invalidate;

   procedure Transfer is
   begin
      BDMA_CCR0 := 0;
      while (BDMA_CCR0 and C_EN) /= 0 loop
         null;
      end loop;
      BDMA_IFCR   := CGIF0;
      BDMA_CPAR0  := Addr (Source);
      BDMA_CM0AR0 := Addr (Destination);
      BDMA_CNDTR0 := Words;
      BDMA_CCR0   := C_MEM2MEM or C_PINC or C_MINC or C_PSIZE_32 or C_MSIZE_32;
      BDMA_CCR0   := BDMA_CCR0 or C_EN;
      while (BDMA_ISR and TCIF0) = 0 or else BDMA_CNDTR0 /= 0 loop
         null;
      end loop;
   end Transfer;

   function Bad_Words (Round : Natural) return Natural is
      Bad : Natural := 0;
   begin
      for K in Destination'Range loop
         if Destination (K) /= Pattern (Round, K) then
            Bad := Bad + 1;
         end if;
      end loop;
      return Bad;
   end Bad_Words;

   Rounds_A : constant := 1_000;
   Rounds_B : constant := 10_000;
   Stale_A, Errors_B : Natural := 0;
begin
   RCC_AHB4ENR := RCC_AHB4ENR or BDMA_Enable;
   Put_Line ("data cache on: " & Boolean'Image ((SCB_CCR and CCR_DC) /= 0));

   --  Phase A: no maintenance. The first transfer finds the destination's
   --  lines not yet cached and may land correct; from then on the CPU reads
   --  stale lines.
   for Round in 1 .. Rounds_A loop
      for K in Source'Range loop
         Source (K) := Pattern (Round, K);
      end loop;
      Transfer;
      if Bad_Words (Round) > 0 then
         Stale_A := Stale_A + 1;
      end if;
   end loop;
   Put_Line ("without maintenance, stale transfers seen: " & Boolean'Image (Stale_A > 0));

   --  Phase B: clean the source, transfer, invalidate the destination.
   Clean (Source);
   Invalidate (Destination);
   for Round in 1 .. Rounds_B loop
      for K in Source'Range loop
         Source (K) := Pattern (Round, K);
      end loop;
      Clean (Source);
      Transfer;
      Invalidate (Destination);
      if Bad_Words (Round) > 0 then
         Errors_B := Errors_B + 1;
      end if;
   end loop;
   Put_Line ("with clean / invalidate / barriers, transfers in error:"
             & Natural'Image (Errors_B) & " of" & Natural'Image (Rounds_B));
   Put_Line ("===TEST COMPLETE===");
end Test;
