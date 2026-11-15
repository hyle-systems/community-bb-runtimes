with Interfaces; use Interfaces;

with Placed; use Placed;

package body Worker is

   task body T is
      In_DTCM : Unsigned_32 with Volatile;
   begin
      --  Main has clocked SRAM1/2 by now: it suspends on Done only after
      --  its own touches.
      In_DTCM   := 16#D7C3_0011#;
      In_AXI    := 16#A51C_0012#;
      In_SRAM12 := 16#5112_0013#;
      In_SRAM4  := 16#5400_0014#;
      OK := In_DTCM = 16#D7C3_0011# and then In_AXI = 16#A51C_0012#
        and then In_SRAM12 = 16#5112_0013# and then In_SRAM4 = 16#5400_0014#;
      Ada.Synchronous_Task_Control.Set_True (Done);
   end T;

end Worker;
