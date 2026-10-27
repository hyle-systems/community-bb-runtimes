with Interfaces; use Interfaces;
with System.Machine_Code; use System.Machine_Code;
with System.Storage_Elements; use System.Storage_Elements;
with Ada.Text_IO;

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

   procedure Last_Chance_Handler
     (Except : Ada.Exceptions.Exception_Occurrence)
   is
      Text  : constant String := Ada.Exceptions.Exception_Message (Except);
      First : Positive := Text'First;
   begin
      --  Keep what follows the last ": "
      for I in reverse Text'First .. Text'Last - 1 loop
         if Text (I) = ':' and then Text (I + 1) = ' ' then
            First := I + 2;
            exit;
         end if;
      end loop;
      Ada.Text_IO.Put_Line ("last chance: " & Text (First .. Text'Last));
      Ada.Text_IO.Put_Line ("in the fault path's context: " & Boolean'Image (Fault_Context));
      Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
      loop
         null;
      end loop;
   end Last_Chance_Handler;

end Test_LCH;
