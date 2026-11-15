package body NMI is
   procedure Handler is
   begin
      Taken := Taken + 1;
   end Handler;
end NMI;
