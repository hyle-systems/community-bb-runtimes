--  Z12 of the fourth review (PM0253 4.6.9: disable the unused regions before
--  enabling the MPU, in case it was programmed before): regions a bootloader
--  - or a debugger's reload without a reset - left enabled must be cleared
--  by the start-up's guard programming; only the two static guards remain.
--  No tasking unit here, so no context switch programs regions 0 or 3.

with Ada.Text_IO;
with Interfaces; use Interfaces;
with System;

with Handover;

procedure Test is
   MPU_CTRL : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_ED94#);
   MPU_RNR  : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_ED98#);
   MPU_RBAR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_ED9C#);
   MPU_RASR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_EDA0#);

   function Enabled (Region : Unsigned_32) return Boolean is
   begin
      MPU_RNR := Region;
      return (MPU_RASR and 1) = 1;
   end Enabled;
begin
   if Handover.Second_Pass then
      Ada.Text_IO.Put_Line ("second pass, after a hand-over with regions 3 and 7 enabled");
      Ada.Text_IO.Put_Line ("MPU on with the guard: " & Boolean'Image (MPU_CTRL = 5));
      Ada.Text_IO.Put_Line ("regions 3 and 7 cleared by the start-up: "
                            & Boolean'Image (not Enabled (3) and then not Enabled (7)));
      Ada.Text_IO.Put_Line ("the static guards in place (regions 1 and 2): "
                            & Boolean'Image (Enabled (1) and then Enabled (2)));
      Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
   else
      Ada.Text_IO.Put_Line ("first pass: regions 3 and 7 enabled over unused SRAM4, then the hand-over");
      for Region in Unsigned_32'(3) .. 7 loop
         if Region = 3 or else Region = 7 then
            MPU_RNR  := Region;
            MPU_RBAR := 16#3800_3000# + 32 * Region;   --  32 bytes, no access, execute never
            MPU_RASR := 16#1000_0000# or (4 * 2) or 1;
         end if;
      end loop;
      Handover.Mark;
      Handover.Restart;
   end if;
end Test;
