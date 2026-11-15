--  An image entered unprivileged, as a bootloader that drops privilege
--  (CONTROL.nPRIV) before its jump would leave it. The start-up's first
--  access to the system control space, the cache invalidation, would then
--  take a BusFault into the vector table in force, so the start-up checks
--  CONTROL first and parks at __gnat_handover_unprivileged. Expected, as in
--  test_handover_in_handler: the first line once, then nothing, and the
--  runner finds the core in thread mode, still unprivileged. A start-up
--  that runs on faults, and its report adds a line.

with Ada.Text_IO;
with System.Machine_Code; use System.Machine_Code;

procedure Test is
begin
   Ada.Text_IO.Put_Line ("dropping privilege, then entering the image again");
   Asm ("mrs r0, control" & ASCII.LF & ASCII.HT
        & "orr r0, r0, #1" & ASCII.LF & ASCII.HT   --  nPRIV, SPSEL kept
        & "msr control, r0" & ASCII.LF & ASCII.HT
        & "isb" & ASCII.LF & ASCII.HT
        & "b _start_rom",
        Volatile => True, Clobber => "r0");
   Ada.Text_IO.Put_Line ("returned from the reset entry: not expected");
end Test;
