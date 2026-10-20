with Ada.Text_IO;
with Interfaces; use Interfaces;

package body Digger is

   procedure Big_Frame is
      Frame : array (1 .. 1280) of Unsigned_32 with Volatile;   -- 5 KB
   begin
      Frame (1) := 1;
      Depth := Natural (Frame (1));
      Frame (1280) := Frame (1);
   end Big_Frame;

   task body Dig_Task is
   begin
      Ada.Text_IO.Put_Line ("digging");
      Big_Frame;
      Ada.Text_IO.Put_Line ("the big frame fitted without a check");
   end Dig_Task;

end Digger;
