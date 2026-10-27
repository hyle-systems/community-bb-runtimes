------------------------------------------------------------------------------
--                                                                          --
--                  GNAT RUN-TIME LIBRARY (GNARL) COMPONENTS                --
--                                                                          --
--                   S Y S T E M . B B . P A R A M E T E R S                --
--                                                                          --
--                                  S p e c                                 --
--                                                                          --
--        Copyright (C) 1999-2002 Universidad Politecnica de Madrid         --
--             Copyright (C) 2003-2005 The European Space Agency            --
--                     Copyright (C) 2003-2021, AdaCore                     --
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
-- GNAT was originally developed  by the GNAT team at  New York University. --
-- Extensive contributions were provided by Ada Core Technologies Inc.      --
--                                                                          --
-- The port of GNARL to bare board targets was initially developed by the   --
-- Real-Time Systems Group at the Technical University of Madrid.           --
--                                                                          --
------------------------------------------------------------------------------
pragma Restrictions (No_Elaboration_Code);

--  This package defines basic parameters used by the low level tasking system.
--  These parameters are in this package in order to isolate target
--  dependencies.

--  This is the STM32H7 (Arm Cortex-M7, ARMv7E-M) version of this package

with System.BB.Board_Parameters;
with System.BB.MCU_Parameters;

with STM32H7xx_Runtime_Config;
with STM32H7xx_Runtime_Profile;

