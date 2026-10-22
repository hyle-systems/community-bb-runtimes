with Interfaces; use Interfaces;
with System.Machine_Code; use System.Machine_Code;

package body Overflow is

   NVIC_ISPR5 : Unsigned_32 with Volatile, Import,
     Address => System'To_Address (16#E000_E214#);
   NVIC_ICPR5 : Unsigned_32 with Volatile, Import,
     Address => System'To_Address (16#E000_E294#);
   IRQ_Mask : constant Unsigned_32 := Shift_Left (1, Natural (IRQ) mod 32);

   procedure Dig (Level : Natural) is
      Frame : array (1 .. 64) of Unsigned_32 with Volatile;   -- 256 bytes
   begin
      Frame (1) := Unsigned_32 (Level);
      Depth := Level;
      Dig (Level + 1);
      Frame (64) := Frame (1);   -- keeps the frame and the call
   end Dig;

   protected body Handler is
      procedure Serve is
      begin
         NVIC_ICPR5 := IRQ_Mask;
         Dig (1);
      end Serve;
   end Handler;

   procedure Pend is
   begin
      NVIC_ISPR5 := IRQ_Mask;
      Asm ("dsb" & ASCII.LF & "isb", Volatile => True);
   end Pend;

end Overflow;
