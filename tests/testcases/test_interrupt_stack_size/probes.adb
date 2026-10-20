with System.Machine_Code; use System.Machine_Code;

package body Probes is

   use Interfaces;

   NVIC_ISPR0 : Unsigned_32 with Volatile, Import,
     Address => System'To_Address (16#E000_E200#);
   NVIC_ICPR0 : Unsigned_32 with Volatile, Import,
     Address => System'To_Address (16#E000_E280#);
   IRQ_Mask : constant Unsigned_32 := Shift_Left (1, Natural (IRQ));

   ----------------
   -- Current_SP --
   ----------------

   function Current_SP return Unsigned_32 is
      SP : Unsigned_32;
   begin
      Asm ("mov %0, sp", Outputs => Unsigned_32'Asm_Output ("=r", SP), Volatile => True);
      return SP;
   end Current_SP;

   ------------
   -- Prober --
   ------------

   task body Prober is
   begin
      Task_SP := Current_SP;
      Ada.Synchronous_Task_Control.Set_True (Task_Done);
   end Prober;

   -------------
   -- Handler --
   -------------

   protected body Handler is
      procedure Serve is
      begin
         NVIC_ICPR0 := IRQ_Mask;
         Handler_SP := Current_SP;
      end Serve;
   end Handler;

   -----------------
   -- Trigger_IRQ --
   -----------------

   procedure Trigger_IRQ is
   begin
      NVIC_ISPR0 := IRQ_Mask;
      Asm ("dsb" & ASCII.LF & "isb", Volatile => True);
   end Trigger_IRQ;

end Probes;
