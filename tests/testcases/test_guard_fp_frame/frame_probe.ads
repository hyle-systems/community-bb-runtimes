--  The 32 words below the environment stack's guard window: the top of the
--  fault stack, which nothing uses until a fault.

package Frame_Probe is

   procedure Fill;

   function Intact return Boolean;

end Frame_Probe;
