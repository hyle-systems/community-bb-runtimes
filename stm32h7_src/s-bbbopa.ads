------------------------------------------------------------------------------
--                                                                          --
--                  GNAT RUN-TIME LIBRARY (GNARL) COMPONENTS                --
--                                                                          --
--            S Y S T E M . B B . B O A R D _ P A R A M E T E R S           --
--                                                                          --
--                                  S p e c                                 --
--                                                                          --
--                    Copyright (C) 2012-2016, AdaCore                      --
--                    Copyright (C) 2026, Hyle Systems S.R.L.               --
--                                                                          --
-- GNAT is free software;  you can  redistribute it  and/or modify it under --
-- terms of the  GNU General Public License as published  by the Free Soft- --
-- ware  Foundation;  either version 3,  or (at your option) any later ver- --
-- sion.  GNAT is distributed in the hope that it will be useful, but WITH- --
-- OUT ANY WARRANTY;  without even the  implied warranty of MERCHANTABILITY --
-- or FITNESS FOR A PARTICULAR PURPOSE.                                     --
--                                                                          --
-- As a special exception under Section 7 of GPL version 3, you are granted --
-- additional permissions described in the GCC Runtime Library Exception,   --
-- version 3.1, as published by the Free Software Foundation.               --
--                                                                          --
-- You should have received a copy of the GNU General Public License and    --
-- a copy of the GCC Runtime Library Exception along with this program;     --
-- see the files COPYING3 and COPYING.RUNTIME respectively.  If not, see    --
-- <http://www.gnu.org/licenses/>.                                          --
--                                                                          --
-- GNAT was originally developed  by the GNAT team at  New York University. --
-- Extensive contributions were provided by Ada Core Technologies Inc.      --
--                                                                          --
-- The port of GNARL to bare board targets was initially developed by the   --
-- Real-Time Systems Group at the Technical University of Madrid.           --
--                                                                          --
------------------------------------------------------------------------------
pragma Restrictions (No_Elaboration_Code);

--  This package defines board parameters for the stm32h7xx family
--  (STM32H723/725/730/733/735, reference manual RM0468). Every frequency is
--  computed at compile time from the crate configuration; the clock tree is
--  RM0468 section 8.3: a PLL1 fed by HSE or HSI, the system clock divided by
--  D1CPRE into the CPU clock, then by HPRE into the AXI/AHB clock, then by
--  the APB prescalers.

with STM32H7xx_Runtime_Config;

