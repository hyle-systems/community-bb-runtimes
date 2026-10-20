--  A task that touches the placed RAMs too, so the background map is also
--  checked from a task's context (its own stack guarded, its accesses
--  everywhere else). The task also makes this a tasking program: on
--  light-tasking the guard is installed by the tasking runtime's
--  initialisation, which a program without a tasking unit never runs
--  (test_guard_taskless).

with Ada.Synchronous_Task_Control;

package Worker is

   Done : Ada.Synchronous_Task_Control.Suspension_Object;

   OK : Boolean := False with Volatile;

   task T;

end Worker;
