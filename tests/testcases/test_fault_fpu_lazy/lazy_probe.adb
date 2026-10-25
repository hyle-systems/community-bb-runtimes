with Ada.Text_IO;
with Interfaces; use Interfaces;
with System;
with System.Machine_Code; use System.Machine_Code;
with System.Storage_Elements; use System.Storage_Elements;

package body Lazy_Probe is

   MPU_RNR  : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_ED98#);
   MPU_RBAR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_ED9C#);
   MPU_RASR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_EDA0#);

   NVIC_ISPR0 : constant System.Address := System'To_Address (16#E000_E200#);
   IRQ_Mask   : constant Unsigned_32 :=
     Shift_Left (1, Natural (Ada.Interrupts.Names.TIM1_CC_Interrupt));

   Handler_Ran : Boolean := False with Volatile;

   --  The running task's window is in region 0 or 3 (the runtime alternates
   --  them across context switches): the enabled one whose base is below
   --  the stack pointer and nearest to it.
   function Window_End return Integer_Address is
      SP   : Unsigned_32;
      Best : Integer_Address := 0;
      Size : Integer_Address := 0;
   begin
      Asm ("mov %0, sp", Outputs => Unsigned_32'Asm_Output ("=r", SP), Volatile => True);
      for Region in Unsigned_32'(0) .. 3 loop
         if Region = 0 or else Region = 3 then
            MPU_RNR := Region;
            declare
               RBAR : constant Unsigned_32 := MPU_RBAR;
               RASR : constant Unsigned_32 := MPU_RASR;
               Base : constant Integer_Address := Integer_Address (RBAR and not 16#1F#);
            begin
               if (RASR and 1) = 1 and then Base <= Integer_Address (SP) and then Base > Best then
                  Best := Base;
                  Size := 2 ** (Natural (Shift_Right (RASR, 1) and 16#1F#) + 1);
               end if;
            end;
         end if;
      end loop;
      return Best + Size;
   end Window_End;

   protected body Handler is
      procedure IRQ_Handler is
      begin
         Handler_Ran := True;
      end IRQ_Handler;
   end Handler;

   task body Digger is
      Target : Integer_Address;
   begin
      --  The FPU in use: a conversion and a multiply, then 1.5 computed from
      --  the volatile (no folding). FPCA is set from here on.
      Value := Float (Window_End mod 7) * 1.5;
      Value := Value - Value + 1.5;

      Window_Top := Window_End;
      Target     := Window_Top + 48;
      Ada.Text_IO.Put_Line ("parking 48 bytes above the window with the FPU in use, pending an interrupt");

      --  One instruction sequence: the stack pointer to Target, the interrupt
      --  pended, a spin. Nothing may touch the stack in between, so it is a
      --  single Asm. The interrupt's entry frame (104 bytes with the FPU
      --  active) then starts 56 bytes inside the window: the integer part's
      --  push faults (MSTKERR, a memory management fault, taken at the fault
      --  handlers' priority), and the lazily reserved FP area runs from 24
      --  bytes inside the window to the parked stack pointer.
      Asm ("mov sp, %0"      & ASCII.LF & ASCII.HT &
           "str %2, [%1]"    & ASCII.LF & ASCII.HT &
           "dsb"             & ASCII.LF & ASCII.HT &
           "isb"             & ASCII.LF &
           "0: b 0b",
           Inputs   => (Integer_Address'Asm_Input ("r", Target),
                        System.Address'Asm_Input ("r", NVIC_ISPR0),
                        Unsigned_32'Asm_Input ("r", IRQ_Mask)),
           Volatile => True);

      loop
         null;   --  not reached
      end loop;
   end Digger;

end Lazy_Probe;
