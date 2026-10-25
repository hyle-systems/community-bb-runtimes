package Idle_Probe is

   task Blocker with Priority => 100, Storage_Size => 4096;

   Done : Boolean := False with Volatile;

end Idle_Probe;
