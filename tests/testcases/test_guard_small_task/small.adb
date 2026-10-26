with Ada.Text_IO;

package body Small is

   task body Small_Task is
   begin
      Ada.Text_IO.Put_Line ("task ran");
      loop
         null;
      end loop;
   end Small_Task;

end Small;
