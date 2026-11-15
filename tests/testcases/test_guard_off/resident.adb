package body Resident is

   task body Keeper is
   begin
      Ada.Synchronous_Task_Control.Suspend_Until_True (Never);
   end Keeper;

end Resident;
