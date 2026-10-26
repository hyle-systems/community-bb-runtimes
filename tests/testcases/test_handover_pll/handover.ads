--  A bootloader's hand-over, reproduced: the program prepares a state the
--  start-up must not assume away, disables interrupts, sets the main stack
--  pointer and branches to the reset entry (_start_rom) - no reset, so
--  every register and every RAM keep what the program left. A word in
--  SRAM4, which the start-up never zeroes (the section is NOLOAD) and a
--  system reset keeps, marks the second pass; the second pass clears it, so
--  the next run starts afresh. The word is written through to memory
--  (DCCMVAC), because the first pass leaves the data cache on and a dirty
--  line would be lost on a start-up that assumes the cache off. A run that
--  dies between the mark and the branch leaves the mark for the next run,
--  which then reports a second pass without a hand-over; such a run is red
--  itself (no output), so the slip cannot pass unseen.

with System;

package Handover is

   function Second_Pass return Boolean;
   --  True when the mark is set; clears it

   procedure Mark;
   --  Sets the mark, written through to memory

   procedure Clean_Line (Addr : System.Address);
   --  Writes the data-cache line holding Addr back to memory (DCCMVAC)

   procedure Restart with No_Return;
   --  Interrupts off, the tick stopped, every interrupt disabled and
   --  unpended, the main stack pointer at its top, CONTROL and BASEPRI at
   --  their reset values, then the branch to _start_rom

end Handover;
