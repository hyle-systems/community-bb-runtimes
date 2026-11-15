--  The test's NMI handler, exported under the vector table's weak name.

package NMI is

   procedure Handler
     with Export, Convention => C, External_Name => "__gnat_nmi_trap";

end NMI;
