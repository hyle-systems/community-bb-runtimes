with Interfaces; use Interfaces;
with System.Machine_Code; use System.Machine_Code;
with System.Storage_Elements; use System.Storage_Elements;

package body Handover is

   NL : constant String := ASCII.LF & ASCII.HT;

   Magic : constant Unsigned_32 := 16#4841_4E44#;   --  "HAND"
   Word  : Unsigned_32 with Volatile, Linker_Section => ".sram4_noinit";

   DCCMVAC      : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_EF68#);
   RCC_RSR      : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#5802_44D0#);
   Reset_Flags  : constant Unsigned_32 := 16#5FFE_0000#;   --  the *RSTF bits; RMVF is bit 16
   SysTick_CTRL : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_E010#);
   SysTick_LOAD : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_E014#);
   ICSR         : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_ED04#);
   FPCCR        : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_EF34#);
   NVIC_ISER0   : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_E100#);
   NVIC_ISPR0   : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_E200#);

   procedure Clean_Line (Addr : System.Address) is
   begin
      DCCMVAC := Unsigned_32 (To_Integer (Addr));
      Asm ("dsb" & NL & "isb", Volatile => True);
   end Clean_Line;

   function Second_Pass return Boolean is
      Marked : constant Boolean := Word = Magic;
      Was    : constant Boolean := Marked and then (RCC_RSR and Reset_Flags) = 0;
   begin
      if Marked then
         Word := 0;
         Clean_Line (Word'Address);
      end if;
      return Was;
   end Second_Pass;

   procedure Mark is
   begin
      RCC_RSR := RCC_RSR or 2 ** 16;   --  RMVF: a reset from here on is visible
      Word := Magic;
      Clean_Line (Word'Address);
   end Mark;

   procedure Restart is
   begin
      Asm ("cpsid i", Volatile => True);
      SysTick_LOAD := 64_000 - 1;
      SysTick_CTRL := 2#111#;              --  ENABLE, TICKINT, the processor clock
      ICSR := 2 ** 26;                     --  PENDSTSET
      NVIC_ISER0 := 2 ** 28;               --  TIM2 enabled
      NVIC_ISPR0 := 2 ** 28;               --  and pending
      FPCCR := FPCCR and not 16#C000_0000#;   --  ASPEN, LSPEN off
      Asm ("dsb" & NL & "isb" & NL
           & "movw r0, #:lower16:__stack_end" & NL
           & "movt r0, #:upper16:__stack_end" & NL
           & "msr msp, r0" & NL
           & "movw r0, #0x8000" & NL
           & "movt r0, #0x2405" & NL        --  a foreign stack in the AXI SRAM
           & "msr psp, r0" & NL
           & "movs r1, #2" & NL
           & "msr control, r1" & NL         --  SPSEL: the thread on the PSP
           & "movs r1, #0x80" & NL
           & "msr basepri, r1" & NL
           & "isb" & NL
           --  Interrupts still masked by PRIMASK, as a bootloader jumps: an
           --  exception taken before the image's first instruction is the
           --  bootloader's, not the runtime's to handle
           & "b _start_rom",
           Volatile => True, Clobber => "r0,r1,memory");
      loop
         null;
      end loop;
   end Restart;

end Handover;
