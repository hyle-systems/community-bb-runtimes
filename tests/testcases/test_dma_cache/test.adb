--  Checks DMA1 stream 0 memory-to-memory copies between two cached buffers
--  in the AXI SRAM. Without maintenance the CPU reads stale data: the
--  destination's lines and the source's writes sit in the cache. With the
--  source cleaned before each transfer, the destination invalidated after
--  it, and the barriers of errata ES0491 2.1.4 (DSB before, DSB-DMB-ISB
--  after), every word arrives.

with Ada.Text_IO;         use Ada.Text_IO;
with Interfaces;          use Interfaces;
with System;
with System.Machine_Code; use System.Machine_Code;
with System.Storage_Elements;

with Dma_Buffers; use Dma_Buffers;

procedure Test is
   --  DCCMVAC and DCIMVAC are in PM0253.
   RCC_AHB1ENR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#5802_44D8#);
   DMA_LISR    : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4002_0000#);
   DMA_LIFCR   : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4002_0008#);
   DMA_S0CR    : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4002_0010#);
   DMA_S0NDTR  : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4002_0014#);
   DMA_S0PAR   : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4002_0018#);
   DMA_S0M0AR  : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4002_001C#);
   DMA_S0FCR   : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4002_0024#);
   DCIMVAC     : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_EF5C#);
   DCCMVAC     : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_EF68#);
   SCB_CCR     : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_ED14#);

   DMA1_Enable : constant Unsigned_32 := 1;
   S_EN        : constant Unsigned_32 := 1;
   S_DIR_M2M   : constant Unsigned_32 := Shift_Left (2#10#, 6);
   S_PINC      : constant Unsigned_32 := Shift_Left (1, 9);
   S_MINC      : constant Unsigned_32 := Shift_Left (1, 10);
   S_PSIZE_32  : constant Unsigned_32 := Shift_Left (2#10#, 11);
   S_MSIZE_32  : constant Unsigned_32 := Shift_Left (2#10#, 13);
   F_DMDIS     : constant Unsigned_32 := Shift_Left (1, 2);
   F_FTH_FULL  : constant Unsigned_32 := 2#11#;
   S0_Flags    : constant Unsigned_32 := 2#11_1101#;
   TCIF0       : constant Unsigned_32 := Shift_Left (1, 5);
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
      DMA_S0CR := 0;
      while (DMA_S0CR and S_EN) /= 0 loop
         null;
      end loop;
      DMA_LIFCR  := S0_Flags;
      DMA_S0PAR  := Addr (Source);
      DMA_S0M0AR := Addr (Destination);
      DMA_S0NDTR := Words;
      DMA_S0FCR  := F_DMDIS or F_FTH_FULL;
      DMA_S0CR   := S_DIR_M2M or S_PINC or S_MINC or S_PSIZE_32 or S_MSIZE_32;
      DMA_S0CR   := DMA_S0CR or S_EN;
      while (DMA_LISR and TCIF0) = 0 or else DMA_S0NDTR /= 0 loop
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

   --  Run longer, the same measurement found all 1 000 unmaintained
   --  transfers stale and no error in 100 000 maintained ones.
   Rounds_A : constant := 1_000;
   Rounds_B : constant := 10_000;
   Stale_A, Errors_B : Natural := 0;
begin
   RCC_AHB1ENR := RCC_AHB1ENR or DMA1_Enable;
   Put_Line ("data cache on: " & Boolean'Image ((SCB_CCR and CCR_DC) /= 0));

   --  Phase A, without maintenance: only the first transfer, before the
   --  destination's lines are cached, may land correct.
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
