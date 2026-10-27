--  The state the family's start-up leaves behind, read from the core's
--  registers (PM0253): both caches on with branch prediction and 8-byte
--  stack alignment on exception entry (CCR), the FPU accessible (CPACR),
--  the vector table installed (VTOR = __vectors), both TCMs enabled at the
--  sizes of the default sharing (ITCMCR/DTCMCR: SZ 7 = 64 KB, 8 = 128 KB),
--  lazy floating-point stacking on (FPCCR), the MPU untouched without the
--  stack guard (MPU_CTRL), and the main program's stack pointer 8-aligned;
--  PLL1's outputs this configuration does not use (Q and R by default)
--  with their enables AND their dividers at zero, as RM0468 8.5.5 requires
--  ("the application shall set the enable bit (DIVyEN) as well as the
--  corresponding post-divider bits ... to 0"): RCC_PLLCFGR 0x5802_442C
--  DIVQ1EN bit 17, DIVR1EN bit 18; RCC_PLL1DIVR 0x5802_4430 DIVQ1 22:16,
--  DIVR1 30:24.
--  Any regression in start-common.S is a text difference here.

with Ada.Text_IO;
with Interfaces; use Interfaces;
with System;
with System.Machine_Code; use System.Machine_Code;
with System.Storage_Elements; use System.Storage_Elements;

procedure Test is
   CCR      : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_ED14#);
   CPACR    : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_ED88#);
   VTOR     : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_ED08#);
   ITCMCR   : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_EF90#);
   DTCMCR   : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_EF94#);
   FPCCR    : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_EF34#);
   MPU_CTRL : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_ED94#);
   PLLCFGR  : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#5802_442C#);
   PLL1DIVR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#5802_4430#);

   Vectors : constant Character
     with Import, Convention => Asm, External_Name => "__vectors";

   function Bit (R : Unsigned_32; N : Natural) return Boolean
   is ((Shift_Right (R, N) and 1) = 1);

   SP : Unsigned_32;
begin
   Asm ("mov %0, sp", Outputs => Unsigned_32'Asm_Output ("=r", SP), Volatile => True);

   Ada.Text_IO.Put_Line
     --  BP reads as one on the Cortex-M7 (PM0253 4.3.7: branch prediction
     --  always on); the line holds the other three bits.
     ("CCR: IC " & Boolean'Image (Bit (CCR, 17)) & " DC " & Boolean'Image (Bit (CCR, 16))
      & " BP " & Boolean'Image (Bit (CCR, 18)) & " STKALIGN " & Boolean'Image (Bit (CCR, 9)));
   Ada.Text_IO.Put_Line
     ("CPACR: CP10/CP11 full access "
      & Boolean'Image ((Shift_Right (CPACR, 20) and 16#F#) = 16#F#));
   Ada.Text_IO.Put_Line
     ("VTOR = __vectors " & Boolean'Image (VTOR = Unsigned_32 (To_Integer (Vectors'Address))));
   Ada.Text_IO.Put_Line
     ("ITCMCR: EN " & Boolean'Image (Bit (ITCMCR, 0))
      & " SZ" & Unsigned_32'Image (Shift_Right (ITCMCR, 3) and 16#F#));
   Ada.Text_IO.Put_Line
     ("DTCMCR: EN " & Boolean'Image (Bit (DTCMCR, 0))
      & " SZ" & Unsigned_32'Image (Shift_Right (DTCMCR, 3) and 16#F#));
   Ada.Text_IO.Put_Line
     ("FPCCR: ASPEN " & Boolean'Image (Bit (FPCCR, 31)) & " LSPEN " & Boolean'Image (Bit (FPCCR, 30)));
   Ada.Text_IO.Put_Line ("MPU_CTRL =" & Unsigned_32'Image (MPU_CTRL));
   Ada.Text_IO.Put_Line ("main SP mod 8 =" & Unsigned_32'Image (SP mod 8));
   Ada.Text_IO.Put_Line
     ("PLL1 Q unused: DIVQ1EN" & Unsigned_32'Image (Shift_Right (PLLCFGR, 17) and 1)
      & " DIVQ1" & Unsigned_32'Image (Shift_Right (PLL1DIVR, 16) and 16#7F#));
   Ada.Text_IO.Put_Line
     ("PLL1 R unused: DIVR1EN" & Unsigned_32'Image (Shift_Right (PLLCFGR, 18) and 1)
      & " DIVR1" & Unsigned_32'Image (Shift_Right (PLL1DIVR, 24) and 16#7F#));
   Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
end Test;
