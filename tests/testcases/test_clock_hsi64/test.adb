--  The runtime's second against the board's 32.768 kHz crystal, the one
--  clock on the NUCLEO-H723ZG that does not descend from the PLL: LPTIM1 is
--  clocked from the LSE (RCC_D2CCIP2R LPTIM1SEL = 011) and counted over one
--  second of Ada.Real_Time. A clock point that came up wrong - a PLL
--  multiplier, a voltage scaling, a prescaler - shows as a ratio far from
--  one; the ST-LINK's 8 MHz, which the HSE path inherits, is about one
--  percent off, so the criterion is two percent. The counter is 16 bits
--  wide, so it is sampled every 100 ms and the increments summed: a single
--  difference over the second would wrap, and a clock an odd integer factor
--  slow would read as one. The LSE needs the backup domain unlocked
--  (PWR_CR1 DBP, with a dummy read after it) and up to a few seconds to
--  start the first time; it stays on across resets.
--
--  Then the end state the start-up left for this point, against RM0468
--  Table 16 computed here from the AXI clock, not taken from the runtime:
--  the voltage scaling applied (PWR_CSR1 ACTVOS, equal to PWR_D3CR VOS)
--  and the flash wait states and programming delay (FLASH_ACR LATENCY,
--  WRHIGHFREQ) for that scaling and that clock.
--
--  Registers: PWR_CR1 0x5802_4800 (DBP bit 8); PWR_CSR1 0x5802_4804
--  (ACTVOS 15:14); PWR_D3CR 0x5802_4818 (VOS 15:14: 00 VOS0, 11 VOS1,
--  10 VOS2, 01 VOS3); FLASH_ACR 0x5200_2000 (LATENCY 3:0, WRHIGHFREQ
--  5:4); RCC_BDCR 0x5802_4470 (LSEON bit 0, LSERDY bit 1); RCC_D2CCIP2R
--  0x5802_4454; RCC_APB1LENR 0x5802_44E8 (LPTIM1EN bit 9); LPTIM1
--  0x4000_2400: CFGR 0x0C, CR 0x10 (ENABLE bit 0, CNTSTRT bit 2), ARR 0x18
--  (written enabled; ISR ARROK bit 4 then set, cleared through ICR), CNT
--  0x1C (read until two consecutive reads agree). RM0468 4.9.1, 6.8.1,
--  6.8.2, 6.8.6, 8.7.20, 8.7.25, 8.7.44, 48.7.

with Ada.Real_Time; use Ada.Real_Time;
with Ada.Text_IO;
with Interfaces; use Interfaces;
with System;
with System.BB.Board_Parameters;

procedure Test is
   PWR_CR1      : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#5802_4800#);
   PWR_CSR1     : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#5802_4804#);
   PWR_D3CR     : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#5802_4818#);
   FLASH_ACR    : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#5200_2000#);
   RCC_BDCR     : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#5802_4470#);
   RCC_D2CCIP2R : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#5802_4454#);
   RCC_APB1LENR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#5802_44E8#);
   LPTIM1_ISR   : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4000_2400#);
   LPTIM1_ICR   : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4000_2404#);
   LPTIM1_CFGR  : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4000_240C#);
   LPTIM1_CR    : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4000_2410#);
   LPTIM1_ARR   : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4000_2418#);
   LPTIM1_CNT   : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4000_241C#);

   LSE_Hz : constant := 32_768.0;

   function Count return Unsigned_32 is
      A, B : Unsigned_32;
   begin
      loop
         A := LPTIM1_CNT and 16#FFFF#;
         B := LPTIM1_CNT and 16#FFFF#;
         exit when A = B;
      end loop;
      return A;
   end Count;

   type Scaling is (VOS0, VOS1, VOS2, VOS3);

   function Decode (Code : Unsigned_32) return Scaling is
     (case Code is
        when 2#00#  => VOS0,
        when 2#11#  => VOS1,
        when 2#10#  => VOS2,
        when others => VOS3);

   --  RM0468 Table 16: the upper AXI clock of 0, 1 and 2 wait states per
   --  scaling (3 wait states only at VOS0, to 275 MHz)
   type Bounds is array (0 .. 2) of Natural;
   Upper : constant array (Scaling) of Bounds :=
     (VOS0 => (70_000_000, 140_000_000, 210_000_000),
      VOS1 => (67_000_000, 133_000_000, 200_000_000),
      VOS2 => (50_000_000, 100_000_000, 150_000_000),
      VOS3 => (35_000_000,  70_000_000,  85_000_000));

   function Expected_Latency (S : Scaling; HCLK : Natural) return Unsigned_32 is
   begin
      for WS in Bounds'Range loop
         if HCLK <= Upper (S) (WS) then
            return Unsigned_32 (WS);
         end if;
      end loop;
      return 3;
   end Expected_Latency;

   Dummy : Unsigned_32 with Volatile;
   LSE_Ready : Boolean := False;
   T0, T1, Next : Time;
   Last, Now_Count, Sum : Unsigned_32;
   Ratio : Long_Float;
