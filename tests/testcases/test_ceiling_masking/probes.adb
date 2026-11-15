with Interfaces; use Interfaces;
with System.Machine_Code; use System.Machine_Code;

package body Probes is

   NVIC_ISPR0 : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_E200#);
   NVIC_ISPR1 : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_E204#);

   protected body Below is
      procedure Handler is
      begin
         Below_N := Below_N + 1;
      end Handler;
   end Below;

   protected body At_Ceiling is
      procedure Handler is
      begin
         At_Ceiling_N := At_Ceiling_N + 1;
      end Handler;
   end At_Ceiling;

   protected body Above is
      procedure Handler is
      begin
         Above_N := Above_N + 1;
      end Handler;
   end Above;

   protected body Guarded is
      procedure Pend_All_And_Look (Inside : out Seen) is
         Spin : Unsigned_32 := 0 with Volatile;
      begin
         NVIC_ISPR0 := 2 ** 29 or 2 ** 30;   --  TIM3, TIM4
         NVIC_ISPR1 := 2 ** (50 - 32);       --  TIM5
         Asm ("dsb" & ASCII.LF & ASCII.HT & "isb", Volatile => True);
         while Spin < 10_000 loop             --  time for any interrupt that may run
            Spin := Spin + 1;
         end loop;
         Inside := (Below      => Below_N,
                    At_Ceiling => At_Ceiling_N,
                    Above      => Above_N);
      end Pend_All_And_Look;
   end Guarded;

end Probes;
