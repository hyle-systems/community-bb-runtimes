with Ada.Real_Time; use Ada.Real_Time;
with System.Machine_Code; use System.Machine_Code;

package body Spinner is

   use Interfaces;

   NL : constant String := ASCII.LF & ASCII.HT;

   type Pattern_Set is array (0 .. 15) of Unsigned_64 with Alignment => 8;

   function Patterns (Base, Step : Unsigned_64) return Pattern_Set is
      Result : Pattern_Set;
   begin
      for K in Result'Range loop
         Result (K) := Base or Unsigned_64 (K) * Step;
      end loop;
      return Result;
   end Patterns;

   Spin_Values  : constant Pattern_Set :=
     Patterns (16#C0DE_0000_0000_0000#, 16#0001_0001_0001#);
   Other_Values : constant Pattern_Set :=
     Patterns (16#BAD0_0000_0000_0000#, 16#0100_0100_0100#);

   --  TIM2 (APB1, RM0468 39.4): the timer clock is twice the APB1 clock at
   --  the default prescalers; a 10 kHz update interrupt
   RCC_APB1LENR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#5802_44E8#);
   TIM2_CR1  : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4000_0000#);
   TIM2_DIER : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4000_000C#);
   TIM2_SR   : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4000_0010#);
   TIM2_PSC  : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4000_0028#);
   TIM2_ARR  : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4000_002C#);
   Dummy : Unsigned_32 with Volatile;

   procedure Start_Timer is
   begin
      RCC_APB1LENR := RCC_APB1LENR or 1;   --  TIM2EN
      Dummy := RCC_APB1LENR;
      TIM2_PSC := 0;
      TIM2_ARR := 26_000 - 1;              --  260 MHz / 26 000 = 10 kHz
      TIM2_SR := 0;
      TIM2_DIER := 1;                      --  UIE
      TIM2_CR1 := 1;                       --  CEN
   end Start_Timer;

   procedure Stop_Timer is
   begin
      TIM2_CR1 := 0;
      TIM2_DIER := 0;
   end Stop_Timer;

   --  Loads d0-d15 from Values, then Rounds times compares each of them
   --  with Values; returns the number of rounds with a mismatch (the round
   --  reloads the registers so that one corruption counts once)
   function Hold (Values : Pattern_Set; Rounds : Unsigned_32) return Unsigned_32
     with No_Inline;
   function Hold (Values : Pattern_Set; Rounds : Unsigned_32) return Unsigned_32 is
      Failed : Unsigned_32;
   begin
      Asm ("mov r12, %2"                & NL &
           "movs %0, #0"                & NL &
           "vldm %1, {d0-d15}"         & NL &
           "1:"                         & NL &
           "vmov r0, r1, d0"          & NL &
           "ldrd r2, r3, [%1, #0]"  & NL &
           "cmp r0, r2"                & NL &
           "bne 3f"                    & NL &
           "cmp r1, r3"                & NL &
           "bne 3f"                    & NL &
           "vmov r0, r1, d1"          & NL &
           "ldrd r2, r3, [%1, #8]"  & NL &
           "cmp r0, r2"                & NL &
           "bne 3f"                    & NL &
           "cmp r1, r3"                & NL &
           "bne 3f"                    & NL &
           "vmov r0, r1, d2"          & NL &
           "ldrd r2, r3, [%1, #16]"  & NL &
           "cmp r0, r2"                & NL &
           "bne 3f"                    & NL &
           "cmp r1, r3"                & NL &
           "bne 3f"                    & NL &
           "vmov r0, r1, d3"          & NL &
           "ldrd r2, r3, [%1, #24]"  & NL &
           "cmp r0, r2"                & NL &
           "bne 3f"                    & NL &
           "cmp r1, r3"                & NL &
           "bne 3f"                    & NL &
           "vmov r0, r1, d4"          & NL &
           "ldrd r2, r3, [%1, #32]"  & NL &
           "cmp r0, r2"                & NL &
           "bne 3f"                    & NL &
           "cmp r1, r3"                & NL &
           "bne 3f"                    & NL &
           "vmov r0, r1, d5"          & NL &
           "ldrd r2, r3, [%1, #40]"  & NL &
           "cmp r0, r2"                & NL &
           "bne 3f"                    & NL &
           "cmp r1, r3"                & NL &
           "bne 3f"                    & NL &
           "vmov r0, r1, d6"          & NL &
           "ldrd r2, r3, [%1, #48]"  & NL &
           "cmp r0, r2"                & NL &
           "bne 3f"                    & NL &
           "cmp r1, r3"                & NL &
           "bne 3f"                    & NL &
           "vmov r0, r1, d7"          & NL &
           "ldrd r2, r3, [%1, #56]"  & NL &
           "cmp r0, r2"                & NL &
           "bne 3f"                    & NL &
           "cmp r1, r3"                & NL &
           "bne 3f"                    & NL &
           "vmov r0, r1, d8"          & NL &
           "ldrd r2, r3, [%1, #64]"  & NL &
           "cmp r0, r2"                & NL &
           "bne 3f"                    & NL &
           "cmp r1, r3"                & NL &
           "bne 3f"                    & NL &
           "vmov r0, r1, d9"          & NL &
           "ldrd r2, r3, [%1, #72]"  & NL &
           "cmp r0, r2"                & NL &
           "bne 3f"                    & NL &
           "cmp r1, r3"                & NL &
           "bne 3f"                    & NL &
           "vmov r0, r1, d10"          & NL &
           "ldrd r2, r3, [%1, #80]"  & NL &
           "cmp r0, r2"                & NL &
           "bne 3f"                    & NL &
           "cmp r1, r3"                & NL &
           "bne 3f"                    & NL &
           "vmov r0, r1, d11"          & NL &
           "ldrd r2, r3, [%1, #88]"  & NL &
           "cmp r0, r2"                & NL &
           "bne 3f"                    & NL &
           "cmp r1, r3"                & NL &
           "bne 3f"                    & NL &
           "vmov r0, r1, d12"          & NL &
           "ldrd r2, r3, [%1, #96]"  & NL &
           "cmp r0, r2"                & NL &
           "bne 3f"                    & NL &
           "cmp r1, r3"                & NL &
           "bne 3f"                    & NL &
           "vmov r0, r1, d13"          & NL &
           "ldrd r2, r3, [%1, #104]"  & NL &
           "cmp r0, r2"                & NL &
           "bne 3f"                    & NL &
           "cmp r1, r3"                & NL &
           "bne 3f"                    & NL &
           "vmov r0, r1, d14"          & NL &
           "ldrd r2, r3, [%1, #112]"  & NL &
           "cmp r0, r2"                & NL &
           "bne 3f"                    & NL &
           "cmp r1, r3"                & NL &
           "bne 3f"                    & NL &
           "vmov r0, r1, d15"          & NL &
           "ldrd r2, r3, [%1, #120]"  & NL &
           "cmp r0, r2"                & NL &
           "bne 3f"                    & NL &
           "cmp r1, r3"                & NL &
           "bne 3f"                    & NL &
           "b 4f"                       & NL &
           "3:"                         & NL &
           "adds %0, %0, #1"            & NL &
           "vldm %1, {d0-d15}"         & NL &
           "4:"                         & NL &
           "subs r12, r12, #1"          & NL &
           "bne 1b",
           Outputs  => Unsigned_32'Asm_Output ("=&r", Failed),
           Inputs   => (System.Address'Asm_Input ("r", Values'Address),
                        Unsigned_32'Asm_Input ("r", Rounds)),
           Clobber  => "r0,r1,r2,r3,r12,"
                       & "d0,d1,d2,d3,d4,d5,d6,d7,d8,d9,d10,d11,d12,d13,d14,d15,"
                       & "memory,cc",
           Volatile => True);
      return Failed;
   end Hold;

   Poke_Next : Time with Volatile;

   procedure Poke_Wait
     with Export, Convention => C, External_Name => "__spinner_poke_wait";
   --  Called from the assembly block below with d0-d15 loaded: the delay,
   --  and the switch back to Spin, happen inside this call with other
   --  values live in every double register - d8-d15 above all, which the
   --  ABI makes this call keep, so that only the switch's save and restore
   --  give Spin its own back
   procedure Poke_Wait is
   begin
      delay until Poke_Next;
   end Poke_Wait;

   procedure Wait_Holding (Values : Pattern_Set) with No_Inline;
   procedure Wait_Holding (Values : Pattern_Set) is
   begin
      Asm ("vldm %0, {d0-d15}"         & NL &
           "bl __spinner_poke_wait",
           Inputs   => System.Address'Asm_Input ("r", Values'Address),
           Clobber  => "r0,r1,r2,r3,r12,lr,"
                       & "d0,d1,d2,d3,d4,d5,d6,d7,d8,d9,d10,d11,d12,d13,d14,d15,"
                       & "memory,cc",
           Volatile => True);
   end Wait_Holding;

   task body Spin is
   begin
      Ada.Synchronous_Task_Control.Suspend_Until_True (Go_Spin);
      for Burst in 1 .. 20 loop
         Rounds_Failed := Rounds_Failed + Hold (Spin_Values, 200_000);
      end loop;
      Finished := True;
      Ada.Synchronous_Task_Control.Set_True (Done);
   end Spin;

   task body Poke is
   begin
      Ada.Synchronous_Task_Control.Suspend_Until_True (Go_Poke);
      Poke_Next := Clock;
      while not Finished loop
         Poke_Next := Poke_Next + Milliseconds (1);
         Wait_Holding (Other_Values);
         Preemptions := Preemptions + 1;
      end loop;
   end Poke;

   protected body Timer is
      procedure Serve is
         X : Long_Float := Long_Float (Interrupts) * 0.5;
      begin
         TIM2_SR := 0;
         X := X + 0.25;                    --  the FPU inside the handler
         Asm ("vldm %0, {d0-d7}",
              Inputs   => System.Address'Asm_Input ("r", Other_Values'Address),
              Clobber  => "d0,d1,d2,d3,d4,d5,d6,d7,memory",
              Volatile => True);
         if X >= 0.0 then
            Interrupts := Interrupts + 1;
         end if;
      end Serve;
   end Timer;

end Spinner;
