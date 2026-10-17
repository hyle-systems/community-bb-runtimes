--  Reads the MPU regions the stack guard programs and checks each against
--  the stack it is meant to guard: region 1 against the interrupt stack,
--  region 2 against the environment stack (both from the linker's symbols),
--  region 0 against the running task's own stack, read from inside a task.

with Ada.Synchronous_Task_Control;
with Interfaces;
with System;

package Guard_Probe is

   Guard_Bytes : constant := 256;
   --  Must equal the crate's Stack_Guard_Bytes (opt.py)

   procedure Report (Region : Interfaces.Unsigned_32;
                     Label  : String;
                     Bottom : System.Address);
   --  Select Region, print its enable, size, access and execute-never
   --  fields and whether its base lies in [Bottom, Bottom + Guard_Bytes - 1],
   --  the window the runtime documents (the lowest Guard_Bytes-aligned
   --  address at or above the stack's bottom).

   Task_Done : Ada.Synchronous_Task_Control.Suspension_Object;

   task Probe_Task with Storage_Size => 4096;

end Guard_Probe;
