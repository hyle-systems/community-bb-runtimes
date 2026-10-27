with Ada.Text_IO;
with System.Machine_Code; use System.Machine_Code;
with System.BB.Threads;
with System.Storage_Elements; use System.Storage_Elements;

package body Guard_Probe is

   use Interfaces;

   MPU_RNR  : Unsigned_32 with Volatile, Import,
     Address => System'To_Address (16#E000_ED98#);
   MPU_RBAR : Unsigned_32 with Volatile, Import,
     Address => System'To_Address (16#E000_ED9C#);
   MPU_RASR : Unsigned_32 with Volatile, Import,
     Address => System'To_Address (16#E000_EDA0#);

   ------------
   -- Report --
   -----------------
   -- Task_Region --
   -----------------

   --  The running task's window is in region 12 or 15 (the runtime alternates
   --  them across context switches): the enabled one whose base is below
   --  the stack pointer and nearest to it; 99 when neither is.
   function Task_Region return Unsigned_32 is
      SP   : Unsigned_32;
      Best : Integer_Address := 0;
      Hit  : Unsigned_32 := 99;
   begin
      Asm ("mov %0, sp", Outputs => Unsigned_32'Asm_Output ("=r", SP), Volatile => True);
      for Region in Unsigned_32'(12) .. 15 loop
         if Region = 12 or else Region = 15 then
            MPU_RNR := Region;
            declare
               RBAR : constant Unsigned_32 := MPU_RBAR;
               RASR : constant Unsigned_32 := MPU_RASR;
               Base : constant Integer_Address := Integer_Address (RBAR and not 16#1F#);
            begin
               if (RASR and 1) = 1 and then Base <= Integer_Address (SP) and then Base > Best then
                  Best := Base;
                  Hit := Region;
               end if;
            end;
         end if;
      end loop;
      return Hit;
   end Task_Region;

   ------------

   procedure Report (Region : Unsigned_32;
                     Label  : String;
                     Bottom : System.Address;
                     Exact  : Boolean)
   is
      RBAR, RASR : Unsigned_32;
      Base       : Integer_Address;
      Size_Code  : Natural;
      Lower      : constant Integer_Address := To_Integer (Bottom);
   begin
      MPU_RNR := Region;
      RBAR := MPU_RBAR;
      RASR := MPU_RASR;
      Base := Integer_Address (RBAR and not 16#1F#);
      Size_Code := Natural (Shift_Right (RASR, 1) and 16#1F#);
      Ada.Text_IO.Put_Line
        ("region" & (if Label = "task" then " 12/15" else Unsigned_32'Image (Region)) & " (" & Label & "): enabled "
         & Boolean'Image ((RASR and 1) = 1)
         & " size" & Natural'Image (2 ** (Size_Code + 1))
         --  SRD, bits 15:8: a disabled subregion would leave part of the
         --  window open (PM0253 4.6.6); a window of 256 bytes or more has
         --  subregions, and none may be disabled
         & " whole " & Boolean'Image ((Shift_Right (RASR, 8) and 16#FF#) = 0)
         & " no access " & Boolean'Image ((Shift_Right (RASR, 24) and 7) = 0)
         & " xn " & Boolean'Image ((Shift_Right (RASR, 28) and 1) = 1)
         & (if Exact
            then " base at bottom " & Boolean'Image (Base = Lower)
            else " base in window "
              & Boolean'Image (Base >= Lower and then Base < Lower + Guard_Bytes)));
   end Report;

   ----------------
   -- Probe_Task --
   ----------------

   task body Probe_Task is
      Self : constant System.BB.Threads.Thread_Id := System.BB.Threads.Thread_Self;
   begin
      Report (Task_Region, "task", Self.Bottom_Of_Stack, Exact => False);
      Ada.Synchronous_Task_Control.Set_True (Task_Done);
   end Probe_Task;

end Guard_Probe;
