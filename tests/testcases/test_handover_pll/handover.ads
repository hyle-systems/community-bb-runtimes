--  A bootloader's hand-over, reproduced: the program prepares a state the
--  start-up must not assume away, disables interrupts, sets the main stack
--  pointer and branches to the reset entry (_start_rom) - no reset, so
--  every register and every RAM keep what the program left. A word in
--  SRAM4, which the start-up never zeroes (the section is NOLOAD) and a
--  system reset keeps, marks the second pass; the second pass clears it, so
--  the next run starts afresh. A mark alone is not enough: a run that
--  dies after marking (the start-up hanging on the prepared state, which
--  is what an unfixed start-up does) leaves it for the next run, which
--  would take its second pass at once. So the first pass also clears the
--  reset flags (RCC_RSR, RMVF), and the second pass is only the mark AND
--  no reset since - a mark found after a reset is stale and is cleared.
--  The word is written through to memory
--  (DCCMVAC), because the first pass leaves the data cache on and a dirty
--  line would be lost on a start-up that assumes the cache off.

with System;

package Handover is

   function Second_Pass return Boolean;
   --  True when the mark is set and no reset happened since the first pass
   --  cleared the reset flags; clears the mark either way

   procedure Mark;
   --  Clears the reset flags and sets the mark, written through to memory

   procedure Clean_Line (Addr : System.Address);
   --  Writes the data-cache line holding Addr back to memory (DCCMVAC)

   procedure Restart with No_Return;
   --  Interrupts off, the tick stopped, every interrupt disabled and
   --  unpended, the main stack pointer at its top, CONTROL and BASEPRI at
   --  their reset values, then the branch to _start_rom

end Handover;
