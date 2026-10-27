--  The CPU clock against the board's 32.768 kHz crystal in any profile, the
--  light one included, which has no Ada.Real_Time: the core's cycle counter
--  (DWT CYCCNT, PM0253; the DWT unlocked through its lock access register
--  and enabled through DEMCR TRCENA) counted over 32 768 periods of LPTIM1
--  clocked from the LSE, against the CPU clock the crate computed. The LSE
--  start is bounded by a cycle count too (about 5 s at the configured clock).
--  Registers as test_clock_reference's; DEMCR 0xE000_EDFC (TRCENA bit 24),
--  DWT_CTRL 0xE000_1000 (CYCCNTENA bit 0), DWT_CYCCNT 0xE000_1004, DWT_LAR
--  0xE000_1FB0.

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
   DEMCR        : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_EDFC#);
   DWT_CTRL     : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_1000#);
   DWT_CYCCNT   : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_1004#);
   DWT_LAR      : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_1FB0#);

   CPU_Hz : constant := System.BB.Board_Parameters.CPU_Clock_Freq;

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

   Dummy     : Unsigned_32 with Volatile;
   LSE_Ready : Boolean := False;
   Start, Cycles, Ticks, Last, Now_Count : Unsigned_32;
   Ratio     : Long_Float;
begin
   DEMCR := DEMCR or 2 ** 24;              --  TRCENA
   DWT_LAR := 16#C5AC_CE55#;               --  unlock
   DWT_CYCCNT := 0;
   DWT_CTRL := DWT_CTRL or 1;              --  CYCCNTENA

   PWR_CR1 := PWR_CR1 or 2 ** 8;           --  DBP
   Dummy := PWR_CR1;
   RCC_BDCR := RCC_BDCR or 1;              --  LSEON
   Start := DWT_CYCCNT;
   loop
      if (RCC_BDCR and 2) = 2 then
         LSE_Ready := True;
         exit;
      end if;
      exit when DWT_CYCCNT - Start > Unsigned_32 (CPU_Hz) * 5;
   end loop;
   Ada.Text_IO.Put_Line ("LSE ready: " & Boolean'Image (LSE_Ready));

   RCC_D2CCIP2R := (RCC_D2CCIP2R and not (7 * 2 ** 28)) or (3 * 2 ** 28);
   RCC_APB1LENR := RCC_APB1LENR or 2 ** 9;
   Dummy := RCC_APB1LENR;
   LPTIM1_CFGR := 0;
   LPTIM1_CR := 1;
   LPTIM1_ARR := 16#FFFF#;
   while (LPTIM1_ISR and 16) = 0 loop
      null;
   end loop;
   LPTIM1_ICR := 16;
   LPTIM1_CR := 1 or 4;

   --  Align on a counter edge, then count cycles over 32 768 LSE periods,
   --  summing the counter's increments (16 bits wide: read often enough)
   Last := Count;
   loop
      Now_Count := Count;
      exit when Now_Count /= Last;
   end loop;
   Start := DWT_CYCCNT;
   Last := Now_Count;
   Ticks := 0;
   while Ticks < 32_768 loop
      Now_Count := Count;
      Ticks := Ticks + ((Now_Count - Last) and 16#FFFF#);
      Last := Now_Count;
   end loop;
   Cycles := DWT_CYCCNT - Start;

   Ratio := Long_Float (Cycles) * 32_768.0 / (Long_Float (Ticks) * Long_Float (CPU_Hz));
   Ada.Text_IO.Put_Line
     ("CPU cycles over one second of the crystal against the configured clock, within 2 %: "
      & Boolean'Image (abs (Ratio - 1.0) < 0.02));
   Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
end Test;
