--  The start-up gives .sram12 and .sram4 their objects' initial values - the
--  implicit ones too - and their clocks before elaboration, and .axisram_bss
--  reads zero. At the end every object is overwritten with a pattern, so
--  that a later run that did not initialise them cannot pass on what this
--  run left (SRAM keeps its contents across a reset while powered).

with Ada.Text_IO;
with Interfaces; use Interfaces;

with Elaborated; use Elaborated;
with Placed; use Placed;

procedure Test is
   Zero : Boolean := True;
begin
   Ada.Text_IO.Put_Line (".sram12 access: null by default " & Boolean'Image (P12 = null));
   Ada.Text_IO.Put_Line (".sram12 table: initial values " & Boolean'Image (T12 = (1, 2, 3, 4)));
   Ada.Text_IO.Put_Line
     (".sram4 record: initial value " & Boolean'Image (R4.A = 16#1234_5678# and then R4.P = null));
   Ada.Text_IO.Put_Line
     (".sram12 record elaborated with its defaults "
      & Boolean'Image (D12.A = 16#1234_5678# and then D12.B = 16#9ABC_DEF0#));
   for W of Z loop
      Zero := Zero and then W = 0;
   end loop;
   Ada.Text_IO.Put_Line (".axisram_bss: zero " & Boolean'Image (Zero));

   P12 := Target'Access;
   T12 := (others => 16#DEAD_0000#);
   R4  := (A => 16#DEAD_0004#, P => Target'Access);
   D12 := (A => 0, B => 0);
   Z   := (others => 16#DEAD_00BB#);
   Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
end Test;
