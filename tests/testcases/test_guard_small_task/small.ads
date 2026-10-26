package Small is

   task Small_Task with Priority => 100, Storage_Size => 600;
   --  600 bytes under a 512-byte window: the window, rounded up to its
   --  alignment inside the stack, cannot fit, and the stack is below the
   --  four windows the README asks for

end Small;
