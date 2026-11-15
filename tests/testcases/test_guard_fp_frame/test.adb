--  The guard window against the core's own exception frame. With the FPU
--  context active (CONTROL.FPCA) a frame is 104 bytes, of which lazy
--  stacking writes only the 32 integer bytes at entry, at the frame's
--  lowest addresses. The environment task puts its stack pointer 40 bytes
--  above its guard window, with an FP register in use, and waits there for
--  the SysTick. A window wider than that reach takes the frame's integer
--  part, and the stacking is reported as a memory management fault
--  (MSTKERR); a narrower one lets the 32 bytes land below it, unreported.

with System.Machine_Code; use System.Machine_Code;
with Ada.Text_IO;
with Ada.Real_Time;

with Test_LCH;    pragma Unreferenced (Test_LCH);
with Frame_Probe;

procedure Test is
   NL : constant String := ASCII.LF & ASCII.HT;
   --  Naming Ada.Real_Time links the tasking runtime, and with it the
   --  SysTick, in every profile
   Now : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
   pragma Unreferenced (Now);
begin
   --  With a window too narrow, the program prints the pattern below it
   --  damaged and no fault. Once the stacking has faulted, the fault's own
   --  entry frame lands below the window too (the escalation the README
   --  describes), so on that path the property is the report, not the
   --  pattern. No code of the task's own comes within 40 bytes of the
   --  window without touching it.
   Frame_Probe.Fill;
   Asm ("mov r4, sp" & NL
        & "movw r0, #:lower16:__stack_start" & NL
        & "movt r0, #:upper16:__stack_start" & NL
        & "movw r1, #:lower16:__stack_guard_bytes" & NL
        & "movt r1, #:upper16:__stack_guard_bytes" & NL
        & "add r0, r0, r1" & NL
        & "add r0, r0, #40" & NL
        & "vmov s0, r0" & NL                 --  the FP context active
        & "mov sp, r0" & NL
        & "movw r1, #0xC6C0" & NL           --  3 000 000 turns, a few ms:
        & "movt r1, #0x2D" & NL             --  several SysTick periods
        & "1: subs r1, r1, #1" & NL
        & "bne 1b" & NL
        & "mov sp, r4",
        Clobber => "r0,r1,r4,s0,memory", Volatile => True);
   Ada.Text_IO.Put_Line
     ("no fault; pattern below the stack intact: "
      & Boolean'Image (Frame_Probe.Intact));
   Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
end Test;
