--  The runtime's second against the board's 32.768 kHz crystal, the one
--  clock on the NUCLEO-H723ZG that does not descend from the PLL: LPTIM1 is
--  clocked from the LSE (RCC_D2CCIP2R LPTIM1SEL = 011) and counted over one
--  second of Ada.Real_Time. A clock point that came up wrong - a PLL
--  multiplier, a voltage scaling, a prescaler - shows as a ratio far from
--  one; the ST-LINK's 8 MHz, which the HSE path inherits, is about one
--  percent off, so the criterion is two percent. The LSE needs the backup
--  domain unlocked (PWR_CR1 DBP, with a dummy read after it) and up to a
--  few seconds to start the first time; it stays on across resets.
--  Registers: PWR_CR1 0x5802_4800 (DBP bit 8); RCC_BDCR 0x5802_4470 (LSEON
--  bit 0, LSERDY bit 1); RCC_D2CCIP2R 0x5802_4454; RCC_APB1LENR 0x5802_44E8
--  (LPTIM1EN bit 9); LPTIM1 0x4000_2400: CFGR 0x0C, CR 0x10 (ENABLE bit 0,
--  CNTSTRT bit 2), ARR 0x18 (written enabled; ISR ARROK bit 4 then set,
--  cleared through ICR), CNT 0x1C (read until two
--  consecutive reads agree). RM0468 6.8.1, 8.7.20, 8.7.25, 8.7.44, 48.7.

with Ada.Real_Time; use Ada.Real_Time;
with Ada.Text_IO;
with Interfaces; use Interfaces;
with System;
with System.BB.Board_Parameters;

procedure Test is
   PWR_CR1      : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#5802_4800#);
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

   Dummy : Unsigned_32 with Volatile;
   LSE_Ready : Boolean := False;
   T0, T1 : Time;
   C0, C1 : Unsigned_32;
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
   T0 := Clock;  C0 := Count;
   delay until T0 + Seconds (1);
   T1 := Clock;  C1 := Count;

   Ratio := Long_Float ((C1 - C0) and 16#FFFF#)
            / (LSE_Hz * Long_Float (To_Duration (T1 - T0)));
   Ada.Text_IO.Put_Line
     ("runtime second against the crystal, within 2 %: "
      & Boolean'Image (abs (Ratio - 1.0) < 0.02));
   Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
end Test;
