--  A task that touches the placed RAMs too, checking the background map
--  from a task's context with its own stack guarded. It also makes this a
--  tasking program, so the task regions (12, 15) join the start-up's
--  static guards, which are all a taskless program gets.

with Ada.Synchronous_Task_Control;

package Worker is

   Done : Ada.Synchronous_Task_Control.Suspension_Object;

   OK : Boolean := False with Volatile;

   task T;

end Worker;