package System.BB.Board_Parameters is
   pragma Pure;

   package Config renames STM32H7xx_Runtime_Config;

   --------------------
   -- Hardware clock --
   --------------------

   HSI_Base_Freq : constant := 64_000_000;
   --  hsi_ck is 64 MHz, optionally divided by HSIDIV (RM0468 8.7.2)

   CSI_Freq : constant := 4_000_000;
   LSE_Freq : constant := 32_768;
   LSI_Freq : constant := 32_000;  --  about; see the datasheet
   HSE_Freq : constant := Config.HSE_Clock_Frequency;

   HSI_Freq : constant :=
     HSI_Base_Freq / (case Config.HSI_Div is
                        when Config.DIV1 => 1,
                        when Config.DIV2 => 2,
                        when Config.DIV4 => 4,
                        when Config.DIV8 => 8);

   ----------
   -- PLL1 --
   ----------

   --  PLL1 limits, RM0468 8.5.5: the input (after the M divider) 1 .. 16 MHz;
   --  the VCO 192 .. 836 MHz in the wide range (PLL1VCOSEL = 0) or
   --  150 .. 420 MHz in the medium range (= 1).

   type PLL_Input_Range      is range   1_000_000 ..  16_000_000;
   type PLL_VCO_Wide_Range   is range 192_000_000 .. 836_000_000;
   type PLL_VCO_Medium_Range is range 150_000_000 .. 420_000_000;

   PLL_Src_Freq : constant :=
     (case Config.PLL_Src is
        when Config.HSE => HSE_Freq,
        when Config.HSI => HSI_Freq);

   --  The input after M, for its range only: the limits are checked
   --  exactly against PLL_Src_Freq and M (setup_pll.adb), and the outputs
   --  are computed from the source with one division each, so that an M
   --  that does not divide the source does not truncate the input before
   --  N multiplies it (25 MHz / 3 x 60 is 500 MHz, not 499 999 980 Hz -
   --  the runtime's clock would gain 3.5 ms a day).
   PLL_IN_Freq : constant := PLL_Src_Freq / Config.PLL_M_Div;

   PLL_VCO_Freq : constant :=
     PLL_Src_Freq * Config.PLL_N_Mul / Config.PLL_M_Div;

   PLL_P_Freq : constant :=
     PLL_Src_Freq * Config.PLL_N_Mul
       / (Config.PLL_M_Div * Config.PLL_P_Div);
   PLL_Q_Freq : constant :=
     PLL_Src_Freq * Config.PLL_N_Mul
       / (Config.PLL_M_Div * Config.PLL_Q_Div);
   PLL_R_Freq : constant :=
     PLL_Src_Freq * Config.PLL_N_Mul
       / (Config.PLL_M_Div * Config.PLL_R_Div);

   ------------------
   -- System clock --
   ------------------

   SYSCLK_Freq : constant :=
     (case Config.SYSCLK_Src is
        when Config.HSI  => HSI_Freq,
        when Config.CSI  => CSI_Freq,
        when Config.HSE  => HSE_Freq,
        when Config.PLL1 => PLL_P_Freq);

   CPU_Clock_Freq : constant :=
     SYSCLK_Freq / (case Config.D1CPRE is
                      when Config.DIV1   => 1,
                      when Config.DIV2   => 2,
                      when Config.DIV4   => 4,
                      when Config.DIV8   => 8,
                      when Config.DIV16  => 16,
                      when Config.DIV64  => 64,
                      when Config.DIV128 => 128,
                      when Config.DIV256 => 256,
                      when Config.DIV512 => 512);
   --  sys_d1cpre_ck, the Cortex-M7 clock (c_ck), which also clocks SysTick

   HCLK_Freq : constant :=
     CPU_Clock_Freq / (case Config.HPRE is
                         when Config.DIV1   => 1,
                         when Config.DIV2   => 2,
                         when Config.DIV4   => 4,
                         when Config.DIV8   => 8,
                         when Config.DIV16  => 16,
                         when Config.DIV64  => 64,
                         when Config.DIV128 => 128,
                         when Config.DIV256 => 256,
                         when Config.DIV512 => 512);
   --  rcc_hclk, the AXI and AHB clock (also the embedded flash clock)

   APB3_Freq : constant :=
     HCLK_Freq / (case Config.D1PPRE is
                    when Config.DIV1  => 1,
                    when Config.DIV2  => 2,
                    when Config.DIV4  => 4,
                    when Config.DIV8  => 8,
                    when Config.DIV16 => 16);

   APB1_Freq : constant :=
     HCLK_Freq / (case Config.D2PPRE1 is
                    when Config.DIV1  => 1,
                    when Config.DIV2  => 2,
                    when Config.DIV4  => 4,
                    when Config.DIV8  => 8,
                    when Config.DIV16 => 16);

   APB2_Freq : constant :=
     HCLK_Freq / (case Config.D2PPRE2 is
                    when Config.DIV1  => 1,
                    when Config.DIV2  => 2,
                    when Config.DIV4  => 4,
                    when Config.DIV8  => 8,
                    when Config.DIV16 => 16);

   APB4_Freq : constant :=
     HCLK_Freq / (case Config.D3PPRE is
                    when Config.DIV1  => 1,
                    when Config.DIV2  => 2,
                    when Config.DIV4  => 4,
                    when Config.DIV8  => 8,
                    when Config.DIV16 => 16);

   Main_Clock_Frequency : constant Positive := CPU_Clock_Freq;
   --  SysTick runs on the processor clock (PM0253 4.4.5)

end System.BB.Board_Parameters;
