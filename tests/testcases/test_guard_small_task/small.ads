package Small is

   task Small_Task with Priority => 100, Storage_Size => 600;
   --  Below the 1024 bytes of four 256-byte windows (opt.py), which the
   --  README's sizing rule requires of every guarded stack. It prints
   --  "task ran" only if the runtime lets it start.

end Small;
