--
--  Copyright (C) 2026, AdaCore
--

pragma Style_Checks (Off);

--  This spec has been automatically generated from STM32H723.svd
--  (version 1.7, Keil STM32H7xx_DFP 4.1.3)


with System;

package Interfaces.STM32.Flash is
   pragma Preelaborate;
   pragma No_Elaboration_Code_All;

   ---------------
   -- Registers --
   ---------------

   subtype ACR_LATENCY_Field is Interfaces.STM32.UInt4;
   subtype ACR_WRHIGHFREQ_Field is Interfaces.STM32.UInt2;

   --  Access control register
   type ACR_Register is record
      --  Read latency
      LATENCY       : ACR_LATENCY_Field := 16#7#;
      --  Flash signal delay
      WRHIGHFREQ    : ACR_WRHIGHFREQ_Field := 16#3#;
      --  unspecified
      Reserved_6_31 : Interfaces.STM32.UInt26 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for ACR_Register use record
      LATENCY       at 0 range 0 .. 3;
      WRHIGHFREQ    at 0 range 4 .. 5;
      Reserved_6_31 at 0 range 6 .. 31;
   end record;

   subtype CR_LOCK_Field is Interfaces.STM32.Bit;
   subtype CR_PG_Field is Interfaces.STM32.Bit;
   subtype CR_SER_Field is Interfaces.STM32.Bit;
   subtype CR_BER_Field is Interfaces.STM32.Bit;
   subtype CR_PSIZE_Field is Interfaces.STM32.UInt2;
   subtype CR_FW_Field is Interfaces.STM32.Bit;
   subtype CR_START_Field is Interfaces.STM32.Bit;
   subtype CR_SNB_Field is Interfaces.STM32.UInt3;
   subtype CR_CRC_EN_Field is Interfaces.STM32.Bit;
   subtype CR_EOPIE_Field is Interfaces.STM32.Bit;
   subtype CR_WRPERRIE_Field is Interfaces.STM32.Bit;
   subtype CR_PGSERRIE_Field is Interfaces.STM32.Bit;
   subtype CR_STRBERRIE_Field is Interfaces.STM32.Bit;
   subtype CR_INCERRIE_Field is Interfaces.STM32.Bit;
   subtype CR_OPERRIE_Field is Interfaces.STM32.Bit;
   subtype CR_RDPERRIE_Field is Interfaces.STM32.Bit;
   subtype CR_RDSERRIE_Field is Interfaces.STM32.Bit;
   subtype CR_SNECCERRIE_Field is Interfaces.STM32.Bit;
   subtype CR_DBECCERRIE_Field is Interfaces.STM32.Bit;
   subtype CR_CRCENDIE_Field is Interfaces.STM32.Bit;
   subtype CR_CRCRDERRIE_Field is Interfaces.STM32.Bit;

   --  FLASH control register
   type CR_Register is record
      --  configuration lock bit
      LOCK           : CR_LOCK_Field := 16#0#;
      --  program enable bit
      PG             : CR_PG_Field := 16#0#;
      --  sector erase request
      SER            : CR_SER_Field := 16#0#;
      --  erase request
      BER            : CR_BER_Field := 16#0#;
      --  program size
      PSIZE          : CR_PSIZE_Field := 16#0#;
      --  write forcing control bit
      FW             : CR_FW_Field := 16#0#;
      --  bank or sector erase start control bit
      START          : CR_START_Field := 16#0#;
      --  sector erase selection number
      SNB            : CR_SNB_Field := 16#0#;
      --  unspecified
      Reserved_11_14 : Interfaces.STM32.UInt4 := 16#0#;
      --  CRC control bit
      CRC_EN         : CR_CRC_EN_Field := 16#0#;
      --  end-of-program interrupt control bit
      EOPIE          : CR_EOPIE_Field := 16#0#;
      --  write protection error interrupt enable bit
      WRPERRIE       : CR_WRPERRIE_Field := 16#0#;
      --  programming sequence error interrupt enable bit
      PGSERRIE       : CR_PGSERRIE_Field := 16#0#;
      --  strobe error interrupt enable bit
      STRBERRIE      : CR_STRBERRIE_Field := 16#0#;
      --  unspecified
      Reserved_20_20 : Interfaces.STM32.Bit := 16#0#;
      --  inconsistency error interrupt enable bit
      INCERRIE       : CR_INCERRIE_Field := 16#0#;
      --  write/erase error interrupt enable bit
      OPERRIE        : CR_OPERRIE_Field := 16#0#;
      --  read protection error interrupt enable bit
      RDPERRIE       : CR_RDPERRIE_Field := 16#0#;
      --  secure error interrupt enable bit
      RDSERRIE       : CR_RDSERRIE_Field := 16#0#;
      --  ECC single correction error interrupt enable bit
      SNECCERRIE     : CR_SNECCERRIE_Field := 16#0#;
      --  ECC double detection error interrupt enable bit
      DBECCERRIE     : CR_DBECCERRIE_Field := 16#0#;
      --  end of CRC calculation interrupt enable bit
      CRCENDIE       : CR_CRCENDIE_Field := 16#0#;
      --  CRC read error interrupt enable bit When CRCRDERRIE1 bit is set to 1,
      --  an interrupt is generated when a protected area (PCROP or
      --  secure-only) has been detected during the last CRC computation on
      --  bank 1. CRCRDERRIE1 can be programmed only when LOCK1 is cleared to
      --  0.
      CRCRDERRIE     : CR_CRCRDERRIE_Field := 16#0#;
      --  unspecified
      Reserved_29_31 : Interfaces.STM32.UInt3 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CR_Register use record
      LOCK           at 0 range 0 .. 0;
      PG             at 0 range 1 .. 1;
      SER            at 0 range 2 .. 2;
      BER            at 0 range 3 .. 3;
      PSIZE          at 0 range 4 .. 5;
      FW             at 0 range 6 .. 6;
      START          at 0 range 7 .. 7;
      SNB            at 0 range 8 .. 10;
      Reserved_11_14 at 0 range 11 .. 14;
      CRC_EN         at 0 range 15 .. 15;
      EOPIE          at 0 range 16 .. 16;
      WRPERRIE       at 0 range 17 .. 17;
      PGSERRIE       at 0 range 18 .. 18;
      STRBERRIE      at 0 range 19 .. 19;
      Reserved_20_20 at 0 range 20 .. 20;
      INCERRIE       at 0 range 21 .. 21;
      OPERRIE        at 0 range 22 .. 22;
      RDPERRIE       at 0 range 23 .. 23;
      RDSERRIE       at 0 range 24 .. 24;
      SNECCERRIE     at 0 range 25 .. 25;
      DBECCERRIE     at 0 range 26 .. 26;
      CRCENDIE       at 0 range 27 .. 27;
      CRCRDERRIE     at 0 range 28 .. 28;
      Reserved_29_31 at 0 range 29 .. 31;
   end record;

   subtype SR_BSY_Field is Interfaces.STM32.Bit;
   subtype SR_WBNE_Field is Interfaces.STM32.Bit;
   subtype SR_QW_Field is Interfaces.STM32.Bit;
   subtype SR_CRC_BUSY_Field is Interfaces.STM32.Bit;
   subtype SR_EOP_Field is Interfaces.STM32.Bit;
   subtype SR_WRPERR_Field is Interfaces.STM32.Bit;
   subtype SR_PGSERR_Field is Interfaces.STM32.Bit;
   subtype SR_STRBERR_Field is Interfaces.STM32.Bit;
   subtype SR_INCERR_Field is Interfaces.STM32.Bit;
   subtype SR_OPERR_Field is Interfaces.STM32.Bit;
   subtype SR_RDPERR_Field is Interfaces.STM32.Bit;
   subtype SR_RDSERR_Field is Interfaces.STM32.Bit;
   subtype SR_SNECCERR_Field is Interfaces.STM32.Bit;
   subtype SR_DBECCERR_Field is Interfaces.STM32.Bit;
   subtype SR_CRCEND_Field is Interfaces.STM32.Bit;
   subtype SR_CRCRDERR_Field is Interfaces.STM32.Bit;

   --  FLASH status register for bank 1
   type SR_Register is record
      --  ongoing program flag
      BSY            : SR_BSY_Field := 16#0#;
      --  write buffer not empty flag
      WBNE           : SR_WBNE_Field := 16#0#;
      --  wait queue flag
      QW             : SR_QW_Field := 16#0#;
      --  CRC busy flag
      CRC_BUSY       : SR_CRC_BUSY_Field := 16#0#;
      --  unspecified
      Reserved_4_15  : Interfaces.STM32.UInt12 := 16#0#;
      --  end-of-program flag
      EOP            : SR_EOP_Field := 16#0#;
      --  write protection error flag
      WRPERR         : SR_WRPERR_Field := 16#0#;
      --  programming sequence error flag
      PGSERR         : SR_PGSERR_Field := 16#0#;
      --  strobe error flag
      STRBERR        : SR_STRBERR_Field := 16#0#;
      --  unspecified
      Reserved_20_20 : Interfaces.STM32.Bit := 16#0#;
      --  inconsistency error flag
      INCERR         : SR_INCERR_Field := 16#0#;
      --  write/erase error flag
      OPERR          : SR_OPERR_Field := 16#0#;
      --  read protection error flag
      RDPERR         : SR_RDPERR_Field := 16#0#;
      --  secure error flag
      RDSERR         : SR_RDSERR_Field := 16#0#;
      --  single correction error flag
      SNECCERR       : SR_SNECCERR_Field := 16#0#;
      --  ECC double detection error flag
      DBECCERR       : SR_DBECCERR_Field := 16#0#;
      --  CRC-complete flag
      CRCEND         : SR_CRCEND_Field := 16#0#;
      --  Read-only. CRC read error flag CRCRDERR1 flag is raised when a word
      --  is found read protected during a CRC operation on bank 1. An
      --  interrupt is generated if CRCRDIE1 and CRCEND1 are set to 1. Writing
      --  1 to CLR_CRCRDERR1 bit in FLASH_CCR1 register clears CRCRDERR1. Note:
      --  This flag is valid only when CRCEND1 bit is set to 1
      CRCRDERR       : SR_CRCRDERR_Field := 16#0#;
      --  unspecified
      Reserved_29_31 : Interfaces.STM32.UInt3 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for SR_Register use record
      BSY            at 0 range 0 .. 0;
      WBNE           at 0 range 1 .. 1;
      QW             at 0 range 2 .. 2;
      CRC_BUSY       at 0 range 3 .. 3;
      Reserved_4_15  at 0 range 4 .. 15;
      EOP            at 0 range 16 .. 16;
      WRPERR         at 0 range 17 .. 17;
      PGSERR         at 0 range 18 .. 18;
      STRBERR        at 0 range 19 .. 19;
      Reserved_20_20 at 0 range 20 .. 20;
      INCERR         at 0 range 21 .. 21;
      OPERR          at 0 range 22 .. 22;
      RDPERR         at 0 range 23 .. 23;
      RDSERR         at 0 range 24 .. 24;
      SNECCERR       at 0 range 25 .. 25;
      DBECCERR       at 0 range 26 .. 26;
      CRCEND         at 0 range 27 .. 27;
      CRCRDERR       at 0 range 28 .. 28;
      Reserved_29_31 at 0 range 29 .. 31;
   end record;

   subtype CCR_CLR_EOP_Field is Interfaces.STM32.Bit;
   subtype CCR_CLR_WRPERR_Field is Interfaces.STM32.Bit;
   subtype CCR_CLR_PGSERR_Field is Interfaces.STM32.Bit;
   subtype CCR_CLR_STRBERR_Field is Interfaces.STM32.Bit;
   subtype CCR_CLR_INCERR_Field is Interfaces.STM32.Bit;
   subtype CCR_CLR_OPERR_Field is Interfaces.STM32.Bit;
   subtype CCR_CLR_RDPERR_Field is Interfaces.STM32.Bit;
   subtype CCR_CLR_RDSERR_Field is Interfaces.STM32.Bit;
   subtype CCR_CLR_SNECCERR_Field is Interfaces.STM32.Bit;
   subtype CCR_CLR_DBECCERR_Field is Interfaces.STM32.Bit;
   subtype CCR_CLR_CRCEND_Field is Interfaces.STM32.Bit;
   subtype CCR_CLR_CRCRDERR_Field is Interfaces.STM32.Bit;

   --  FLASH clear control register for bank 1
   type CCR_Register is record
      --  unspecified
      Reserved_0_15  : Interfaces.STM32.UInt16 := 16#0#;
      --  EOP1 flag clear bit
      CLR_EOP        : CCR_CLR_EOP_Field := 16#0#;
      --  WRPERR1 flag clear bit
      CLR_WRPERR     : CCR_CLR_WRPERR_Field := 16#0#;
      --  PGSERR flag clear bi
      CLR_PGSERR     : CCR_CLR_PGSERR_Field := 16#0#;
      --  STRBERR flag clear bit
      CLR_STRBERR    : CCR_CLR_STRBERR_Field := 16#0#;
      --  unspecified
      Reserved_20_20 : Interfaces.STM32.Bit := 16#0#;
      --  INCERR flag clear bit
      CLR_INCERR     : CCR_CLR_INCERR_Field := 16#0#;
      --  OPERR flag clear bit
      CLR_OPERR      : CCR_CLR_OPERR_Field := 16#0#;
      --  RDPERR flag clear bit
      CLR_RDPERR     : CCR_CLR_RDPERR_Field := 16#0#;
      --  RDSERR flag clear bit
      CLR_RDSERR     : CCR_CLR_RDSERR_Field := 16#0#;
      --  SNECCERR flag clear bit
      CLR_SNECCERR   : CCR_CLR_SNECCERR_Field := 16#0#;
      --  DBECCERR flag clear bit
      CLR_DBECCERR   : CCR_CLR_DBECCERR_Field := 16#0#;
      --  CRCEND flag clear bit
      CLR_CRCEND     : CCR_CLR_CRCEND_Field := 16#0#;
      --  Write-only. CRCRDERR1 flag clear bit Setting this bit to 1 resets to
      --  0 CRCRDERR1 flag in FLASH_SR1 register.
      CLR_CRCRDERR   : CCR_CLR_CRCRDERR_Field := 16#0#;
      --  unspecified
      Reserved_29_31 : Interfaces.STM32.UInt3 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CCR_Register use record
      Reserved_0_15  at 0 range 0 .. 15;
      CLR_EOP        at 0 range 16 .. 16;
      CLR_WRPERR     at 0 range 17 .. 17;
      CLR_PGSERR     at 0 range 18 .. 18;
      CLR_STRBERR    at 0 range 19 .. 19;
      Reserved_20_20 at 0 range 20 .. 20;
      CLR_INCERR     at 0 range 21 .. 21;
      CLR_OPERR      at 0 range 22 .. 22;
      CLR_RDPERR     at 0 range 23 .. 23;
      CLR_RDSERR     at 0 range 24 .. 24;
      CLR_SNECCERR   at 0 range 25 .. 25;
      CLR_DBECCERR   at 0 range 26 .. 26;
      CLR_CRCEND     at 0 range 27 .. 27;
      CLR_CRCRDERR   at 0 range 28 .. 28;
      Reserved_29_31 at 0 range 29 .. 31;
   end record;

   subtype OPTCR_OPTLOCK_Field is Interfaces.STM32.Bit;
   subtype OPTCR_OPTSTART_Field is Interfaces.STM32.Bit;
   subtype OPTCR_OPTCHANGEERRIE_Field is Interfaces.STM32.Bit;

   --  FLASH option control register
   type OPTCR_Register is record
      --  FLASH_OPTCR lock option configuration bit
      OPTLOCK        : OPTCR_OPTLOCK_Field := 16#0#;
      --  Option byte start change option configuration bit
      OPTSTART       : OPTCR_OPTSTART_Field := 16#0#;
      --  unspecified
      Reserved_2_29  : Interfaces.STM32.UInt28 := 16#0#;
      --  Option byte change error interrupt enable bit
      OPTCHANGEERRIE : OPTCR_OPTCHANGEERRIE_Field := 16#0#;
      --  unspecified
      Reserved_31_31 : Interfaces.STM32.Bit := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for OPTCR_Register use record
      OPTLOCK        at 0 range 0 .. 0;
      OPTSTART       at 0 range 1 .. 1;
      Reserved_2_29  at 0 range 2 .. 29;
      OPTCHANGEERRIE at 0 range 30 .. 30;
      Reserved_31_31 at 0 range 31 .. 31;
   end record;

   subtype OPTSR_CUR_OPT_BUSY_Field is Interfaces.STM32.Bit;
   subtype OPTSR_CUR_BOR_LEV_Field is Interfaces.STM32.UInt2;
   subtype OPTSR_CUR_IWDG1_SW_Field is Interfaces.STM32.Bit;
   subtype OPTSR_CUR_NRST_STOP_D1_Field is Interfaces.STM32.Bit;
   subtype OPTSR_CUR_NRST_STBY_D1_Field is Interfaces.STM32.Bit;
   subtype OPTSR_CUR_RDP_Field is Interfaces.STM32.Byte;
   subtype OPTSR_CUR_IWDG_FZ_STOP_Field is Interfaces.STM32.Bit;
   subtype OPTSR_CUR_IWDG_FZ_SDBY_Field is Interfaces.STM32.Bit;
   subtype OPTSR_CUR_ST_RAM_SIZE_Field is Interfaces.STM32.UInt2;
   subtype OPTSR_CUR_SECURITY_Field is Interfaces.STM32.Bit;
   subtype OPTSR_CUR_IO_HSLV_Field is Interfaces.STM32.Bit;
   subtype OPTSR_CUR_OPTCHANGEERR_Field is Interfaces.STM32.Bit;

   --  FLASH option status register
   type OPTSR_CUR_Register is record
      --  Option byte change ongoing flag
      OPT_BUSY       : OPTSR_CUR_OPT_BUSY_Field := 16#0#;
      --  unspecified
      Reserved_1_1   : Interfaces.STM32.Bit := 16#0#;
      --  Brownout level option status bit
      BOR_LEV        : OPTSR_CUR_BOR_LEV_Field := 16#0#;
      --  IWDG1 control option status bit
      IWDG1_SW       : OPTSR_CUR_IWDG1_SW_Field := 16#0#;
      --  unspecified
      Reserved_5_5   : Interfaces.STM32.Bit := 16#0#;
      --  D1 DStop entry reset option status bit
      NRST_STOP_D1   : OPTSR_CUR_NRST_STOP_D1_Field := 16#0#;
      --  D1 DStandby entry reset option status bit
      NRST_STBY_D1   : OPTSR_CUR_NRST_STBY_D1_Field := 16#0#;
      --  Readout protection level option status byte
      RDP            : OPTSR_CUR_RDP_Field := 16#0#;
      --  unspecified
      Reserved_16_16 : Interfaces.STM32.Bit := 16#0#;
      --  IWDG Stop mode freeze option status bit
      IWDG_FZ_STOP   : OPTSR_CUR_IWDG_FZ_STOP_Field := 16#0#;
      --  IWDG Standby mode freeze option status bit
      IWDG_FZ_SDBY   : OPTSR_CUR_IWDG_FZ_SDBY_Field := 16#0#;
      --  DTCM RAM size option status
      ST_RAM_SIZE    : OPTSR_CUR_ST_RAM_SIZE_Field := 16#0#;
      --  Security enable option status bit
      SECURITY       : OPTSR_CUR_SECURITY_Field := 16#0#;
      --  unspecified
      Reserved_22_28 : Interfaces.STM32.UInt7 := 16#0#;
      --  I/O high-speed at low-voltage status bit (PRODUCT_BELOW_25V)
      IO_HSLV        : OPTSR_CUR_IO_HSLV_Field := 16#0#;
      --  Option byte change error flag
      OPTCHANGEERR   : OPTSR_CUR_OPTCHANGEERR_Field := 16#0#;
      --  unspecified
      Reserved_31_31 : Interfaces.STM32.Bit := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for OPTSR_CUR_Register use record
      OPT_BUSY       at 0 range 0 .. 0;
      Reserved_1_1   at 0 range 1 .. 1;
      BOR_LEV        at 0 range 2 .. 3;
      IWDG1_SW       at 0 range 4 .. 4;
      Reserved_5_5   at 0 range 5 .. 5;
      NRST_STOP_D1   at 0 range 6 .. 6;
      NRST_STBY_D1   at 0 range 7 .. 7;
      RDP            at 0 range 8 .. 15;
      Reserved_16_16 at 0 range 16 .. 16;
      IWDG_FZ_STOP   at 0 range 17 .. 17;
      IWDG_FZ_SDBY   at 0 range 18 .. 18;
      ST_RAM_SIZE    at 0 range 19 .. 20;
      SECURITY       at 0 range 21 .. 21;
      Reserved_22_28 at 0 range 22 .. 28;
      IO_HSLV        at 0 range 29 .. 29;
      OPTCHANGEERR   at 0 range 30 .. 30;
      Reserved_31_31 at 0 range 31 .. 31;
   end record;

   subtype OPTSR_PRG_BOR_LEV_Field is Interfaces.STM32.UInt2;
   subtype OPTSR_PRG_IWDG1_SW_Field is Interfaces.STM32.Bit;
   subtype OPTSR_PRG_NRST_STOP_D1_Field is Interfaces.STM32.Bit;
   subtype OPTSR_PRG_NRST_STBY_D1_Field is Interfaces.STM32.Bit;
   subtype OPTSR_PRG_RDP_Field is Interfaces.STM32.Byte;
   subtype OPTSR_PRG_IWDG_FZ_STOP_Field is Interfaces.STM32.Bit;
   subtype OPTSR_PRG_IWDG_FZ_SDBY_Field is Interfaces.STM32.Bit;
   subtype OPTSR_PRG_ST_RAM_SIZE_Field is Interfaces.STM32.UInt2;
   subtype OPTSR_PRG_SECURITY_Field is Interfaces.STM32.Bit;
   subtype OPTSR_PRG_IO_HSLV_Field is Interfaces.STM32.Bit;

   --  FLASH option status register
   type OPTSR_PRG_Register is record
      --  unspecified
      Reserved_0_1   : Interfaces.STM32.UInt2 := 16#0#;
      --  BOR reset level option configuration bits
      BOR_LEV        : OPTSR_PRG_BOR_LEV_Field := 16#0#;
      --  IWDG1 option configuration bit
      IWDG1_SW       : OPTSR_PRG_IWDG1_SW_Field := 16#0#;
      --  unspecified
      Reserved_5_5   : Interfaces.STM32.Bit := 16#0#;
      --  Option byte erase after D1 DStop option configuration bit
      NRST_STOP_D1   : OPTSR_PRG_NRST_STOP_D1_Field := 16#0#;
      --  Option byte erase after D1 DStandby option configuration bit
      NRST_STBY_D1   : OPTSR_PRG_NRST_STBY_D1_Field := 16#0#;
      --  Readout protection level option configuration byte
      RDP            : OPTSR_PRG_RDP_Field := 16#0#;
      --  unspecified
      Reserved_16_16 : Interfaces.STM32.Bit := 16#0#;
      --  IWDG Stop mode freeze option configuration bit
      IWDG_FZ_STOP   : OPTSR_PRG_IWDG_FZ_STOP_Field := 16#0#;
      --  IWDG Standby mode freeze option configuration bit
      IWDG_FZ_SDBY   : OPTSR_PRG_IWDG_FZ_SDBY_Field := 16#0#;
      --  DTCM size select option configuration bits
      ST_RAM_SIZE    : OPTSR_PRG_ST_RAM_SIZE_Field := 16#0#;
      --  Security option configuration bit
      SECURITY       : OPTSR_PRG_SECURITY_Field := 16#0#;
      --  unspecified
      Reserved_22_28 : Interfaces.STM32.UInt7 := 16#0#;
      --  I/O high-speed at low-voltage (PRODUCT_BELOW_25V)
      IO_HSLV        : OPTSR_PRG_IO_HSLV_Field := 16#0#;
      --  unspecified
      Reserved_30_31 : Interfaces.STM32.UInt2 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for OPTSR_PRG_Register use record
      Reserved_0_1   at 0 range 0 .. 1;
      BOR_LEV        at 0 range 2 .. 3;
      IWDG1_SW       at 0 range 4 .. 4;
      Reserved_5_5   at 0 range 5 .. 5;
      NRST_STOP_D1   at 0 range 6 .. 6;
      NRST_STBY_D1   at 0 range 7 .. 7;
      RDP            at 0 range 8 .. 15;
      Reserved_16_16 at 0 range 16 .. 16;
      IWDG_FZ_STOP   at 0 range 17 .. 17;
      IWDG_FZ_SDBY   at 0 range 18 .. 18;
      ST_RAM_SIZE    at 0 range 19 .. 20;
      SECURITY       at 0 range 21 .. 21;
      Reserved_22_28 at 0 range 22 .. 28;
      IO_HSLV        at 0 range 29 .. 29;
      Reserved_30_31 at 0 range 30 .. 31;
   end record;

   subtype OPTCCR_CLR_OPTCHANGEERR_Field is Interfaces.STM32.Bit;

   --  FLASH option clear control register
   type OPTCCR_Register is record
      --  unspecified
      Reserved_0_29    : Interfaces.STM32.UInt30 := 16#0#;
      --  Write-only. OPTCHANGEERR reset bit
      CLR_OPTCHANGEERR : OPTCCR_CLR_OPTCHANGEERR_Field := 16#0#;
      --  unspecified
      Reserved_31_31   : Interfaces.STM32.Bit := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for OPTCCR_Register use record
      Reserved_0_29    at 0 range 0 .. 29;
      CLR_OPTCHANGEERR at 0 range 30 .. 30;
      Reserved_31_31   at 0 range 31 .. 31;
   end record;

   subtype PRAR_CUR_PROT_AREA_START_Field is Interfaces.STM32.UInt12;
   subtype PRAR_CUR_PROT_AREA_END_Field is Interfaces.STM32.UInt12;
   subtype PRAR_CUR_DMEP_Field is Interfaces.STM32.Bit;

   --  FLASH protection address for bank 1
   type PRAR_CUR_Register is record
      --  Read-only. lowest PCROP protected address
      PROT_AREA_START : PRAR_CUR_PROT_AREA_START_Field;
      --  unspecified
      Reserved_12_15  : Interfaces.STM32.UInt4;
      --  Read-only. highest PCROP protected address
      PROT_AREA_END   : PRAR_CUR_PROT_AREA_END_Field;
      --  unspecified
      Reserved_28_30  : Interfaces.STM32.UInt3;
      --  Read-only. PCROP protected erase enable option status bit
      DMEP            : PRAR_CUR_DMEP_Field;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for PRAR_CUR_Register use record
      PROT_AREA_START at 0 range 0 .. 11;
      Reserved_12_15  at 0 range 12 .. 15;
      PROT_AREA_END   at 0 range 16 .. 27;
      Reserved_28_30  at 0 range 28 .. 30;
      DMEP            at 0 range 31 .. 31;
   end record;

   subtype PRAR_PRG_PROT_AREA_START_Field is Interfaces.STM32.UInt12;
   subtype PRAR_PRG_PROT_AREA_END_Field is Interfaces.STM32.UInt12;
   subtype PRAR_PRG_DMEP_Field is Interfaces.STM32.Bit;

   --  FLASH protection address for bank 1
   type PRAR_PRG_Register is record
      --  lowest PCROP protected address configuration
      PROT_AREA_START : PRAR_PRG_PROT_AREA_START_Field := 16#0#;
      --  unspecified
      Reserved_12_15  : Interfaces.STM32.UInt4 := 16#0#;
      --  highest PCROP protected address configuration
      PROT_AREA_END   : PRAR_PRG_PROT_AREA_END_Field := 16#0#;
      --  unspecified
      Reserved_28_30  : Interfaces.STM32.UInt3 := 16#0#;
      --  PCROP protected erase enable option configuration bit
      DMEP            : PRAR_PRG_DMEP_Field := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for PRAR_PRG_Register use record
      PROT_AREA_START at 0 range 0 .. 11;
      Reserved_12_15  at 0 range 12 .. 15;
      PROT_AREA_END   at 0 range 16 .. 27;
      Reserved_28_30  at 0 range 28 .. 30;
      DMEP            at 0 range 31 .. 31;
   end record;

   subtype SCAR_CUR_SEC_AREA_START_Field is Interfaces.STM32.UInt12;
   subtype SCAR_CUR_SEC_AREA_END_Field is Interfaces.STM32.UInt12;
   subtype SCAR_CUR_DMES_Field is Interfaces.STM32.Bit;

   --  FLASH secure address for bank 1
   type SCAR_CUR_Register is record
      --  lowest secure protected address
      SEC_AREA_START : SCAR_CUR_SEC_AREA_START_Field := 16#0#;
      --  unspecified
      Reserved_12_15 : Interfaces.STM32.UInt4 := 16#0#;
      --  highest secure protected address
      SEC_AREA_END   : SCAR_CUR_SEC_AREA_END_Field := 16#0#;
      --  unspecified
      Reserved_28_30 : Interfaces.STM32.UInt3 := 16#0#;
      --  secure protected erase enable option status bit
      DMES           : SCAR_CUR_DMES_Field := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for SCAR_CUR_Register use record
      SEC_AREA_START at 0 range 0 .. 11;
      Reserved_12_15 at 0 range 12 .. 15;
      SEC_AREA_END   at 0 range 16 .. 27;
      Reserved_28_30 at 0 range 28 .. 30;
      DMES           at 0 range 31 .. 31;
   end record;

   subtype SCAR_PRG_SEC_AREA_START_Field is Interfaces.STM32.UInt12;
   subtype SCAR_PRG_SEC_AREA_END_Field is Interfaces.STM32.UInt12;
   subtype SCAR_PRG_DMES_Field is Interfaces.STM32.Bit;

   --  FLASH secure address for bank 1
   type SCAR_PRG_Register is record
      --  lowest secure protected address configuration
      SEC_AREA_START : SCAR_PRG_SEC_AREA_START_Field := 16#0#;
      --  unspecified
      Reserved_12_15 : Interfaces.STM32.UInt4 := 16#0#;
      --  highest secure protected address configuration
      SEC_AREA_END   : SCAR_PRG_SEC_AREA_END_Field := 16#0#;
      --  unspecified
      Reserved_28_30 : Interfaces.STM32.UInt3 := 16#0#;
      --  secure protected erase enable option configuration bit
      DMES           : SCAR_PRG_DMES_Field := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for SCAR_PRG_Register use record
      SEC_AREA_START at 0 range 0 .. 11;
      Reserved_12_15 at 0 range 12 .. 15;
      SEC_AREA_END   at 0 range 16 .. 27;
      Reserved_28_30 at 0 range 28 .. 30;
      DMES           at 0 range 31 .. 31;
   end record;

   subtype WPSN_CUR_WRPSn_Field is Interfaces.STM32.Byte;

   --  FLASH write sector protection for bank 1
   type WPSN_CUR_Register is record
      --  Read-only. sector write protection option status byte
      WRPSn         : WPSN_CUR_WRPSn_Field;
      --  unspecified
      Reserved_8_31 : Interfaces.STM32.UInt24;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for WPSN_CUR_Register use record
      WRPSn         at 0 range 0 .. 7;
      Reserved_8_31 at 0 range 8 .. 31;
   end record;

   subtype WPSN_PRG_WRPSn_Field is Interfaces.STM32.Byte;

   --  FLASH write sector protection for bank 1
   type WPSN_PRG_Register is record
      --  sector write protection configuration byte
      WRPSn         : WPSN_PRG_WRPSn_Field := 16#0#;
      --  unspecified
      Reserved_8_31 : Interfaces.STM32.UInt24 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for WPSN_PRG_Register use record
      WRPSn         at 0 range 0 .. 7;
      Reserved_8_31 at 0 range 8 .. 31;
   end record;

   --  BOOT_CUR_BOOT_CM_ADD array element
   subtype BOOT_CUR_BOOT_CM_ADD_Element is Interfaces.STM32.UInt16;

   --  BOOT_CUR_BOOT_CM_ADD array
   type BOOT_CUR_BOOT_CM_ADD_Field_Array is array (0 .. 1)
     of BOOT_CUR_BOOT_CM_ADD_Element
     with Component_Size => 16, Size => 32;

   --  FLASH register with boot address
   type BOOT_CUR_Register
     (As_Array : Boolean := False)
   is record
      case As_Array is
         when False =>
            --  BOOT_CM_ADD as a value
            Val : Interfaces.STM32.UInt32;
         when True =>
            --  BOOT_CM_ADD as an array
            Arr : BOOT_CUR_BOOT_CM_ADD_Field_Array;
      end case;
   end record
     with Unchecked_Union, Size => 32, Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for BOOT_CUR_Register use record
      Val at 0 range 0 .. 31;
      Arr at 0 range 0 .. 31;
   end record;

   --  BOOT_PRG_BOOT_CM_ADD array element
   subtype BOOT_PRG_BOOT_CM_ADD_Element is Interfaces.STM32.UInt16;

   --  BOOT_PRG_BOOT_CM_ADD array
   type BOOT_PRG_BOOT_CM_ADD_Field_Array is array (0 .. 1)
     of BOOT_PRG_BOOT_CM_ADD_Element
     with Component_Size => 16, Size => 32;

   --  FLASH register with boot address
   type BOOT_PRG_Register
     (As_Array : Boolean := False)
   is record
      case As_Array is
         when False =>
            --  BOOT_CM_ADD as a value
            Val : Interfaces.STM32.UInt32;
         when True =>
            --  BOOT_CM_ADD as an array
            Arr : BOOT_PRG_BOOT_CM_ADD_Field_Array;
      end case;
   end record
     with Unchecked_Union, Size => 32, Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for BOOT_PRG_Register use record
      Val at 0 range 0 .. 31;
      Arr at 0 range 0 .. 31;
   end record;

   subtype CRCCR_CRC_SECT_Field is Interfaces.STM32.UInt3;
   subtype CRCCR_CRC_BY_SECT_Field is Interfaces.STM32.Bit;
   subtype CRCCR_ADD_SECT_Field is Interfaces.STM32.Bit;
   subtype CRCCR_CLEAN_SECT_Field is Interfaces.STM32.Bit;
   subtype CRCCR_START_CRC_Field is Interfaces.STM32.Bit;
   subtype CRCCR_CLEAN_CRC_Field is Interfaces.STM32.Bit;
   subtype CRCCR_CRC_BURST_Field is Interfaces.STM32.UInt2;
   subtype CRCCR_ALL_BANK_Field is Interfaces.STM32.Bit;

   --  FLASH CRC control register for bank 1
   type CRCCR_Register is record
      --  CRC sector number
      CRC_SECT       : CRCCR_CRC_SECT_Field := 16#0#;
      --  unspecified
      Reserved_3_7   : Interfaces.STM32.UInt5 := 16#0#;
      --  CRC sector mode select bit
      CRC_BY_SECT    : CRCCR_CRC_BY_SECT_Field := 16#0#;
      --  CRC sector select bit
      ADD_SECT       : CRCCR_ADD_SECT_Field := 16#0#;
      --  CRC sector list clear bit
      CLEAN_SECT     : CRCCR_CLEAN_SECT_Field := 16#0#;
      --  unspecified
      Reserved_11_15 : Interfaces.STM32.UInt5 := 16#0#;
      --  CRC start bit
      START_CRC      : CRCCR_START_CRC_Field := 16#0#;
      --  CRC clear bit
      CLEAN_CRC      : CRCCR_CLEAN_CRC_Field := 16#0#;
      --  unspecified
      Reserved_18_19 : Interfaces.STM32.UInt2 := 16#0#;
      --  CRC burst size
      CRC_BURST      : CRCCR_CRC_BURST_Field := 16#0#;
      --  Write-only. Bank 1 CRC select bit
      ALL_BANK       : CRCCR_ALL_BANK_Field := 16#0#;
      --  unspecified
      Reserved_23_31 : Interfaces.STM32.UInt9 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CRCCR_Register use record
      CRC_SECT       at 0 range 0 .. 2;
      Reserved_3_7   at 0 range 3 .. 7;
      CRC_BY_SECT    at 0 range 8 .. 8;
      ADD_SECT       at 0 range 9 .. 9;
      CLEAN_SECT     at 0 range 10 .. 10;
      Reserved_11_15 at 0 range 11 .. 15;
      START_CRC      at 0 range 16 .. 16;
      CLEAN_CRC      at 0 range 17 .. 17;
      Reserved_18_19 at 0 range 18 .. 19;
      CRC_BURST      at 0 range 20 .. 21;
      ALL_BANK       at 0 range 22 .. 22;
      Reserved_23_31 at 0 range 23 .. 31;
   end record;

   subtype CRCSADDR_CRC_START_ADDR_Field is Interfaces.STM32.UInt18;

   --  FLASH CRC start address register for bank 1
   type CRCSADDR_Register is record
      --  unspecified
      Reserved_0_1   : Interfaces.STM32.UInt2 := 16#0#;
      --  CRC start address on bank 1
      CRC_START_ADDR : CRCSADDR_CRC_START_ADDR_Field := 16#0#;
      --  unspecified
      Reserved_20_31 : Interfaces.STM32.UInt12 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CRCSADDR_Register use record
      Reserved_0_1   at 0 range 0 .. 1;
      CRC_START_ADDR at 0 range 2 .. 19;
      Reserved_20_31 at 0 range 20 .. 31;
   end record;

   subtype CRCEADDR_CRC_END_ADDR_Field is Interfaces.STM32.UInt18;

   --  FLASH CRC end address register for bank 1
   type CRCEADDR_Register is record
      --  unspecified
      Reserved_0_1   : Interfaces.STM32.UInt2 := 16#0#;
      --  CRC end address on bank 1
      CRC_END_ADDR   : CRCEADDR_CRC_END_ADDR_Field := 16#0#;
      --  unspecified
      Reserved_20_31 : Interfaces.STM32.UInt12 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CRCEADDR_Register use record
      Reserved_0_1   at 0 range 0 .. 1;
      CRC_END_ADDR   at 0 range 2 .. 19;
      Reserved_20_31 at 0 range 20 .. 31;
   end record;

   subtype ECC_FAR_FAIL_ECC_ADDR_Field is Interfaces.STM32.UInt15;

   --  FLASH ECC fail address for bank 1
   type ECC_FAR_Register is record
      --  Read-only. ECC error address
      FAIL_ECC_ADDR  : ECC_FAR_FAIL_ECC_ADDR_Field;
      --  unspecified
      Reserved_15_31 : Interfaces.STM32.UInt17;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for ECC_FAR_Register use record
      FAIL_ECC_ADDR  at 0 range 0 .. 14;
      Reserved_15_31 at 0 range 15 .. 31;
   end record;

   subtype OPTSR2_CUR_TCM_AXI_SHARED_Field is Interfaces.STM32.UInt2;
   subtype OPTSR2_CUR_CPUFREQ_BOOST_Field is Interfaces.STM32.Bit;

   --  FLASH ECC fail address for bank 1
   type OPTSR2_CUR_Register is record
      --  Read-only. TCM RAM sharing status bit
      TCM_AXI_SHARED : OPTSR2_CUR_TCM_AXI_SHARED_Field;
      --  Read-only. CPU frequency boost status bit
      CPUFREQ_BOOST  : OPTSR2_CUR_CPUFREQ_BOOST_Field;
      --  unspecified
      Reserved_3_31  : Interfaces.STM32.UInt29;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for OPTSR2_CUR_Register use record
      TCM_AXI_SHARED at 0 range 0 .. 1;
      CPUFREQ_BOOST  at 0 range 2 .. 2;
      Reserved_3_31  at 0 range 3 .. 31;
   end record;

   subtype OPTSR2_PRG_TCM_AXI_SHARED_Field is Interfaces.STM32.UInt2;
   subtype OPTSR2_PRG_CPUFREQ_BOOST_Field is Interfaces.STM32.Bit;

   --  FLASH ECC fail address for bank 1
   type OPTSR2_PRG_Register is record
      --  TCM RAM sharing status bit
      TCM_AXI_SHARED : OPTSR2_PRG_TCM_AXI_SHARED_Field := 16#0#;
      --  CPU frequency boost status bit
      CPUFREQ_BOOST  : OPTSR2_PRG_CPUFREQ_BOOST_Field := 16#0#;
      --  unspecified
      Reserved_3_31  : Interfaces.STM32.UInt29 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for OPTSR2_PRG_Register use record
      TCM_AXI_SHARED at 0 range 0 .. 1;
      CPUFREQ_BOOST  at 0 range 2 .. 2;
      Reserved_3_31  at 0 range 3 .. 31;
   end record;

   -----------------
   -- Peripherals --
   -----------------

   --  Flash
   type Flash_Peripheral is record
      --  Access control register
      ACR        : aliased ACR_Register;
      --  FLASH key register
      KEYR       : aliased Interfaces.STM32.UInt32;
      --  FLASH option key register
      OPTKEYR    : aliased Interfaces.STM32.UInt32;
      --  FLASH control register
      CR         : aliased CR_Register;
      --  FLASH status register for bank 1
      SR         : aliased SR_Register;
      --  FLASH clear control register for bank 1
      CCR        : aliased CCR_Register;
      --  FLASH option control register
      OPTCR      : aliased OPTCR_Register;
      --  FLASH option status register
      OPTSR_CUR  : aliased OPTSR_CUR_Register;
      --  FLASH option status register
      OPTSR_PRG  : aliased OPTSR_PRG_Register;
      --  FLASH option clear control register
      OPTCCR     : aliased OPTCCR_Register;
      --  FLASH protection address for bank 1
      PRAR_CUR   : aliased PRAR_CUR_Register;
      --  FLASH protection address for bank 1
      PRAR_PRG   : aliased PRAR_PRG_Register;
      --  FLASH secure address for bank 1
      SCAR_CUR   : aliased SCAR_CUR_Register;
      --  FLASH secure address for bank 1
      SCAR_PRG   : aliased SCAR_PRG_Register;
      --  FLASH write sector protection for bank 1
      WPSN_CUR   : aliased WPSN_CUR_Register;
      --  FLASH write sector protection for bank 1
      WPSN_PRG   : aliased WPSN_PRG_Register;
      --  FLASH register with boot address
      BOOT_CUR   : aliased BOOT_CUR_Register;
      --  FLASH register with boot address
      BOOT_PRG   : aliased BOOT_PRG_Register;
      --  FLASH CRC control register for bank 1
      CRCCR      : aliased CRCCR_Register;
      --  FLASH CRC start address register for bank 1
      CRCSADDR   : aliased CRCSADDR_Register;
      --  FLASH CRC end address register for bank 1
      CRCEADDR   : aliased CRCEADDR_Register;
      --  FLASH CRC data register
      CRCDATAR   : aliased Interfaces.STM32.UInt32;
      --  FLASH ECC fail address for bank 1
      ECC_FAR    : aliased ECC_FAR_Register;
      --  FLASH ECC fail address for bank 1
      OPTSR2_CUR : aliased OPTSR2_CUR_Register;
      --  FLASH ECC fail address for bank 1
      OPTSR2_PRG : aliased OPTSR2_PRG_Register;
   end record
     with Volatile;

   for Flash_Peripheral use record
      ACR        at 16#0# range 0 .. 31;
      KEYR       at 16#4# range 0 .. 31;
      OPTKEYR    at 16#8# range 0 .. 31;
      CR         at 16#C# range 0 .. 31;
      SR         at 16#10# range 0 .. 31;
      CCR        at 16#14# range 0 .. 31;
      OPTCR      at 16#18# range 0 .. 31;
      OPTSR_CUR  at 16#1C# range 0 .. 31;
      OPTSR_PRG  at 16#20# range 0 .. 31;
      OPTCCR     at 16#24# range 0 .. 31;
      PRAR_CUR   at 16#28# range 0 .. 31;
      PRAR_PRG   at 16#2C# range 0 .. 31;
      SCAR_CUR   at 16#30# range 0 .. 31;
      SCAR_PRG   at 16#34# range 0 .. 31;
      WPSN_CUR   at 16#38# range 0 .. 31;
      WPSN_PRG   at 16#3C# range 0 .. 31;
      BOOT_CUR   at 16#40# range 0 .. 31;
      BOOT_PRG   at 16#44# range 0 .. 31;
      CRCCR      at 16#50# range 0 .. 31;
      CRCSADDR   at 16#54# range 0 .. 31;
      CRCEADDR   at 16#58# range 0 .. 31;
      CRCDATAR   at 16#5C# range 0 .. 31;
      ECC_FAR    at 16#60# range 0 .. 31;
      OPTSR2_CUR at 16#70# range 0 .. 31;
      OPTSR2_PRG at 16#74# range 0 .. 31;
   end record;

   --  Flash
   Flash_Periph : aliased Flash_Peripheral
     with Import, Address => Flash_Base;

end Interfaces.STM32.Flash;
