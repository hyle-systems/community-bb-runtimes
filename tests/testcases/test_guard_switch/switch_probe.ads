with System.Storage_Elements;

package Switch_Probe is

   task Digger with Priority => 100, Storage_Size => 4096;
   task Waker  with Priority => 200, Storage_Size => 2048;

   Headroom : System.Storage_Elements.Integer_Address := 0 with Volatile;
   --  Bytes between Digger's stack pointer at its deepest frame and the top
   --  of its guard window; the last-chance handler checks it against the band.

end Switch_Probe;
