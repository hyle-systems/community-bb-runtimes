with Ada.Text_IO;
with Interfaces; use Interfaces;

package body Digger is

   procedure Dig (N : Natural) is
      Frame : array (1 .. 64) of Unsigned_32 with Volatile;
   begin
      Frame (1) := Unsigned_32 (N);
      Depth := N;
      if N < 100_000 then
         Dig (N + 1);
      end if;
      Frame (64) := Frame (1);
   end Dig;

   task body Dig_Task is
   begin
      Ada.Text_IO.Put_Line ("digging");
      Dig (1);
      Ada.Text_IO.Put_Line ("bottom reached without a check");
   end Dig_Task;

end Digger;
