--  Stack_Guard = true in a program with no tasking unit at all: the MPU must
--  be on (ENABLE + PRIVDEFENA = 5) with the static guards programmed -
--  region 2 at the environment stack's start, a 256-byte no-access window,
--  and region 1 at the interrupt stack's start where there is an interrupt
--  stack. The guard was programmed only by the tasking runtime's CPU
--  initialisation, which a program that withs no tasking unit never links on
--  light-tasking, so the option protected nothing there; the start-up now
--  programs the static guards for every program. Embedded initialises the
--  tasking runtime for every program and was guarded either way.
--
--  Region 1 follows the interrupt stack's length: on light-tasking a program
--  without a tasking unit has none (the section is empty, start = end), and
--  a window at its start would sit on the fault stack that follows it - the
--  report of any fault would then fault on its first push and come out as a
--  hard fault (test_guard_taskless_faultstack). So the line for region 1
--  states both facts in a form that holds on both profiles: the region is
--  programmed exactly when the stack has a length, and then it is at the
--  stack's start, 256 bytes, no access.

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
   Interrupt_Stack_End : constant Character
     with Import, Convention => Asm, External_Name => "__interrupt_stack_end";
   Environment_Stack_Start : constant Character
     with Import, Convention => Asm, External_Name => "__stack_start";

   procedure Read (Region : Unsigned_32; RBAR, RASR : out Unsigned_32) is
   begin
      MPU_RNR := Region;
      RBAR := MPU_RBAR;
      RASR := MPU_RASR;
   end Read;

   function At_Start (RBAR : Unsigned_32; Expected : System.Address) return Boolean is
     (Integer_Address (RBAR and not 16#1F#) = To_Integer (Expected));

   function Enabled (RASR : Unsigned_32) return Boolean is ((RASR and 1) = 1);

   function Window_256_No_Access (RASR : Unsigned_32) return Boolean is
     ((Shift_Right (RASR, 1) and 16#1F#) = 7 and then (Shift_Right (RASR, 24) and 7) = 0);

   RBAR, RASR : Unsigned_32;

begin
   Ada.Text_IO.Put_Line ("MPU_CTRL =" & Unsigned_32'Image (MPU_CTRL));

   declare
      Has_Length : constant Boolean :=
        To_Integer (Interrupt_Stack_Start'Address) /= To_Integer (Interrupt_Stack_End'Address);
   begin
      Read (1, RBAR, RASR);
      Ada.Text_IO.Put_Line
        ("region 1 (interrupt stack): programmed iff the stack has a length "
         & Boolean'Image (Enabled (RASR) = Has_Length)
         & ", and then at its start, 256 bytes, no access "
         & Boolean'Image
             (not Has_Length
              or else (At_Start (RBAR, Interrupt_Stack_Start'Address)
                       and then Window_256_No_Access (RASR))));
   end;

   Read (2, RBAR, RASR);
   Ada.Text_IO.Put_Line
     ("region 2 (environment stack): at its start "
      & Boolean'Image (At_Start (RBAR, Environment_Stack_Start'Address))
      & " enabled " & Boolean'Image (Enabled (RASR))
      & " 256 bytes, no access " & Boolean'Image (Window_256_No_Access (RASR)));

   Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
end Test;
