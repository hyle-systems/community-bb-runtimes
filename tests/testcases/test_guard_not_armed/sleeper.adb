package body Sleeper is

   task body Waiter is
   begin
      Ada.Synchronous_Task_Control.Suspend_Until_True (Never);
   end Waiter;

end Sleeper;
