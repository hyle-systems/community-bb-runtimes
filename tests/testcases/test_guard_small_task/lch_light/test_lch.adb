with Interfaces; use Interfaces;
with System.Machine_Code; use System.Machine_Code;
with Ada.Text_IO;
with System.Storage_Elements; use System.Storage_Elements;

package body Test_LCH is

   Fault_Stack_Start : constant Character
     with Import, Convention => Asm, External_Name => "__fault_stack_start";
   Fault_Stack_End : constant Character
     with Import, Convention => Asm, External_Name => "__fault_stack_end";

   --  The context the report runs in, as for a fault: on the fault stack
   --  (not on the interrupt stack or the stack that failed), with every
   --  interrupt held off (PRIMASK, or a fault exception's own priority)
   function Fault_Context return Boolean is
      SP, PM, IPSR : Unsigned_32;
   begin
      Asm ("mov %0, sp", Outputs => Unsigned_32'Asm_Output ("=r", SP), Volatile => True);
      Asm ("mrs %0, primask", Outputs => Unsigned_32'Asm_Output ("=r", PM), Volatile => True);
      Asm ("mrs %0, ipsr", Outputs => Unsigned_32'Asm_Output ("=r", IPSR), Volatile => True);
      return SP >= Unsigned_32 (To_Integer (Fault_Stack_Start'Address))
        and then SP < Unsigned_32 (To_Integer (Fault_Stack_End'Address))
        and then ((PM and 1) = 1 or else (IPSR and 16#1FF#) in 2 .. 6);
   end Fault_Context;

   procedure Last_Chance_Handler (Msg : System.Address; Line : Integer) is
      pragma Unreferenced (Line);
      Text  : String (1 .. 200);
      Last  : Natural := 0;
      First : Positive := 1;
   begin
      --  Msg is a NUL-terminated string
      for I in Text'Range loop
         declare
            C : constant Character
              with Import, Address => Msg + Storage_Offset (I - 1);
         begin
            exit when C = ASCII.NUL;
            Text (I) := C;
            Last := I;
         end;
      end loop;
      --  Keep what follows the last ": "
      for I in reverse 1 .. Last - 1 loop
         if Text (I) = ':' and then Text (I + 1) = ' ' then
            First := I + 2;
            exit;
         end if;
      end loop;
      Ada.Text_IO.Put_Line ("last chance: " & Text (First .. Last));
      Ada.Text_IO.Put_Line ("in the fault path's context: " & Boolean'Image (Fault_Context));
      Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
      loop
         null;
      end loop;
   end Last_Chance_Handler;

end Test_LCH;
