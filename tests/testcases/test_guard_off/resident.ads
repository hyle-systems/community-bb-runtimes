--  A task that only exists, so that the program links the tasking runtime.

with Ada.Synchronous_Task_Control;

package Resident is

   Never : Ada.Synchronous_Task_Control.Suspension_Object;

   task Keeper with Storage_Size => 4096;

end Resident;
