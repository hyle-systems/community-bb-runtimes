with System.Storage_Elements;

package Lazy_Probe is

   task Digger with Priority => 100, Storage_Size => 4096;

   Headroom : System.Storage_Elements.Integer_Address := 0 with Volatile;
   Value    : Float := 0.0 with Volatile;

end Lazy_Probe;
