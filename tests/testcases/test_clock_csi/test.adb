--  test_clock_reference's program, which explains it, for the 4 MHz CSI
--  point that opt.py configures; only the crystal criterion differs.

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

   RCC_D2CCIP2R := (RCC_D2CCIP2R and not (7 * 2 ** 28)) or (3 * 2 ** 28);
   RCC_APB1LENR := RCC_APB1LENR or 2 ** 9;                                 -- LPTIM1EN
   Dummy := RCC_APB1LENR;
   LPTIM1_CFGR := 0;                    -- internal clock (the kernel clock), /1
   LPTIM1_CR := 1;                      -- ENABLE
   LPTIM1_ARR := 16#FFFF#;
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

   --  The CSI is an internal RC oscillator: 8 %, not the other points' 2 %.
   Ratio := Long_Float (Sum) / (LSE_Hz * Long_Float (To_Duration (T1 - T0)));
   Ada.Text_IO.Put_Line
     ("runtime second against the crystal, within 8 %: "
      & Boolean'Image (abs (Ratio - 1.0) < 0.08));

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
