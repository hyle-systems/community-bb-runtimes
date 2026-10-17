--  One task that only exists: the stack guard, like the rest of the tasking
--  runtime, is initialised when a program uses tasking; a program without
--  tasks links none of it and has no guard and no checks.

with Ada.Synchronous_Task_Control;

package Resident is

   Never : Ada.Synchronous_Task_Control.Suspension_Object;

   task Keeper with Storage_Size => 4096;

end Resident;
