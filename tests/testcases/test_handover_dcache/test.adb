--  A bootloader that leaves the data cache on. The
--  start-up zeroes the ECC RAMs and then invalidates the data cache by set
--  and way before enabling it; a cache that was already on holds the zero
--  lines dirty, and an invalidate without a clean throws them away. The
--  observable here: lines the first pass dirties over SRAM4 (which the
--  start-up never zeroes) and leaves in the cache must reach memory across
--  the hand-over - a start-up that finds the cache on must clean before it
--  invalidates. The base values are written through first, so a lost line
--  reads as the base value, not as noise.

with Ada.Text_IO;
with Interfaces; use Interfaces;
with System;

with Handover;
with Dcache_Lines; use Dcache_Lines;

procedure Test is
   CCR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_ED14#);

   Written_Back : Natural := 0;
begin
   if Handover.Second_Pass then
      Ada.Text_IO.Put_Line ("second pass, after a hand-over with the data cache on");
      for I in Words'Range loop
         if Words (I) = 16#2222_0000# + Unsigned_32 (I) then
            Written_Back := Written_Back + 1;
         end if;
      end loop;
      Ada.Text_IO.Put_Line
        ("dirty lines written back across the hand-over: " & Boolean'Image (Written_Back = Words'Length));
      Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
   else
      Ada.Text_IO.Put_Line ("first pass: dirty lines over SRAM4, the data cache left on, then the hand-over");
      Ada.Text_IO.Put_Line ("data cache on: " & Boolean'Image ((CCR and 2 ** 16) /= 0));
      for I in Words'Range loop
         Words (I) := 16#1111_0000# + Unsigned_32 (I);
      end loop;
      for I in 0 .. 7 loop
         Handover.Clean_Line (Words (8 * I)'Address);   --  the base values, in memory
      end loop;
      for I in Words'Range loop
         Words (I) := 16#2222_0000# + Unsigned_32 (I);   --  dirty, in the cache only
      end loop;
      Handover.Mark;
      Handover.Restart;
   end if;
end Test;