begin
   Ada.Text_IO.Put_Line
     ("configured CPU clock MHz =" & Integer'Image (System.BB.Board_Parameters.CPU_Clock_Freq / 1_000_000));

   PWR_CR1 := PWR_CR1 or 2 ** 8;        -- DBP
   Dummy := PWR_CR1;
   RCC_BDCR := RCC_BDCR or 1;           -- LSEON
   declare
      Give_Up : constant Time := Clock + Seconds (5);
   begin
      while Clock < Give_Up loop
         if (RCC_BDCR and 2) = 2 then  -- LSERDY
            LSE_Ready := True;
            exit;
         end if;
      end loop;
   end;
   Ada.Text_IO.Put_Line ("LSE ready: " & Boolean'Image (LSE_Ready));

   RCC_D2CCIP2R := (RCC_D2CCIP2R and not (7 * 2 ** 28)) or (3 * 2 ** 28);   -- lse_ck
   RCC_APB1LENR := RCC_APB1LENR or 2 ** 9;                                 -- LPTIM1EN
   Dummy := RCC_APB1LENR;               -- the enable takes a bus cycle to act: read it back first
   LPTIM1_CFGR := 0;                    -- internal clock (the kernel clock), /1
   LPTIM1_CR := 1;                      -- ENABLE
   LPTIM1_ARR := 16#FFFF#;              -- reaches the timer after a few kernel clocks: wait for ARROK
   while (LPTIM1_ISR and 16) = 0 loop
      null;
   end loop;
   LPTIM1_ICR := 16;
   LPTIM1_CR := 1 or 4;                 -- CNTSTRT

   delay until Clock + Milliseconds (100);
   T0 := Clock;  Last := Count;  Sum := 0;  Next := T0;
   for Step in 1 .. 10 loop
      Next := Next + Milliseconds (100);
      delay until Next;
      Now_Count := Count;
      Sum := Sum + ((Now_Count - Last) and 16#FFFF#);
      Last := Now_Count;
   end loop;
   T1 := Clock;

   Ratio := Long_Float (Sum) / (LSE_Hz * Long_Float (To_Duration (T1 - T0)));
   Ada.Text_IO.Put_Line
     ("runtime second against the crystal, within 2 %: "
      & Boolean'Image (abs (Ratio - 1.0) < 0.02));

   declare
      Applied : constant Scaling := Decode (Shift_Right (PWR_CSR1, 14) and 3);
      Asked   : constant Scaling := Decode (Shift_Right (PWR_D3CR, 14) and 3);
      WS      : constant Unsigned_32 :=
        Expected_Latency (Applied, System.BB.Board_Parameters.HCLK_Freq);
   begin
      Ada.Text_IO.Put_Line
        ("voltage scaling applied: " & Scaling'Image (Applied)
         & ", as asked: " & Boolean'Image (Applied = Asked));
      Ada.Text_IO.Put_Line
        ("flash wait states and programming delay per RM0468 Table 16: "
         & Boolean'Image ((FLASH_ACR and 16#F#) = WS
                          and then (Shift_Right (FLASH_ACR, 4) and 3) = WS));
   end;
   Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
end Test;
