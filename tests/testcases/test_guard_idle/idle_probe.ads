--  A task that blocks fifty times, 2 ms apart, so that the idle task runs
--  between its blocks, then sets Done.

package Idle_Probe is

   task Blocker with Priority => 100, Storage_Size => 4096;

   Done : Boolean := False with Volatile;

end Idle_Probe;
