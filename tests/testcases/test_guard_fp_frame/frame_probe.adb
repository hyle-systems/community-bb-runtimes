with System;
with System.Storage_Elements; use System.Storage_Elements;
with Interfaces; use Interfaces;

package body Frame_Probe is

   Stack_Start : constant Character
     with Import, Convention => Asm, External_Name => "__stack_start";

   type Words is array (1 .. 32) of Unsigned_32 with Volatile_Components;

   Below : Words
     with Import, Address => Stack_Start'Address - 128;

   Pattern : constant Unsigned_32 := 16#A5A5_5A5A#;

   procedure Fill is
   begin
      for W of Below loop
         W := Pattern;
      end loop;
   end Fill;

   function Intact return Boolean is
   begin
      for W of Below loop
         if W /= Pattern then
            return False;
         end if;
      end loop;
      return True;
   end Intact;

end Frame_Probe;
