--  The hand-over of tests/support/handover (the mark, Second_Pass, Mark and
--  Clean_Line are described there), with a Restart that leaves more of a
--  bootloader's state behind.

with System;

package Handover is

   function Second_Pass return Boolean;

   procedure Mark;

   procedure Clean_Line (Addr : System.Address);

   procedure Restart with No_Return;
   --  The branch to _start_rom the way a careless bootloader takes it: the
   --  tick running with its interrupt enabled and pending, a peripheral
   --  interrupt (TIM2, IRQ 28) enabled and pending, BASEPRI raised, lazy
   --  floating-point stacking off (FPCCR ASPEN and LSPEN clear), the
   --  floating-point defaults changed (FPDSCR DN and FZ), deep sleep selected
   --  (SCR SLEEPDEEP, SEVONPEND), unaligned accesses trapped and bus faults
   --  ignored at priority -1 (CCR UNALIGN_TRP, BFHFNMIGN), both stack
   --  pointers at addresses of the bootloader's in the AXI SRAM, the thread
   --  on the process stack (CONTROL.SPSEL), interrupts and faults masked
   --  (PRIMASK, FAULTMASK).

end Handover;
