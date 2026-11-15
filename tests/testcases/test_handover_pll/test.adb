--  A bootloader that leaves PLL2 (or PLL3) running from the HSI. PLLSRC can
--  be written only when all PLLs are disabled (RM0468 8.7.10), and HSIDIV
--  cannot change while an enabled PLL takes the HSI (8.7.2). A start-up that
--  turns off PLL1 alone writes PLLSRC and HSIDIV into the void: PLL1 then
--  locks on the HSI with the crystal's M and N, or never locks, and every
--  compile-time frequency is wrong with no error. The first pass sets up that
--  state and hands over; the second checks the PLL source and the runtime's
--  second against the LSE crystal, as test_clock_reference measures it.

with Ada.Real_Time; use Ada.Real_Time;
with Ada.Text_IO;
with Interfaces; use Interfaces;
with System;

with Handover;

procedure Test is
   RCC_CR        : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#5802_4400#);
   RCC_CFGR      : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#5802_4410#);
   RCC_PLLCKSELR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#5802_4428#);
   RCC_PLLCFGR   : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#5802_442C#);
   RCC_PLL2DIVR  : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#5802_4438#);

   --  test_clock_reference's cross-check, with the same registers: LPTIM1
   --  clocked from the LSE, counted over one second of Ada.Real_Time.
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

   procedure Cross_Check is
      Dummy     : Unsigned_32 with Volatile;
      LSE_Ready : Boolean := False;
      T0, T1    : Time;
      Next      : Time;
      Last, Now_Count, Sum : Unsigned_32;
      Ratio     : Long_Float;
   begin
      PWR_CR1 := PWR_CR1 or 2 ** 8;
      Dummy := PWR_CR1;
      RCC_BDCR := RCC_BDCR or 1;
      declare
         Give_Up : constant Time := Clock + Seconds (5);
      begin
         while Clock < Give_Up loop
            if (RCC_BDCR and 2) = 2 then
               LSE_Ready := True;
               exit;
            end if;
         end loop;
      end;
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
      delay until Clock + Milliseconds (100);
      --  Sampled every 100 ms and summed. A single reading after one second
      --  could wrap the 16-bit counter, and a runtime clock slow by an odd
      --  factor would then read as exact.
      T0 := Clock;  Last := Count;  Sum := 0;  Next := T0;
      for Step in 1 .. 10 loop
         Next := Next + Milliseconds (100);
         delay until Next;
         Now_Count := Count;
         Sum := Sum + ((Now_Count - Last) and 16#FFFF#);
         Last := Now_Count;
      end loop;
      T1 := Clock;
      Ratio := Long_Float (Sum) / (32_768.0 * Long_Float (To_Duration (T1 - T0)));
      Ada.Text_IO.Put_Line
        ("runtime second against the crystal, within 2 %: " & Boolean'Image (abs (Ratio - 1.0) < 0.02));
   end Cross_Check;

begin
   if Handover.Second_Pass then
      Ada.Text_IO.Put_Line ("second pass, after a hand-over with PLL2 running from the HSI");
      Ada.Text_IO.Put_Line ("PLL source is the HSE: " & Boolean'Image ((RCC_PLLCKSELR and 3) = 2));
      Ada.Text_IO.Put_Line ("PLL2 off: " & Boolean'Image ((RCC_CR and 2 ** 26) = 0));
      Cross_Check;
      Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
   else
      Ada.Text_IO.Put_Line ("first pass: PLL2 on from the HSI, then the hand-over");
      --  Switch the system clock to the HSI and turn PLL1 off, so that
      --  PLLSRC may be written.
      RCC_CFGR := RCC_CFGR and not 7;
      while (RCC_CFGR and 16#38#) /= 0 loop
         null;
      end loop;
      RCC_CR := RCC_CR and not (2 ** 24);
      while (RCC_CR and 2 ** 25) /= 0 loop
         null;
      end loop;
      --  PLLSRC = HSI (00) and DIVM2 = 4 put 16 MHz into PLL2; the wide VCO,
      --  the 8 .. 16 MHz input range and N = 50 make an 800 MHz VCO.
      RCC_PLLCKSELR := (RCC_PLLCKSELR and not (3 or 16#3F000#)) or (4 * 2 ** 12);
      RCC_PLLCFGR := (RCC_PLLCFGR and not (2 ** 5 or 3 * 2 ** 6)) or (3 * 2 ** 6);
      RCC_PLL2DIVR := (RCC_PLL2DIVR and not 16#1FF#) or 49;
      RCC_CR := RCC_CR or 2 ** 26;
      while (RCC_CR and 2 ** 27) = 0 loop
         null;
      end loop;
      Handover.Mark;
      Handover.Restart;
   end if;
end Test;
