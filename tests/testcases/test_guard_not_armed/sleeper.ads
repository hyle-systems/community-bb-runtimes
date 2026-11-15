--  A task that only waits, so that the program uses tasking.

with Ada.Synchronous_Task_Control;

package Sleeper is

   Never : Ada.Synchronous_Task_Control.Suspension_Object;

   task Waiter with Storage_Size => 4096;

end Sleeper;
