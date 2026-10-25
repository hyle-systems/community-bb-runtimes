with System.Storage_Elements;

package Switch_Probe is

   task Digger with Priority => 100, Storage_Size => 4096;
   task Waker  with Priority => 200, Storage_Size => 2048;

   Headroom : System.Storage_Elements.Integer_Address := 0 with Volatile;
   --  Bytes between Digger's deepest frame and the top of its guard window,
   --  for the last-chance handler to report as in or out of the band.

end Switch_Probe;
