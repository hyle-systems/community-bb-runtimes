------------------------------------------------------------------------------
--                                                                          --
--                         GNAT RUN-TIME COMPONENTS                         --
--                                                                          --
--          Copyright (C) 2012-2025, Free Software Foundation, Inc.         --
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
------------------------------------------------------------------------------

pragma Ada_2012;
pragma Suppress (All_Checks);

--  Supply configuration, voltage scaling, flash latency and clock tree for
--  the STM32H72x/H73x line (reference manual RM0468), driven by the crate
--  configuration. The sequence follows RM0468 6.4.1 (system supply start-up),
--  4.3.8 (the flash latency raised and read back before the AXI clock rises,
--  Table 16) and 8.4 (HSE, PLL1, prescalers, system clock switch).

with Interfaces.STM32;           use Interfaces.STM32;
with Interfaces.STM32.Flash;     use Interfaces.STM32.Flash;
with Interfaces.STM32.PWR;       use Interfaces.STM32.PWR;
with Interfaces.STM32.RCC;       use Interfaces.STM32.RCC;

with System.BB.Board_Parameters; use System.BB.Board_Parameters;

with STM32H7xx_Runtime_Config;

procedure Setup_Pll is
   procedure Initialize_Clocks;
   procedure Reset_Clocks;

   package Config renames STM32H7xx_Runtime_Config;

   use type Config.PLL_Src_Kind;
   use type Config.SYSCLK_Src_Kind;
   use type Config.Voltage_Scaling_Kind;
   use type Config.HSI_Div_Kind;

   ------------------------------
   -- Clock Tree Configuration --
   ------------------------------

   PLL_P_Used : constant Boolean := Config.SYSCLK_Src = Config.PLL1;

   Activate_PLL : constant Boolean :=
     PLL_P_Used or Config.PLL_Q_Enable or Config.PLL_R_Enable;

   CSI_Used : constant Boolean := Config.SYSCLK_Src = Config.CSI;

   HSE_Used : constant Boolean :=
     Config.SYSCLK_Src = Config.HSE
     or (Activate_PLL and Config.PLL_Src = Config.HSE);

   --  Voltage scaling code for PWR_D3CR.VOS (RM0468 6.8.6):
   --  00 = VOS0, 01 = VOS3, 10 = VOS2, 11 = VOS1

   VOS_Code : constant :=
     (case Config.Voltage_Scaling is
        when Config.VOS0 => 2#00#,
        when Config.VOS1 => 2#11#,
        when Config.VOS2 => 2#10#,
        when Config.VOS3 => 2#01#);

   --  Flash wait states for the AXI clock, RM0468 Table 16; the programming
   --  delay code WRHIGHFREQ equals the wait-state count in that table.

   Flash_Latency : constant :=
     (case Config.Voltage_Scaling is
        when Config.VOS0 =>
          (if    HCLK_Freq <=  70_000_000 then 0
           elsif HCLK_Freq <= 140_000_000 then 1
           elsif HCLK_Freq <= 210_000_000 then 2
           else 3),
        when Config.VOS1 =>
          (if    HCLK_Freq <=  67_000_000 then 0
           elsif HCLK_Freq <= 133_000_000 then 1
           else 2),
        when Config.VOS2 =>
          (if    HCLK_Freq <=  50_000_000 then 0
           elsif HCLK_Freq <= 100_000_000 then 1
           else 2),
        when Config.VOS3 =>
          (if    HCLK_Freq <=  35_000_000 then 0
           elsif HCLK_Freq <=  70_000_000 then 1
           else 2));

   --  What the reset clock needs: the core runs the 64 MHz HSI with the AXI
   --  undivided until the switch (Reset_Clocks leaves it so), and the
   --  latency is written while the scaling is still the present one - VOS3
   --  after a reset (RM0468 6.6.2), whatever a bootloader left otherwise.
   --  64 MHz needs 1 wait state at VOS3 and VOS2 and at most 1 at any
   --  scaling (Table 16), so 1 whatever the target. The latency written
   --  before the switch is the larger of this and the target's; the
   --  target's follows the switch when it is the smaller (RM0468 4.3.8:
   --  when the frequency falls, the clock first, the latency after).
   Reset_Clock_Latency : constant := 1;
   Switch_Latency : constant :=
     Integer'Max (Flash_Latency, Reset_Clock_Latency);
   Lower_Latency_After : constant Boolean :=
     Flash_Latency < Switch_Latency;

   --  Maximum frequencies per voltage scaling, DS13313 Table 12: CPU 520 /
   --  400 / 300 / 170 MHz, AXI and AHB 275 / 200 / 150 / 85 MHz, APB half of
   --  the AXI maximum, for VOS0 / VOS1 / VOS2 / VOS3.

   CPU_Max : constant :=
     (case Config.Voltage_Scaling is
        when Config.VOS0 => 520_000_000,
        when Config.VOS1 => 400_000_000,
        when Config.VOS2 => 300_000_000,
        when Config.VOS3 => 170_000_000);

   HCLK_Max : constant :=
     (case Config.Voltage_Scaling is
        when Config.VOS0 => 275_000_000,
        when Config.VOS1 => 200_000_000,
        when Config.VOS2 => 150_000_000,
        when Config.VOS3 =>  85_000_000);

   --  PLL1 input range code for RCC_PLLCFGR.PLL1RGE (RM0468 8.7.11):
   --  00 = 1..2 MHz, 01 = 2..4 MHz, 10 = 4..8 MHz, 11 = 8..16 MHz

   PLL_RGE : constant :=
     (if    PLL_Src_Freq < 2_000_000 * Config.PLL_M_Div then 2#00#
      elsif PLL_Src_Freq <= 4_000_000 * Config.PLL_M_Div then 2#01#
      elsif PLL_Src_Freq <= 8_000_000 * Config.PLL_M_Div then 2#10#
      else 2#11#);

   --  The PLL1 input selects the VCO range (DS13313 6.3.11): an input of
   --  1 to 2 MHz runs the medium range, 150 .. 420 MHz with every output
   --  limited to 210 MHz (Table 40); an input of 2 to 16 MHz runs the wide
   --  range, 192 .. 836 MHz (Table 39). Exactly 2 MHz is in both tables,
   --  and RM0468 8.5.5 claims it for both VCOs in consecutive sentences
   --  ("lower or equal to 2 MHz, VCOL"; "equal or higher to 2 MHz, VCOH").
   --  ST's own CubeH7 configuration for the NUCLEO-H723ZG runs 2 MHz into
   --  the wide VCO with the 2 .. 4 MHz input code, and so does this
   --  runtime: the medium range below 2 MHz only.

   PLL_VCO_Medium : constant Boolean :=
     PLL_Src_Freq < 2_000_000 * Config.PLL_M_Div;

   PLL_Medium_Out_Max : constant :=
     (if Config.Voltage_Scaling = Config.VOS3 then 200_000_000
      else 210_000_000);

   --  Every wait below is bounded. RM0468 and the datasheet give these in
   --  microseconds (a PLL locks within 150 us, DS13313 Table 39), the HSE
   --  in milliseconds; ST's HAL bounds the PLL waits at 2 ms and the HSE
   --  at 100 ms and returns an error. The bound here is a count of polls,
   --  well above those times at the 64 MHz reset clock; on expiry the
   --  start-up parks at a label a debugger can name instead of spinning
   --  somewhere unnamed: the HSE never ready (no clock on the input, or a
   --  crystal configured as a bypass or the reverse), PLL1 never locked,
   --  or another clock state that did not come (an oscillator, the switch,
   --  the voltage scaling, a register write the hardware did not take).

   Wait_Bound : constant := 2 ** 21;

   --  The parks are start-common.S's, next to the supply's.

   procedure HSE_Not_Ready
     with No_Return, Import, Convention => C,
          External_Name => "__gnat_hse_not_ready";
   procedure PLL_Not_Locked
     with No_Return, Import, Convention => C,
          External_Name => "__gnat_pll_not_locked";
   procedure Clock_Not_Ready
     with No_Return, Import, Convention => C,
          External_Name => "__gnat_clock_not_ready";

   -----------------------
   -- Initialize_Clocks --
   -----------------------

   procedure Initialize_Clocks
   is
      -------------------------
      -- Compile-Time Checks --
      -------------------------

      pragma Compile_Time_Error
        (HSE_Used and then not Config.HSE_Bypass
           and then Config.HSE_Clock_Frequency > 48_000_000,
         "HSE_Clock_Frequency: a crystal is 4 to 48 MHz (RM0468 8.5; the"
           & " datasheet's Table 33 says 50; the manual's figure is kept);"
           & " up to 50 MHz is for an external clock, with HSE_Bypass");

      pragma Compile_Time_Error
        (Activate_PLL
           and (PLL_Src_Freq < 1_000_000 * Config.PLL_M_Div
                or PLL_Src_Freq > 16_000_000 * Config.PLL_M_Div),
         "Invalid PLL configuration. PLL1 input frequency after the /M"
           & " divider must be between 1 and 16 MHz");

      pragma Compile_Time_Error
        (Activate_PLL and PLL_VCO_Medium
           and PLL_VCO_Freq not in PLL_VCO_Medium_Range,
         "Invalid PLL configuration. A PLL1 input of 1 to 2 MHz selects the"
           & " medium range: the VCO must be 150 .. 420 MHz (DS13313"
           & " Table 40)");

      pragma Compile_Time_Error
        (Activate_PLL and not PLL_VCO_Medium
           and PLL_VCO_Freq not in PLL_VCO_Wide_Range,
         "Invalid PLL configuration. A PLL1 input of 2 to 16 MHz selects the"
           & " wide range: the VCO must be 192 .. 836 MHz (DS13313"
           & " Table 39)");

      pragma Compile_Time_Error
        (Activate_PLL and PLL_VCO_Medium
           and ((PLL_P_Used and PLL_P_Freq > PLL_Medium_Out_Max)
                or (Config.PLL_Q_Enable and PLL_Q_Freq > PLL_Medium_Out_Max)
                or (Config.PLL_R_Enable and PLL_R_Freq > PLL_Medium_Out_Max)),
         "Invalid PLL configuration. In the medium range every PLL1 output"
           & " is limited to 210 MHz (200 MHz at VOS3, DS13313 Table 40)");

      pragma Compile_Time_Error
        (Config.PLL_P_Div /= 1 and Config.PLL_P_Div mod 2 /= 0,
         "Invalid PLL configuration. PLL1 P divider must be 1 or even"
           & " (RM0468 8.7.12)");

      pragma Compile_Time_Error
        (CPU_Clock_Freq > CPU_Max,
         "CPU clock above the maximum for the selected voltage scaling"
           & " (520 / 400 / 300 / 170 MHz for VOS0 / 1 / 2 / 3)");

      --  The P output has a ceiling of its own, DS13313 Table 39: 550 / 400 /
      --  300 / 170 MHz per voltage scaling (520 at VOS0 here, the CPU's own
      --  maximum, since the boost point is not supported). D1CPRE divides
      --  the CPU clock after it and does not lift it. The ceiling binds the
      --  output only where it is used (DIVP1EN follows PLL_P_Used): a PLL
      --  run for its Q or R output alone may leave the nominal P high.
      pragma Compile_Time_Error
        (PLL_P_Used and PLL_P_Freq > CPU_Max,
         "PLL1 P output above the maximum for the selected voltage scaling"
           & " (520 / 400 / 300 / 170 MHz for VOS0 / 1 / 2 / 3, DS13313"
           & " Table 39; D1CPRE does not lift it)");

      --  The Q and R outputs are held to the same ceiling (Table 39 lists
      --  the P output; the same figure for Q and R is this crate's choice);
      --  the runtime does not use them, an application may.
      pragma Compile_Time_Error
        (Activate_PLL
           and ((Config.PLL_Q_Enable and PLL_Q_Freq > CPU_Max)
                or (Config.PLL_R_Enable and PLL_R_Freq > CPU_Max)),
         "PLL1 Q output above the maximum for the selected voltage scaling,"
           & " or the R output (520 / 400 / 300 / 170 MHz for VOS0 / 1 / 2 /"
           & " 3, DS13313 Table 39)");

      pragma Compile_Time_Error
        (HCLK_Freq > HCLK_Max,
         "AXI/AHB clock above the maximum for the selected voltage scaling"
           & " (275 / 200 / 150 / 85 MHz for VOS0 / 1 / 2 / 3)");

      pragma Compile_Time_Error
        (APB1_Freq > HCLK_Max / 2 or APB2_Freq > HCLK_Max / 2
           or APB3_Freq > HCLK_Max / 2 or APB4_Freq > HCLK_Max / 2,
         "An APB clock is above half the AXI/AHB maximum for the selected"
           & " voltage scaling");

      SW_Value : CFGR_SW_Field;

   begin
      --  The supply configuration (PWR_CR3's lower byte, written once after
      --  a power-on reset) is the start-up's, from the crate option
      --  Supply_Configuration, before any RAM write; here only the wait for
      --  valid voltage levels is repeated before the voltage scaling changes.

      for N in 1 .. Wait_Bound loop
         exit when PWR_Periph.CSR1.ACTVOSRDY = 1;
         if N = Wait_Bound then
            Clock_Not_Ready;
         end if;
      end loop;

      --  Flash latency first, read back as RM0468 4.3.8 requires: the
      --  target's, or what the 64 MHz reset clock needs at the present
      --  scaling where that is more (Switch_Latency). Written before the
      --  voltage scaling changes, so that a scaling lowered under a latency
      --  a bootloader left low never runs the flash short; it holds for the
      --  64 MHz clock at every scaling, the present one and the target. The
      --  target's latency then follows the switch, at the end.

      declare
         ACR : ACR_Register := Flash_Periph.ACR;
      begin
         ACR.LATENCY    := Switch_Latency;
         ACR.WRHIGHFREQ := Switch_Latency;
         Flash_Periph.ACR := ACR;
      end;

      for N in 1 .. Wait_Bound loop
         exit when Flash_Periph.ACR.LATENCY = Switch_Latency;
         if N = Wait_Bound then
            Clock_Not_Ready;
         end if;
      end loop;

      --  Voltage scaling, then wait until it is the one applied and ready

      PWR_Periph.D3CR.VOS := VOS_Code;

      for N in 1 .. Wait_Bound loop
         exit when PWR_Periph.CSR1.ACTVOS = VOS_Code
              and then PWR_Periph.CSR1.ACTVOSRDY = 1;
         if N = Wait_Bound then
            Clock_Not_Ready;
         end if;
      end loop;

      --  HSI divider: written whatever its value, so that a divider left by
      --  a bootloader does not stand behind the runtime's arithmetic

      RCC_Periph.CR.HSIDIV :=
        (case Config.HSI_Div is
           when Config.DIV1 => 2#00#,
           when Config.DIV2 => 2#01#,
           when Config.DIV4 => 2#10#,
           when Config.DIV8 => 2#11#);

      for N in 1 .. Wait_Bound loop
         exit when RCC_Periph.CR.HSIDIVF = 1;
         if N = Wait_Bound then
            Clock_Not_Ready;
         end if;
      end loop;

      --  High-speed external clock, crystal or bypass (RM0468 8.5)

      --  HSEBYP can be written only while the oscillator is off (RM0468
      --  8.7.1; Reset_Clocks turned it off and waited): the bypass alone,
      --  then the oscillator, in two writes as ST's HAL does.

      if HSE_Used then
         RCC_Periph.CR.HSEBYP := (if Config.HSE_Bypass then 1 else 0);
         RCC_Periph.CR.HSEON  := 1;

         for N in 1 .. Wait_Bound loop
            exit when RCC_Periph.CR.HSERDY = 1;
            if N = Wait_Bound then
               HSE_Not_Ready;
            end if;
         end loop;
      end if;

      --  PLL1 (RM0468 8.5.5, registers 8.7.10 .. 8.7.13)

      if Activate_PLL then
         RCC_Periph.CR.PLL1ON := 0;

         for N in 1 .. Wait_Bound loop
            exit when RCC_Periph.CR.PLL1RDY = 0;
            if N = Wait_Bound then
               Clock_Not_Ready;
            end if;
         end loop;

         declare
            CKSEL : PLLCKSELR_Register := RCC_Periph.PLLCKSELR;
         begin
            CKSEL.PLLSRC := (case Config.PLL_Src is
                               when Config.HSI => 2#00#,
                               when Config.HSE => 2#10#);
            CKSEL.DIVM1  := Config.PLL_M_Div;
            RCC_Periph.PLLCKSELR := CKSEL;

            --  Read back: a write the hardware ignored (a PLL still
            --  enabled) would leave another source behind every frequency
            --  the crate computed; the wait parks here instead, where it
            --  shows
            for N in 1 .. Wait_Bound loop
               exit when RCC_Periph.PLLCKSELR.PLLSRC = CKSEL.PLLSRC
                    and then RCC_Periph.PLLCKSELR.DIVM1 = CKSEL.DIVM1;
               if N = Wait_Bound then
                  Clock_Not_Ready;
               end if;
            end loop;
         end;

         declare
            DIVR : PLL1DIVR_Register := RCC_Periph.PLL1DIVR;
         begin
            --  An output the configuration does not use has its divider at
            --  zero as well as its enable (RM0468 8.5.5: "the application
            --  shall set the enable bit (DIVyEN) as well as the
            --  corresponding post-divider bits ... to 0")
            DIVR.DIVN1 := Config.PLL_N_Mul - 1;
            DIVR.DIVP1 := (if PLL_P_Used then Config.PLL_P_Div - 1 else 0);
            DIVR.DIVQ1 :=
              (if Config.PLL_Q_Enable then Config.PLL_Q_Div - 1 else 0);
            DIVR.DIVR1 :=
              (if Config.PLL_R_Enable then Config.PLL_R_Div - 1 else 0);
            RCC_Periph.PLL1DIVR := DIVR;
         end;

         declare
            CFGR : PLLCFGR_Register := RCC_Periph.PLLCFGR;
         begin
            CFGR.PLL1FRACEN := 0;
            CFGR.PLL1VCOSEL := (if PLL_VCO_Medium then 1 else 0);
            CFGR.PLL1RGE    := PLL_RGE;
            CFGR.DIVP1EN    := (if PLL_P_Used then 1 else 0);
            CFGR.DIVQ1EN    := (if Config.PLL_Q_Enable then 1 else 0);
            CFGR.DIVR1EN    := (if Config.PLL_R_Enable then 1 else 0);
            RCC_Periph.PLLCFGR := CFGR;
         end;

         --  Integer mode: the modulator runs on the value latched into its
         --  shadow register when PLL1FRACEN goes from 0 to 1, and keeps it
         --  while the bit is 0 (RM0468 8.5.5), so a fraction a bootloader
         --  latched would survive a FRACN1 of zero alone. Zero is written,
         --  then latched by the edge, as ST's HAL does before every PLL
         --  start.
         RCC_Periph.PLL1FRACR.FRACN1 := 0;
         RCC_Periph.PLLCFGR.PLL1FRACEN := 1;

         RCC_Periph.CR.PLL1ON := 1;

         for N in 1 .. Wait_Bound loop
            exit when RCC_Periph.CR.PLL1RDY = 1;
            if N = Wait_Bound then
               PLL_Not_Locked;
            end if;
         end loop;
      end if;

      --  Domain prescalers (RM0468 8.7.7 .. 8.7.9): D1CPRE and HPRE take
      --  0xxx = /1, 1000 = /2, 1001 = /4, 1010 = /8, 1011 = /16, 1100 = /64,
      --  1101 = /128, 1110 = /256, 1111 = /512; the APB prescalers take
      --  0xx = /1, 100 = /2, 101 = /4, 110 = /8, 111 = /16.

      declare
         D1 : D1CFGR_Register := RCC_Periph.D1CFGR;
      begin
         D1.D1CPRE := (case Config.D1CPRE is
                         when Config.DIV1   => 2#0000#,
                         when Config.DIV2   => 2#1000#,
                         when Config.DIV4   => 2#1001#,
                         when Config.DIV8   => 2#1010#,
                         when Config.DIV16  => 2#1011#,
                         when Config.DIV64  => 2#1100#,
                         when Config.DIV128 => 2#1101#,
                         when Config.DIV256 => 2#1110#,
                         when Config.DIV512 => 2#1111#);
         D1.HPRE   := (case Config.HPRE is
                         when Config.DIV1   => 2#0000#,
                         when Config.DIV2   => 2#1000#,
                         when Config.DIV4   => 2#1001#,
                         when Config.DIV8   => 2#1010#,
                         when Config.DIV16  => 2#1011#,
                         when Config.DIV64  => 2#1100#,
                         when Config.DIV128 => 2#1101#,
                         when Config.DIV256 => 2#1110#,
                         when Config.DIV512 => 2#1111#);
         D1.D1PPRE := (case Config.D1PPRE is
                         when Config.DIV1  => 2#000#,
                         when Config.DIV2  => 2#100#,
                         when Config.DIV4  => 2#101#,
                         when Config.DIV8  => 2#110#,
                         when Config.DIV16 => 2#111#);
         RCC_Periph.D1CFGR := D1;
      end;

      declare
         D2 : D2CFGR_Register := RCC_Periph.D2CFGR;
      begin
         D2.D2PPRE1 := (case Config.D2PPRE1 is
                          when Config.DIV1  => 2#000#,
                          when Config.DIV2  => 2#100#,
                          when Config.DIV4  => 2#101#,
                          when Config.DIV8  => 2#110#,
                          when Config.DIV16 => 2#111#);
         D2.D2PPRE2 := (case Config.D2PPRE2 is
                          when Config.DIV1  => 2#000#,
                          when Config.DIV2  => 2#100#,
                          when Config.DIV4  => 2#101#,
                          when Config.DIV8  => 2#110#,
                          when Config.DIV16 => 2#111#);
         RCC_Periph.D2CFGR := D2;
      end;

      RCC_Periph.D3CFGR.D3PPRE := (case Config.D3PPRE is
                                     when Config.DIV1  => 2#000#,
                                     when Config.DIV2  => 2#100#,
                                     when Config.DIV4  => 2#101#,
                                     when Config.DIV8  => 2#110#,
                                     when Config.DIV16 => 2#111#);

      --  Switch the system clock (RM0468 8.7.6: SW and SWS take
      --  000 = HSI, 001 = CSI, 010 = HSE, 011 = PLL1 P)

      SW_Value := (case Config.SYSCLK_Src is
                     when Config.HSI  => 2#000#,
                     when Config.CSI  => 2#001#,
                     when Config.HSE  => 2#010#,
                     when Config.PLL1 => 2#011#);

      --  The CSI, if it is the system clock: on and ready (off after reset,
      --  RM0468 8.7.2)

      if CSI_Used then
         RCC_Periph.CR.CSION := 1;

         for N in 1 .. Wait_Bound loop
            exit when RCC_Periph.CR.CSIRDY = 1;
            if N = Wait_Bound then
               Clock_Not_Ready;
            end if;
         end loop;
      end if;

      RCC_Periph.CFGR.SW := SW_Value;

      for N in 1 .. Wait_Bound loop
         exit when RCC_Periph.CFGR.SWS = SW_Value;
         if N = Wait_Bound then
            Clock_Not_Ready;
         end if;
      end loop;

      --  The target latency, where the reset clock needed more

      if Lower_Latency_After then
         declare
            ACR : ACR_Register := Flash_Periph.ACR;
         begin
            ACR.LATENCY    := Flash_Latency;
            ACR.WRHIGHFREQ := Flash_Latency;
            Flash_Periph.ACR := ACR;
         end;

         for N in 1 .. Wait_Bound loop
            exit when Flash_Periph.ACR.LATENCY = Flash_Latency;
            if N = Wait_Bound then
               Clock_Not_Ready;
            end if;
         end loop;
      end if;
   end Initialize_Clocks;

   ------------------
   -- Reset_Clocks --
   ------------------

   procedure Reset_Clocks is
   begin
      --  The prescalers return to their reset values below, which can raise
      --  the AXI clock to the 64 MHz HSI under a latency a bootloader left
      --  for a lower clock: at least 1 wait state first (enough for 64 MHz
      --  at every scaling, Table 16), never lowered here.

      if Flash_Periph.ACR.LATENCY < 1 then
         declare
            ACR : ACR_Register := Flash_Periph.ACR;
         begin
            ACR.LATENCY    := 1;
            ACR.WRHIGHFREQ :=
              ACR_WRHIGHFREQ_Field'Max (ACR.WRHIGHFREQ, 1);
            Flash_Periph.ACR := ACR;
         end;

         for N in 1 .. Wait_Bound loop
            exit when Flash_Periph.ACR.LATENCY = 1;
            if N = Wait_Bound then
               Clock_Not_Ready;
            end if;
         end loop;
      end if;

      --  Run from the HSI, as after reset, before touching anything else

      RCC_Periph.CR.HSION := 1;

      for N in 1 .. Wait_Bound loop
         exit when RCC_Periph.CR.HSIRDY = 1;
         if N = Wait_Bound then
            Clock_Not_Ready;
         end if;
      end loop;

      --  The whole register at its reset value: SW = HSI, and TIMPRE, the
      --  MCO and RTC prescalers as after reset, whatever a bootloader left

      RCC_Periph.CFGR := (others => <>);

      for N in 1 .. Wait_Bound loop
         exit when RCC_Periph.CFGR.SWS = 2#000#;
         if N = Wait_Bound then
            Clock_Not_Ready;
         end if;
      end loop;

      --  Default prescalers, every PLL off, the HSE off and its bypass
      --  cleared. A clock security system a bootloader armed stays armed:
      --  HSECSSON is set-only (RM0468 8.7.1, "clearing this bit through
      --  software has no impact"), and an HSE failure then raises the NMI.

      RCC_Periph.D1CFGR := (others => <>);
      RCC_Periph.D2CFGR := (others => <>);
      RCC_Periph.D3CFGR := (others => <>);

      --  Every PLL off, not PLL1 alone: PLLSRC can be written only when all
      --  PLLs are disabled (RM0468 8.7.10) and HSIDIV cannot change while an
      --  enabled PLL takes the HSI (8.7.1); a bootloader that left PLL2 or
      --  PLL3 running would turn both writes into no-ops, silently

      declare
         CR : Interfaces.STM32.RCC.CR_Register := RCC_Periph.CR;
      begin
         CR.PLL1ON := 0;
         CR.PLL2ON := 0;
         CR.PLL3ON := 0;
         RCC_Periph.CR := CR;
      end;

      for N in 1 .. Wait_Bound loop
         exit when RCC_Periph.CR.PLL1RDY = 0
              and then RCC_Periph.CR.PLL2RDY = 0
              and then RCC_Periph.CR.PLL3RDY = 0;
         if N = Wait_Bound then
            Clock_Not_Ready;
         end if;
      end loop;

      --  HSEBYP can be written only while the oscillator is off (RM0468
      --  8.7.1): the oscillator off and its ready flag down first

      RCC_Periph.CR.HSEON := 0;

      for N in 1 .. Wait_Bound loop
         exit when RCC_Periph.CR.HSERDY = 0;
         if N = Wait_Bound then
            Clock_Not_Ready;
         end if;
      end loop;

      RCC_Periph.CR.HSEBYP := 0;
   end Reset_Clocks;

begin
   Reset_Clocks;
   Initialize_Clocks;
end Setup_Pll;
