--  A bootloader's hand-over, reproduced. The first pass prepares a state the
--  start-up must not assume away and branches to the reset entry, _start_rom,
--  with interrupts disabled and without a reset, so every register and RAM
--  keeps what it left. A mark in SRAM4 tells the second pass from the first.

with System;

package Handover is

   --  The mark is a word in SRAM4 (.sram4_noinit), which the start-up neither
   --  loads nor zeroes and a system reset keeps. A run that dies after
   --  marking (a start-up hanging on the prepared state) would leave it, and
   --  the next run would take its second pass at once; so the first pass
   --  also clears the reset flags (RCC_RSR, RMVF), and a mark found after a
   --  reset is stale. The word is written through to memory (DCCMVAC): the
   --  first pass leaves the data cache on, and a start-up that assumes it
   --  off would lose a dirty line.

   function Second_Pass return Boolean;
   --  True when the mark is set and no reset happened since the first pass
   --  cleared the reset flags. Clears the mark either way, so the next run
   --  starts afresh.

   procedure Mark;
   --  Clears the reset flags and sets the mark, written through to memory.

   procedure Clean_Line (Addr : System.Address);
   --  Writes the data-cache line holding Addr back to memory (DCCMVAC).

   procedure Restart with No_Return;
   --  The branch to _start_rom the way a careless bootloader takes it: the
   --  tick running with its interrupt enabled and pending, a peripheral
   --  interrupt (TIM2, IRQ 28) enabled and pending, BASEPRI raised, lazy
   --  floating-point stacking off (FPCCR ASPEN and LSPEN clear), the main
   --  stack pointer at __stack_end, the thread on the process stack
   --  (CONTROL.SPSEL) at an address in the AXI SRAM, interrupts masked
   --  (PRIMASK). The start-up must clear what would interrupt it or the
   --  runtime and re-establish what the runtime assumes.

end Handover;
