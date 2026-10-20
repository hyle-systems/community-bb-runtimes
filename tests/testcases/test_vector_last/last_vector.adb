with Ada.Text_IO;
with Interfaces; use Interfaces;
with System.Machine_Code; use System.Machine_Code;

package body Last_Vector is

   --  Interrupt 162: register 162 / 32 = 5, bit 162 mod 32 = 2
   NVIC_ISPR5 : Unsigned_32 with Volatile, Import,
     Address => System'To_Address (16#E000_E214#);
   NVIC_ICPR5 : Unsigned_32 with Volatile, Import,
     Address => System'To_Address (16#E000_E294#);
   IRQ_Mask : constant Unsigned_32 := Shift_Left (1, Natural (IRQ) mod 32);

   protected body Handler is
      procedure Serve is
      begin
         NVIC_ICPR5 := IRQ_Mask;
         Ada.Text_IO.Put_Line ("last vector served");
      end Serve;
   end Handler;

   procedure Trigger_IRQ is
   begin
      NVIC_ISPR5 := IRQ_Mask;
      Asm ("dsb" & ASCII.LF & "isb", Volatile => True);
   end Trigger_IRQ;

end Last_Vector;
