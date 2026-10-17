with Ada.Text_IO;
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
        ("region" & Unsigned_32'Image (Region) & " (" & Label & "): enabled "
         & Boolean'Image ((RASR and 1) = 1)
         & " size" & Natural'Image (2 ** (Size_Code + 1))
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
      Report (0, "task", Self.Bottom_Of_Stack, Exact => False);
      Ada.Synchronous_Task_Control.Set_True (Task_Done);
   end Probe_Task;

end Guard_Probe;
