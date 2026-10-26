--  The same probe as test_ecc_initialised, linked for the RAM loader (opt.py):
--  the image occupies the start of the AXI SRAM and the start-up must
--  initialise the rest.
--  After the family's start-up, every word of the AXI SRAM and of the ITCM
--  carries a valid ECC (the start-up zeroes both with 64-bit stores before
--  the data cache is on), so sub-word writes and read-backs anywhere in
--  them raise no RAMECC flag. The probe uses the last kilobyte of each,
--  which the runtime's memory map places nothing in. Without the start-up's
--  zeroing the same program raises the flags on words nobody has written
--  since power-up (measured on the AXI SRAM: the monitor read 0x7).

with Ada.Text_IO;
with Interfaces; use Interfaces;
with System;

with ECC_Probe;

procedure Test is
   AXI_Last_KB  : constant System.Address := System'To_Address (16#2404_FC00#);
   ITCM_Last_KB : constant System.Address := System'To_Address (16#0000_FC00#);
   --  A reset keeps the SRAM's contents and ECC, so the monitors alone would
   --  pass on history after the first run that touched these words. The
   --  first word of the probe is left non-zero at the end of every run and
   --  must read zero at the start of the next: only the start-up's zeroing
   --  makes it so (the first run after a power cycle reads zero either way).
   Probe_Word : Unsigned_32 with Volatile, Import, Address => AXI_Last_KB;
   Zero_At_Start : constant Boolean := Probe_Word = 0;
begin
   Ada.Text_IO.Put_Line ("probe word zero at start (zeroed by the start-up): "
                         & Boolean'Image (Zero_At_Start));
   ECC_Probe.Clear (ECC_Probe.D1_AXI_SRAM);
   ECC_Probe.Clear (ECC_Probe.D1_ITCM);
   ECC_Probe.Clear (ECC_Probe.D1_Shared);

   ECC_Probe.Touch (AXI_Last_KB, 1024);
   ECC_Probe.Clean_Data_Cache (AXI_Last_KB, 1024);
   ECC_Probe.Touch (ITCM_Last_KB, 1024);

   ECC_Probe.Report ("AXI SRAM monitor after sub-word writes", ECC_Probe.D1_AXI_SRAM);
   ECC_Probe.Report ("ITCM monitor after sub-word writes", ECC_Probe.D1_ITCM);
   ECC_Probe.Report ("shared AXI/ITCM monitor", ECC_Probe.D1_Shared);
   Probe_Word := 16#5EED_0001#;   -- for the next run to find, unless zeroed
   ECC_Probe.Clean_Data_Cache (AXI_Last_KB, 32);   -- through to memory: the next start-up's invalidate would
                                                    -- discard a dirty line, and only Touch's byte would survive
   Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
end Test;