package System.BB.Parameters is
   pragma Preelaborate (System.BB.Parameters);

   Clock_Frequency  : constant := Board_Parameters.Main_Clock_Frequency;
   Ticks_Per_Second : constant := Board_Parameters.Main_Clock_Frequency;

   --  The tasking runtimes take a SysTick interrupt every millisecond, of a
   --  few hundred processor cycles: below 1 MHz the tick would take most
   --  of the processor or all of it (a CSI divided by 512 gives a 7-cycle
   --  tick). A light crate has no tick.
   pragma Compile_Time_Error
     (STM32H7xx_Runtime_Profile.Has_Tasking
        and then Clock_Frequency < 1_000_000,
      "The CPU clock is below 1 MHz: the tasking runtimes' 1 ms tick would"
        & " take the processor (raise the clock or lower D1CPRE)");

   ----------------
   -- Interrupts --
   ----------------

   subtype Cortex_Priority_Bits_Width is Integer range 1 .. 8;
   --  The number of bits used by the hardware for priority levels, i.e.,
   --  within the BASEPRI register and IP priority registers. Priorities are
   --  at most eight bits wide but usually fewer. The value varies both with
   --  vendor and chip.

   NVIC_Priority_Bits : constant Cortex_Priority_Bits_Width := 4;
   --  The number of bits allocated by this specific hardware implementation.

   subtype Interrupt_Range is Integer
     range -1 .. MCU_Parameters.Number_Of_Interrupts;
   --  Number of interrupts for the interrupt controller

   Trap_Vectors : constant := 17;
   --  While on this target there is little difference between interrupts
   --  and traps, we consider the following traps:
   --
   --    Name                        Nr
   --
   --    Reset_Vector                 1
   --    NMI_Vector                   2
   --    Hard_Fault_Vector            3
   --    Mem_Manage_Vector            4
   --    Bus_Fault_Vector             5
   --    Usage_Fault_Vector           6
   --    SVC_Vector                  11
   --    Debug_Mon_Vector            12
   --    Pend_SV_Vector              14
   --    Sys_Tick_Vector             15
   --    Interrupt_Request_Vector    16
   --
   --  These trap vectors correspond to different low-level trap handlers in
   --  the run time. Note that as all interrupt requests (IRQs) will use the
   --  same interrupt wrapper, there is no benefit to using separate vectors
   --  for each.

   Context_Buffer_Capacity : constant := 10;
   --  The context buffer contains registers r4 .. r11 and the SP_process
   --  (PSP). The size is rounded up to an even number for alignment

   ------------
   -- Stacks --
   ------------

   Interrupt_Stack_Size : constant :=
     STM32H7xx_Runtime_Config.Interrupt_Stack_Size;

   Stack_Guard : constant Boolean := STM32H7xx_Runtime_Config.Stack_Guard;
   Stack_Guard_Bytes : constant := STM32H7xx_Runtime_Config.Stack_Guard_Bytes;
   --  An MPU no-access window under every stack (System.BB.CPU_Primitives,
   --  "MPU stack guard"); off by default.

   Fault_Stack_Size : constant := STM32H7xx_Runtime_Config.Fault_Stack_Size;
   --  The stack every fault's handling runs on: the fault trap switches to
   --  it before the report (handler.S, the linker scripts). In every profile.

   --  The three options above act in the tasking runtimes only: the light
   --  runtime has no interrupt stack, no context switch and no MPU code of
   --  its own (the start-up's guard block is skipped with the option off). A
   --  light crate refuses them rather than accept a guard that guards
   --  nothing (the defaults repeated here are the manifest's).
   pragma Compile_Time_Error
     (not STM32H7xx_Runtime_Profile.Has_Tasking
        and then (Stack_Guard or else Stack_Guard_Bytes /= 32
                  or else Interrupt_Stack_Size /= 4096),
      "Stack_Guard, Stack_Guard_Bytes and Interrupt_Stack_Size have no"
        & " effect in the light profile; remove them from the crate's"
        & " configuration values");

   --  On embedded a fault's handling - the raise in System.BB.Faults.Report,
   --  the unwinder and the last-chance handler - uses 1792 bytes of the
   --  fault stack with a handler of fixed buffers (test_fault_stack_use)
   --  and 2048 with one that builds its lines through the secondary stack
   --  as the default handler does (test_fault_stack_use_alloc, both rounded
   --  up to 256); the floor holds the latter with half again. Light-
   --  tasking's handler is a direct call and needs no floor.
   pragma Compile_Time_Error
     (STM32H7xx_Runtime_Profile.Has_Exception_Propagation
        and then Fault_Stack_Size < 3072,
      "Fault_Stack_Size on embedded must be at least 3072 bytes: a fault's"
        & " handling runs on the fault stack");

   --  The interrupt stack carries the tick's handler and the scheduler on
   --  the tasking runtimes: a floor of 1 KB. (A fault's handling has its
   --  own stack; the guard's four-windows rule is in CPU_Primitives.)
   pragma Compile_Time_Error
     (STM32H7xx_Runtime_Profile.Has_Tasking
        and then Interrupt_Stack_Size < 1024,
      "Interrupt_Stack_Size must be at least 1024 bytes on the tasking"
        & " runtimes");

   package Cfg renames STM32H7xx_Runtime_Config;

   --  The core-supply arrangement must exist on the part (RM0468 6.4,
   --  Table 30). The STM32H723 and STM32H733 have no SMPS step-down
   --  converter: on them the byte of an arrangement that uses it is an
   --  invalid combination, ignored, and the write-once lock then holds the
   --  register with ACTVOSRDY never set, until a power cycle (6.8.4). The
   --  STM32H725 and STM32H735 have the converter; the STM32H730 exists both
   --  ways (the Q suffix), so it is not checked.
   pragma Compile_Time_Error
     (Cfg.MCU_Sub_Family in Cfg.H723 | Cfg.H733
        and then Cfg.Supply_Configuration not in Cfg.LDO | Cfg.Bypass,
      "This part has no SMPS step-down converter: Supply_Configuration"
        & " must be LDO or Bypass on the STM32H723 and STM32H733");

   --  The flash size follows the part: STM32H730 128 KB (B) only, STM32H733
   --  and STM32H735 1 MB (G) only, STM32H723 and STM32H725 512 KB (E) or
   --  1 MB (G). A map larger than the flash links a program that does not
   --  fit the device.
   pragma Compile_Time_Error
     ((Cfg.MCU_Sub_Family in Cfg.H730
         and then Cfg.MCU_Flash_Memory_Size not in Cfg.B)
      or else (Cfg.MCU_Sub_Family in Cfg.H733 | Cfg.H735
               and then Cfg.MCU_Flash_Memory_Size not in Cfg.G)
      or else (Cfg.MCU_Sub_Family in Cfg.H723 | Cfg.H725
               and then Cfg.MCU_Flash_Memory_Size in Cfg.B),
      "MCU_Flash_Memory_Size does not exist on this part: the STM32H730 is"
        & " B (128 KB), the STM32H733 and STM32H735 G (1 MB), the STM32H723"
        & " and STM32H725 E (512 KB) or G");

   --  The converter's output when it feeds the LDO: DS13311 Table 14 lists
   --  the "SMPS supplies LDO" source at VOS0 only with the converter at
   --  2.5 V (its note 2); 1.8 V into the LDO is listed from VOS1 down. The
   --  scaling itself is reachable from every source on this family: the
   --  LDO-only limit on VOS0 belongs to the STM32H74x/75x (SYSCFG ODEN).
   pragma Compile_Time_Error
     (Cfg.Voltage_Scaling in Cfg.VOS0
        and then Cfg.Supply_Configuration
          in Cfg.SMPS_1V8_Supplies_LDO
           | Cfg.SMPS_1V8_Supplies_External_And_LDO,
      "At VOS0 a converter that feeds the LDO must output 2.5 V (DS13311"
        & " Table 14): use the SMPS_2V5 arrangement, or VOS1 to VOS3");

   Has_FPU : constant Boolean := True;
   --  Set to true if core has a FPU

   Has_VTOR : constant Boolean := True;
   --  Set to true if core has a Vector Table Offset Register (VTOR).
   --  VTOR is implemented in Cortex-M0+, Cortex-M4 and above.

   Has_OS_Extensions : constant Boolean := True;
   --  Set to true if core has armv6-m OS extensions (PendSV, MSP, PSP,
   --  etc...).

   Is_ARMv6m : constant Boolean := False;
   --  Set to true if core is an armv6-m (Cortex-M0, Cortex-M0+, Cortex-M1)

   ----------
   -- CPUs --
   ----------

   Max_Number_Of_CPUs : constant := 1;
   --  Maximum number of CPUs

   Multiprocessor : constant Boolean := Max_Number_Of_CPUs /= 1;
   --  Are we on a multiprocessor board?

end System.BB.Parameters;
