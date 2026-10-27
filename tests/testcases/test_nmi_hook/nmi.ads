package NMI is
   Taken : Natural := 0 with Volatile;

   procedure Handler
     with Export, Convention => C, External_Name => "__gnat_nmi_trap";
   --  The application's NMI handler, replacing the runtime's default (the
   --  fault report). The clock security system's HSE failure is the NMI an
   --  application must handle itself (RM0468 8.5: "the application has to
   --  clear the HSECSSF flag in the NMI ISR").
end NMI;
