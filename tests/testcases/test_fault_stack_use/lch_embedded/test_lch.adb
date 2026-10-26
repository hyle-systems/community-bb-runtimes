with Ada.Text_IO;
with Interfaces; use Interfaces;
with System;
with System.Storage_Elements; use System.Storage_Elements;

package body Test_LCH is

   Stack_Start : constant Character
     with Import, Convention => Asm, External_Name => "__fault_stack_start";
   Stack_End : constant Character
     with Import, Convention => Asm, External_Name => "__fault_stack_end";

   --  Fixed buffers and Put only, so that the number is the path's alone
   --  (the secondary stack in handler mode is the interrupted task's and
   --  works; test_fault_stack_use_alloc measures a handler that uses it).
   procedure Put_Number (N : Natural) is
      R : String (1 .. 8) := (others => ' ');
      X : Natural := N;
      I : Natural := R'Last;
   begin
      loop
         R (I) := Character'Val (Character'Pos ('0') + X mod 10);
         X := X / 10;
         exit when X = 0;
         I := I - 1;
      end loop;
      Ada.Text_IO.Put (R (I .. R'Last));
   end Put_Number;

   procedure Last_Chance_Handler
     (Except : Ada.Exceptions.Exception_Occurrence)
   is
      pragma Unreferenced (Except);
      A    : Integer_Address := To_Integer (Stack_Start'Address);
      Top  : constant Integer_Address := To_Integer (Stack_End'Address);
      Used : Natural;
   begin
      --  The lowest word the path touched: the first that is not the pattern
      loop
         declare
            W : Unsigned_32 with Volatile, Import, Address => To_Address (A);
         begin
            exit when W /= 16#5AFE_5AFE# or else A >= Top;
         end;
         A := A + 4;
      end loop;
      Used := Natural (Top - A);
      Ada.Text_IO.Put ("fault path used (rounded up to 256 bytes): ");
      Put_Number (((Used + 255) / 256) * 256);
      Ada.Text_IO.New_Line;
      Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
      loop
         null;
      end loop;
   end Last_Chance_Handler;

end Test_LCH;
