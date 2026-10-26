with Ada.Real_Time; use Ada.Real_Time;
with Interfaces.C;
with System.Machine_Code; use System.Machine_Code;

package body Chains is

   use Interfaces;

   NL : constant String := ASCII.LF & ASCII.HT;

   NVIC_ISPR0 : Unsigned_32 with Volatile, Import,
     Address => System'To_Address (16#E000_E200#);
   NVIC_ICPR0 : Unsigned_32 with Volatile, Import,
     Address => System'To_Address (16#E000_E280#);
   IRQ_Mask : constant Unsigned_32 := Shift_Left (1, Natural (IRQ));

   One : Long_Float := 1.0 with Volatile;   --  a factor the compiler cannot fold

   --  Chain A: x <- x * 1.000001 + 0.5 from 1.0; chain B: x <- x / 1.000002 + 0.25
   --  from 2.0.

   function Step_A (X : Long_Float) return Long_Float is (X * 1.000001 + 0.5);
   function Step_B (X : Long_Float) return Long_Float is (X / 1.000002 + 0.25);

   function Expected_A return Long_Float is
      X : Long_Float := 1.0;
   begin
      for I in 1 .. Steps loop
         X := Step_A (X);
      end loop;
      return X;
   end Expected_A;

   function Expected_B return Long_Float is
      X : Long_Float := 2.0;
   begin
      for I in 1 .. Steps loop
         X := Step_B (X);
      end loop;
      return X;
   end Expected_B;

   ----------------------------------------------------------------------
   --  The callee-saved registers across a delay

   type Slot is range 0 .. 1;
   Wake_At : array (Slot) of Time with Volatile;

   procedure Wait (S : Interfaces.C.int)
     with Export, Convention => C, External_Name => "__fpu_test_wait";
   --  Called from the assembly block below with d8-d15 loaded: the delay,
   --  and with it the context switches, happen inside this call. The ABI
   --  makes the callee keep d8-d15, and the runtime's switch is what makes
   --  that true across the tasks.
   procedure Wait (S : Interfaces.C.int) is
   begin
      delay until Wake_At (Slot (S));
   end Wait;

   type Pattern_Set is array (0 .. 7) of Unsigned_64 with Alignment => 8;

   --  Loads d8-d15 with Patterns, calls Wait (S), stores d8-d15 back and
   --  returns whether every register came back as it went. r4 and r5 hold
   --  the two addresses across the call (callee-saved); the call clobbers
   --  r0-r3, r12, lr and d0-d7, the asm says so, and the memory clobber
   --  keeps the arrays in memory on both sides.
   function Hold_Across_Delay (S : Slot; Patterns : Pattern_Set) return Boolean
     with No_Inline;
   function Hold_Across_Delay (S : Slot; Patterns : Pattern_Set) return Boolean
   is
      Input  : Pattern_Set := Patterns with Volatile;
      Output : Pattern_Set := (others => 0) with Volatile;
   begin
      Asm ("mov r4, %0"              & NL &
           "mov r5, %1"              & NL &
           "vldm r4, {d8-d15}"       & NL &
           "mov r0, %2"              & NL &
           "bl __fpu_test_wait"      & NL &
           "vstm r5, {d8-d15}",
           Inputs   => (System.Address'Asm_Input ("r", Input'Address),
                        System.Address'Asm_Input ("r", Output'Address),
                        Interfaces.C.int'Asm_Input ("r", Interfaces.C.int (S))),
           Clobber  => "r0,r1,r2,r3,r4,r5,r12,lr,"
                       & "d0,d1,d2,d3,d4,d5,d6,d7,d8,d9,d10,d11,d12,d13,d14,d15,"
                       & "memory,cc",
           Volatile => True);
      return (for all K in Pattern_Set'Range => Output (K) = Input (K));
   end Hold_Across_Delay;

   function Patterns_For (Tag : Unsigned_64; Step : Positive) return Pattern_Set is
      P : Pattern_Set;
   begin
      for K in P'Range loop
         P (K) := Tag xor Shift_Left (Unsigned_64 (Step), 32)
                  xor Shift_Left (Unsigned_64 (K + 1), 56) xor Unsigned_64 (K) * 16#0101_0101#;
      end loop;
      return P;
   end Patterns_For;

   task body Chain_A is
      X : Long_Float := 1.0;
      Y : Long_Float := 3.0;   -- a second live double, checked at the end
      Lost : Natural := 0;
   begin
      Wake_At (0) := Clock;
      for I in 1 .. Steps loop
         X := Step_A (X);
         Y := Y * One;
         Wake_At (0) := Wake_At (0) + Milliseconds (1);
         if not Hold_Across_Delay (0, Patterns_For (16#A5A5_0000_0000_0000#, I)) then
            Lost := Lost + 1;
         end if;
      end loop;
      Result_A := (Value => (if Y = 3.0 then X else -1.0), Done => True, Lost => Lost);
      Ada.Synchronous_Task_Control.Set_True (Done_A);
   end Chain_A;

   task body Chain_B is
      X : Long_Float := 2.0;
      Y : Long_Float := 7.0;
      Lost : Natural := 0;
   begin
      Wake_At (1) := Clock;
      for I in 1 .. Steps loop
         X := Step_B (X);
         Y := Y * One;
         Wake_At (1) := Wake_At (1) + Milliseconds (1);
         if not Hold_Across_Delay (1, Patterns_For (16#5A5A_0000_0000_0000#, I)) then
            Lost := Lost + 1;
         end if;
      end loop;
      Result_B := (Value => (if Y = 7.0 then X else -1.0), Done => True, Lost => Lost);
      Ada.Synchronous_Task_Control.Set_True (Done_B);
   end Chain_B;

   protected body Handler is
      procedure Serve is
      begin
         NVIC_ICPR0 := IRQ_Mask;
         Handler_Sum := Handler_Sum + 0.125;   -- the FPU inside the handler
         Handler_Count := Handler_Count + 1;
      end Serve;
   end Handler;

   procedure Trigger_IRQ is
   begin
      NVIC_ISPR0 := IRQ_Mask;
      Asm ("dsb" & ASCII.LF & "isb", Volatile => True);
   end Trigger_IRQ;

end Chains;
