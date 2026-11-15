------------------------------------------------------------------------------
--                                                                          --
--                  GNAT RUN-TIME LIBRARY (GNARL) COMPONENTS                --
--                                                                          --
--                      S Y S T E M . B B . F A U L T S                     --
--                                                                          --
--                                 S p e c                                  --
--                                                                          --
--                    Copyright (C) 2026, Hyle Systems S.R.L.               --
--                                                                          --
-- GNAT is free software;  you can  redistribute it  and/or modify it under --
-- terms of the  GNU General Public License as published  by the Free Soft- --
-- ware  Foundation;  either version 3,  or (at your option) any later ver- --
-- sion.  GNAT is distributed in the hope that it will be useful, but WITH- --
-- OUT ANY WARRANTY;  without even the  implied warranty of MERCHANTABILITY --
-- or FITNESS FOR A PARTICULAR PURPOSE.                                     --
--                                                                          --
-- As a special exception under Section 7 of GPL version 3, you are granted --
-- additional permissions described in the GCC Runtime Library Exception,   --
-- version 3.1, as published by the Free Software Foundation.               --
--                                                                          --
-- You should have received a copy of the GNU General Public License and    --
-- a copy of the GCC Runtime Library Exception along with this program;     --
-- see the files COPYING3 and COPYING.RUNTIME respectively.  If not, see    --
-- <http://www.gnu.org/licenses/>.                                          --
--                                                                          --
------------------------------------------------------------------------------

--  Fault reporting for the stm32h7xx family. The fault trap in the vector
--  table (handler.S) passes the exception number from IPSR to Report, which
--  raises the fault as an Ada exception. The exception ends in the
--  last-chance handler in the form each profile expects: a message and a
--  line in light and light-tasking, an exception occurrence in embedded.
--  This is a libgnat unit, linked with the vector table in every program.

pragma Restrictions (No_Elaboration_Code);

with Interfaces;

package System.BB.Faults is
   pragma Preelaborate;

   procedure Report (Vector : Interfaces.Unsigned_32)
     with Export, Convention => C, External_Name => "__gnat_fault_report",
          No_Return;
   --  Vector is the exception number from IPSR: 2 NMI, 3 HardFault,
   --  4 MemManage, 5 BusFault, 6 UsageFault; any other is reported as an
   --  unhandled trap. Report runs in Handler mode on the fault stack the
   --  trap switched to, so it is reachable even when the stack that faulted
   --  has been destroyed. A fault inside the handling itself does not come
   --  back here: the trap sends it to __gnat_fault_in_fault (handler.S),
   --  which parks under a debugger and resets the board without one.

end System.BB.Faults;
