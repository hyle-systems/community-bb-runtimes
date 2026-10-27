------------------------------------------------------------------------------
--                                                                          --
--                  GNAT RUN-TIME LIBRARY (GNARL) COMPONENTS                --
--                                                                          --
--                      S Y S T E M . B B . F A U L T S                     --
--                                                                          --
--                                 B o d y                                  --
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

package body System.BB.Faults is

   Reporting : Boolean := False
     with Volatile, Export, Convention => Asm,
          External_Name => "__gnat_fault_reporting";
   --  Set by the first report. A fault inside the handling itself - the
   --  last-chance handler faulting, a second overflow - finds it set and
   --  parks below instead of reporting again without end. Cleared by the
   --  start-up right after the supply is valid (start-common.S): the fault
   --  vectors are live before .bss is zeroed, and the DTCM keeps the latch
   --  across a warm reset, so a fault in that window would otherwise find
   --  the previous run's latch and park silently. Zeroed with .bss
   --  at start-up, so the first fault after a reset reports; never reset
   --  afterwards, since a fault raised here does not come back to the
   --  program (the handler does not return).

   Cause : Interfaces.Unsigned_8 := 0
     with Volatile, Export, Convention => Asm,
          External_Name => "__gnat_fault_cause";
   --  Set by a fault the runtime raises on purpose, before the faulting
   --  instruction (handler.S, __gnat_stack_below_windows: 1, a task stack
   --  below four guard windows), so that the report names the cause rather
   --  than the vector

   ------------
   -- Report --
   ------------

   procedure Report (Vector : Interfaces.Unsigned_32) is
      use type Interfaces.Unsigned_8;
   begin
      if Reporting then
         loop
            exit when not Reporting;   --  never: parked, on the fault stack
         end loop;
      end if;
      Reporting := True;

      if Cause = 1 then
         raise Storage_Error with "task stack below four guard windows";
      end if;

      case Vector is
         when 2 =>
            raise Program_Error with "non-maskable interrupt";
         when 3 =>
            raise Program_Error with "hard fault";
         when 4 =>
            raise Storage_Error with "memory management fault";
         when 5 =>
            raise Program_Error with "bus fault";
         when 6 =>
            raise Constraint_Error with "usage fault";
         when others =>
            raise Program_Error with "unhandled trap";
      end case;
   end Report;

end System.BB.Faults;
