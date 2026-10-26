with Interfaces; use Interfaces;
with System.Machine_Code; use System.Machine_Code;
with System.Storage_Elements; use System.Storage_Elements;

package body Handover is

   NL : constant String := ASCII.LF & ASCII.HT;

   Magic : constant Unsigned_32 := 16#4841_4E44#;   --  "HAND"
   Word  : Unsigned_32 with Volatile, Linker_Section => ".sram4";

   DCCMVAC      : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_EF68#);
   RCC_RSR      : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#5802_44D0#);
   Reset_Flags  : constant Unsigned_32 := 16#5FFE_0000#;   --  the *RSTF bits; RMVF is bit 16
   SysTick_CTRL : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_E010#);
   ICSR         : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_ED04#);
   NVIC_ICER    : array (0 .. 7) of Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_E180#);
   NVIC_ICPR    : array (0 .. 7) of Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_E280#);

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
      SysTick_CTRL := 0;
      ICSR := 2 ** 27 or 2 ** 25;          --  PENDSVCLR, PENDSTCLR
      for I in NVIC_ICER'Range loop
         NVIC_ICER (I) := 16#FFFF_FFFF#;
         NVIC_ICPR (I) := 16#FFFF_FFFF#;
      end loop;
      Asm ("dsb" & NL & "isb" & NL
           & "movw r0, #:lower16:__stack_end" & NL
           & "movt r0, #:upper16:__stack_end" & NL
           & "msr msp, r0" & NL
           & "movs r1, #0" & NL
           & "msr control, r1" & NL         --  MSP, privileged, no FP context
           & "msr basepri, r1" & NL
           & "isb" & NL
           & "cpsie i" & NL
           & "b _start_rom",
           Volatile => True, Clobber => "r0,r1,memory");
      loop
         null;
      end loop;
   end Restart;

end Handover;
