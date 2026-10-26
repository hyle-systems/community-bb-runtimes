with Ada.Text_IO;
with Interfaces; use Interfaces;
with System;
with System.Storage_Elements; use System.Storage_Elements;

package body Test_LCH is

   Stack_Start : constant Character
     with Import, Convention => Asm, External_Name => "__fault_stack_start";
   Stack_End : constant Character
     with Import, Convention => Asm, External_Name => "__fault_stack_end";

   --  The number is printed with fixed buffers so that printing it costs
   --  the same as in test_fault_stack_use; the allocating part comes first.
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
      A    : Integer_Address := To_Integer (Stack_Start'Address);
      Top  : constant Integer_Address := To_Integer (Stack_End'Address);
      Used : Natural;
   begin
      --  What the default handler does, before the measurement: two lines
      --  built on the secondary stack and printed
      Ada.Text_IO.Put_Line
        ("Unhandled Ada Exception: " & Ada.Exceptions.Exception_Name (Except));
      Ada.Text_IO.Put_Line
        ("Message: " & Ada.Exceptions.Exception_Message (Except));
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
      Ada.Text_IO.Put ("fault path with an allocating handler used (rounded up to 256 bytes): ");
      Put_Number (((Used + 255) / 256) * 256);
      Ada.Text_IO.New_Line;
      Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
      loop
         null;
      end loop;
   end Last_Chance_Handler;

end Test_LCH;
