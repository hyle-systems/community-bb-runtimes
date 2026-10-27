with Ada.Text_IO;
with Interfaces; use Interfaces;
with System;
with System.Machine_Code; use System.Machine_Code;
with System.Storage_Elements; use System.Storage_Elements;

package body Test_LCH is

   Interrupt_Stack_End : constant Character
     with Import, Convention => Asm, External_Name => "__interrupt_stack_end";
   Interrupt_Stack_Start : constant Character
     with Import, Convention => Asm, External_Name => "__interrupt_stack_start";
   Fault_Stack_Start : constant Character
     with Import, Convention => Asm, External_Name => "__fault_stack_start";
   Fault_Stack_End : constant Character
     with Import, Convention => Asm, External_Name => "__fault_stack_end";
   --  The stack pointer at the fault, kept by the trap before it moves to
   --  the fault stack
   Fault_SP : constant Unsigned_32
     with Import, Convention => Asm, External_Name => "__gnat_fault_sp";

   procedure Last_Chance_Handler
     (Except : Ada.Exceptions.Exception_Occurrence)
   is
      Text  : constant String := Ada.Exceptions.Exception_Message (Except);
      First : Positive := Text'First;
      SP    : System.Address;
   begin
      Asm ("mov %0, sp", Outputs => System.Address'Asm_Output ("=r", SP), Volatile => True);
      for I in reverse Text'First .. Text'Last - 1 loop
         if Text (I) = ':' and then Text (I + 1) = ' ' then
            First := I + 2;
            exit;
         end if;
      end loop;
      Ada.Text_IO.Put_Line ("last chance: " & Text (First .. Text'Last));
      Ada.Text_IO.Put_Line
        ("reported on the fault stack: "
         & Boolean'Image (To_Integer (SP) >= To_Integer (Fault_Stack_Start'Address)
                          and then To_Integer (SP) < To_Integer (Fault_Stack_End'Address)));
      Ada.Text_IO.Put_Line
        ("faulting SP in the interrupt stack: "
         & Boolean'Image (Integer_Address (Fault_SP) >= To_Integer (Interrupt_Stack_Start'Address)
                          and then Integer_Address (Fault_SP) <= To_Integer (Interrupt_Stack_End'Address)));
      Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
      loop
         null;
      end loop;
   end Last_Chance_Handler;

end Test_LCH;
