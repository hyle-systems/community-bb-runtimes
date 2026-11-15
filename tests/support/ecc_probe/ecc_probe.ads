--  The RAM ECC monitors of the STM32H72x/H73x, and a probe that writes bytes
--  and half-words into a range of words and reads them back. A sub-word
--  write to a word nobody has written since power-up is a read-modify-write
--  against a garbage ECC, and the monitor flags it.

with Interfaces;
with System;

package ECC_Probe is

   subtype Word is Interfaces.Unsigned_32;

   --  Monitor status registers (RM0468 Rev 3, 3.3.3 Table 11 and 3.4).
   --  Monitor x's status register is at 0x24 + 0x20 * (x - 1) from its
   --  RAMECC base. RM0468 Table 7 gives the D1 base, 0x5200_9000, and the
   --  D2 base, 0x4802_3000. D3 is not listed there: its base, 0x5802_7000,
   --  comes from the vendor's STM32H723 SVD and matches the STM32H74x.
   D1_AXI_SRAM : constant System.Address := System'To_Address (16#5200_9024#);
   D1_ITCM     : constant System.Address := System'To_Address (16#5200_9044#);
   D1_D0TCM    : constant System.Address := System'To_Address (16#5200_9064#);
   D1_D1TCM    : constant System.Address := System'To_Address (16#5200_9084#);
   D1_Shared   : constant System.Address := System'To_Address (16#5200_90C4#);
   D2_SRAM1    : constant System.Address := System'To_Address (16#4802_3024#);
   D2_SRAM2    : constant System.Address := System'To_Address (16#4802_3044#);
   D3_SRAM4    : constant System.Address := System'To_Address (16#5802_7024#);
   D3_Backup   : constant System.Address := System'To_Address (16#5802_7044#);

   type Address_List is array (Positive range <>) of System.Address;

   procedure Clear (Monitor : System.Address);
   --  Clears the three flags; each is cleared by writing 0.

   function Flags (Monitor : System.Address) return Word;
   --  Returns the three flags: SEDCF in bit 0, DEDF in bit 1 and DEBWDF in
   --  bit 2.

   procedure Touch (First : System.Address; Bytes : Positive);
   --  For every 8 bytes from First, writes one byte and one half-word, then
   --  reads both words back (RM0468 2.4 asks for a read-back on the TCMs).

   procedure Clean_Data_Cache (First : System.Address; Bytes : Positive);
   --  Cleans the data cache lines covering the range (DCCMVAC, PM0253
   --  4.8.1) and waits, so that writes through a cacheable region reach the
   --  memory and its ECC logic before the monitors are read.

   procedure Report (Name : String; Monitor : System.Address);
   --  Prints "<Name>: <flags>".

end ECC_Probe;
