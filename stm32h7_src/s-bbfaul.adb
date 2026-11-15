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
   --  The re-entry latch. The fault trap (handler.S) sets it before keeping
   --  the first fault's evidence. A fault inside the handling itself (the
   --  last-chance handler faulting, a second overflow) or an NMI during it
   --  finds the latch set and goes to __gnat_fault_in_fault (see Report's
   --  spec), instead of reporting again without end.

   --  The latch is in .data, and the start-up also clears it right after
   --  the supply is valid (start-common.S). The fault vectors are live
   --  before .data is loaded, and the DTCM keeps the latch across a warm
   --  reset, so a fault in that interval would otherwise find the previous
   --  run's latch. It is never reset afterwards: a reported fault never
   --  returns to the program.

   Cause : Interfaces.Unsigned_8 := 0
     with Volatile, Export, Convention => Asm,
          External_Name => "__gnat_fault_cause";
   --  Set by a fault that the runtime raises on purpose, just before the
   --  undefined instruction that raises it, so the report names the cause
   --  rather than the vector: handler.S sets 1 in __gnat_stack_below_windows
   --  and 2 in __gnat_guard_not_armed. Report reads it only for a UsageFault
   --  with CFSR.UNDEFINSTR kept, so an interrupt that faults between the
   --  store and the instruction reports its own fault, unless that fault is
   --  also an undefined instruction. The byte is in .data, and the start-up
   --  clears it with the latch, for the same reason.

   Kept_CFSR : constant Interfaces.Unsigned_32
     with Volatile, Import, Convention => Asm,
          External_Name => "__gnat_fault_cfsr";
   --  CFSR as the fault trap (handler.S) kept it at the first fault.

   ------------
   -- Report --
   ------------

   procedure Report (Vector : Interfaces.Unsigned_32) is
      use type Interfaces.Unsigned_8;
      use type Interfaces.Unsigned_32;
   begin
      if Vector = 6 and then (Kept_CFSR and 2 ** 16) /= 0 then
         if Cause = 1 then
            raise Storage_Error with "task stack below four guard windows";
         elsif Cause = 2 then
            raise Program_Error with "stack guard not armed by the start-up";
         end if;
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
