--  Stack_Guard = true in a program with no tasking unit at all: the MPU must
--  be on (ENABLE + PRIVDEFENA = 5) with the two static guards programmed -
--  region 1 at the interrupt stack's start, region 2 at the environment
--  stack's start, each a 256-byte no-access window. The guard was programmed
--  only by the tasking runtime's CPU initialisation, which a program that
--  withs no tasking unit never links on light-tasking, so the option
--  protected nothing there (finding 6, 2026-10-21); the start-up now
--  programs the two static guards for every program (decision of
--  2026-10-21). Embedded initialises the tasking runtime for every program
--  and was guarded either way.

with Ada.Text_IO;
with Interfaces; use Interfaces;
with System;
with System.Storage_Elements; use System.Storage_Elements;

procedure Test is
   MPU_CTRL : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_ED94#);
   MPU_RNR  : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_ED98#);
   MPU_RBAR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_ED9C#);
   MPU_RASR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_EDA0#);

   --  The linker's symbols: the object's address is the symbol's value.
   Interrupt_Stack_Start : constant Character
     with Import, Convention => Asm, External_Name => "__interrupt_stack_start";
   Environment_Stack_Start : constant Character
     with Import, Convention => Asm, External_Name => "__stack_start";

   procedure Report (Region : Unsigned_32; Name : String; Expected : System.Address) is
      RBAR, RASR : Unsigned_32;
   begin
      MPU_RNR := Region;
      RBAR := MPU_RBAR;
      RASR := MPU_RASR;
      Ada.Text_IO.Put_Line
        ("region" & Unsigned_32'Image (Region) & " (" & Name & "): at its start "
         & Boolean'Image (Integer_Address (RBAR and not 16#1F#) = To_Integer (Expected))
         & " enabled " & Boolean'Image ((RASR and 1) = 1)
         & " 256 bytes " & Boolean'Image ((Shift_Right (RASR, 1) and 16#1F#) = 7)
         & " no access " & Boolean'Image ((Shift_Right (RASR, 24) and 7) = 0));
   end Report;
begin
   Ada.Text_IO.Put_Line ("MPU_CTRL =" & Unsigned_32'Image (MPU_CTRL));
   Report (1, "interrupt stack", Interrupt_Stack_Start'Address);
   Report (2, "environment stack", Environment_Stack_Start'Address);
   Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
end Test;
