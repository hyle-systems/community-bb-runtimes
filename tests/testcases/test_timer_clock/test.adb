--  The runtime's derived peripheral clocks against hardware: TIM2 (APB1,
--  32-bit) and TIM1 (APB2, 16-bit, prescaled by 65536) run free while the
--  runtime's clock measures the elapsed time; each count rate must equal the
--  timer kernel clock, which is twice the APB clock the runtime computes
--  when the APB prescaler is 2 (RM0468 8.7.6 TIMPRE = 0: rcc_hclk1 for
--  D2PPREx of 1 or 2). A wrong APB divider or a missed doubling shows as a
--  factor of two. Clock enables: RCC_APB1LENR bit 0 (TIM2EN), RCC_APB2ENR
--  bit 0 (TIM1EN); the timers' CR1/EGR/CNT/PSC/ARR at 0x00/0x14/0x24/0x28/
--  0x2C (vendor SVD).

with Ada.Real_Time; use Ada.Real_Time;
with Ada.Text_IO;
with Interfaces; use Interfaces;
with System;
with System.BB.Board_Parameters;

procedure Test is
   RCC_APB1LENR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#5802_44E8#);
   RCC_APB2ENR  : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#5802_44F0#);

   TIM2_CR1 : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4000_0000#);
   TIM2_EGR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4000_0014#);
   TIM2_CNT : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4000_0024#);
   TIM2_PSC : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4000_0028#);
   TIM2_ARR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4000_002C#);

   TIM1_CR1 : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4001_0000#);
   TIM1_EGR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4001_0014#);
   TIM1_CNT : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4001_0024#);
   TIM1_PSC : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4001_0028#);
   TIM1_ARR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4001_002C#);

   APB1 : constant := System.BB.Board_Parameters.APB1_Freq;
   APB2 : constant := System.BB.Board_Parameters.APB2_Freq;

   Dummy : Unsigned_32 with Volatile;
   T0, T1 : Time;
   C2_0, C2_1, C1_0, C1_1 : Unsigned_32;

   --  Ada's conversion to Integer rounds to nearest: no "+ 0.5" here. The C
   --  idiom double-rounds, and with a measured ratio within 1e-6 of one it
   --  flipped the line between 100 and 101 from run to run.
   function Ratio_X1000 (Counts : Unsigned_32; Per_Second : Long_Float; Elapsed : Duration)
     return Integer
   is (Integer (Long_Float (Counts) / (Per_Second * Long_Float (Elapsed)) * 1000.0));
begin
   RCC_APB1LENR := RCC_APB1LENR or 1;
   RCC_APB2ENR  := RCC_APB2ENR or 1;
   Dummy := RCC_APB2ENR;                -- the enables take a bus cycle to act

   TIM2_PSC := 0;        TIM2_ARR := 16#FFFF_FFFF#;  TIM2_EGR := 1;  TIM2_CR1 := 1;
   TIM1_PSC := 16#FFFF#; TIM1_ARR := 16#FFFF#;       TIM1_EGR := 1;  TIM1_CR1 := 1;

   delay until Clock + Milliseconds (10);   -- let both settle after UG

   T0 := Clock;  C2_0 := TIM2_CNT;  C1_0 := TIM1_CNT;
   delay until T0 + Seconds (1);
   T1 := Clock;  C2_1 := TIM2_CNT;  C1_1 := TIM1_CNT;

   Ada.Text_IO.Put_Line
     ("TIM2 (APB1 x 2) ratio x1000 ="
      & Integer'Image (Ratio_X1000 (C2_1 - C2_0, 2.0 * Long_Float (APB1), To_Duration (T1 - T0))));
   Ada.Text_IO.Put_Line
     ("TIM1 (APB2 x 2 / 65536) ratio x1000 ="
      & Integer'Image (Ratio_X1000 ((C1_1 - C1_0) and 16#FFFF#, 2.0 * Long_Float (APB2) / 65536.0,
                                    To_Duration (T1 - T0))));
   Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
end Test;
