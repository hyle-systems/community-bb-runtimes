--  Two tasks run double-precision chains, switching every millisecond with
--  d8-d15 loaded with patterns across each delay, while the main program
--  pends an FPU-using interrupt a thousand times and runs a chain of its
--  own. Every result must equal the one computed without any switch, and
--  every callee-saved register must come back from every delay unchanged.
--  Then the asynchronous half (Spinner): live values in all of d0-d15
--  across preemptions by a task and by an FPU-using interrupt.

with Ada.Real_Time; use Ada.Real_Time;
with Ada.Synchronous_Task_Control;
with Ada.Text_IO;
with Interfaces; use Interfaces;

with Chains;
with Spinner;

procedure Test is
   Main_X : Long_Float := 5.0;
   Expected_Main : Long_Float := 5.0;
   Next : Time := Clock;
begin
   for I in 1 .. 1000 loop
      Chains.Trigger_IRQ;
      Main_X := Main_X * 0.999 + 0.001;
      Next := Next + Microseconds (200);
      delay until Next;
   end loop;
   for I in 1 .. 1000 loop
      Expected_Main := Expected_Main * 0.999 + 0.001;
   end loop;

   Ada.Synchronous_Task_Control.Suspend_Until_True (Chains.Done_A);
   Ada.Synchronous_Task_Control.Suspend_Until_True (Chains.Done_B);

   Ada.Text_IO.Put_Line
     ("chain A exact: " & Boolean'Image (Chains.Result_A.Value = Chains.Expected_A));
   Ada.Text_IO.Put_Line
     ("chain B exact: " & Boolean'Image (Chains.Result_B.Value = Chains.Expected_B));
   Ada.Text_IO.Put_Line
     ("callee-saved FP registers kept across every switch: "
      & Boolean'Image (Chains.Result_A.Lost = 0 and then Chains.Result_B.Lost = 0));
   Ada.Text_IO.Put_Line
     ("main chain exact: " & Boolean'Image (Main_X = Expected_Main));
   Ada.Text_IO.Put_Line
     ("handler: served" & Unsigned_32'Image (Chains.Handler_Count)
      & " sum exact " & Boolean'Image (Chains.Handler_Sum = 125.0));

   Spinner.Start_Timer;
   Ada.Synchronous_Task_Control.Set_True (Spinner.Go_Poke);
   Ada.Synchronous_Task_Control.Set_True (Spinner.Go_Spin);
   Ada.Synchronous_Task_Control.Suspend_Until_True (Spinner.Done);
   Spinner.Stop_Timer;
   Ada.Text_IO.Put_Line
     ("live d0-d15 kept across asynchronous preemptions: "
      & Boolean'Image (Spinner.Rounds_Failed = 0));
   Ada.Text_IO.Put_Line
     ("preempted by the task more than 100 times: " & Boolean'Image (Spinner.Preemptions > 100)
      & ", by the interrupt more than 1000: " & Boolean'Image (Spinner.Interrupts > 1000));
   Ada.Text_IO.Put_Line ("===TEST COMPLETE===");
end Test;
