/****************************************************************************
 *                                                                          *
 *                         GNAT COMPILER COMPONENTS                         *
 *                                                                          *
 *                                  A R M                                   *
 *                                                                          *
 *                            Linker Script File                            *
 *                                                                          *
 *      Copyright (C) 1999-2002 Universidad Politecnica de Madrid           *
 *             Copyright (C) 2003-2006 The European Space Agency            *
 *                   Copyright (C) 2003-2015 AdaCore                        *
 *                                                                          *
 * GNAT is free software;  you can  redistribute it  and/or modify it under *
 * terms of the  GNU General Public License as published  by the Free Soft- *
 * ware  Foundation;  either version 2,  or (at your option) any later ver- *
 * sion.  GNAT is distributed in the hope that it will be useful, but WITH- *
 * OUT ANY WARRANTY;  without even the  implied warranty of MERCHANTABILITY *
 * or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License *
 * for  more details.  You should have  received  a copy of the GNU General *
 * Public License  distributed with GNAT;  see file COPYING.  If not, write *
 * to  the  Free Software Foundation,  51  Franklin  Street,  Fifth  Floor, *
 * Boston, MA 02110-1301, USA.                                              *
 *                                                                          *
 * As a  special  exception,  if you  link  this file  with other  files to *
 * produce an executable,  this file does not by itself cause the resulting *
 * executable to be covered by the GNU General Public License. This except- *
 * ion does not  however invalidate  any other reasons  why the  executable *
 * file might be covered by the  GNU Public License.                        *
 *                                                                          *
 * GNARL was developed by the GNARL team at Florida State University.       *
 * Extensive contributions were provided by Ada Core Technologies, Inc.     *
 * The  executive  was developed  by the  Real-Time  Systems  Group  at the *
 * Technical University of Madrid.                                          *
 *                                                                          *
 ****************************************************************************/

/* This is a ARM specific version of this file */

/* This script replaces ld's default linker script, providing the
   appropriate memory map and output format. */

INCLUDE memory-ROM.ld
INCLUDE memory-RAM.ld

_DEFAULT_STACK_SIZE = 4*1024;

ENTRY(_start_rom);

SECTIONS
{
  .text :
  {
    KEEP (*(.vectors))
    *(.text .text.* .gnu.linkonce.t*)
    *(.gnu.warning)
  } > flash

  .ARM.extab   : { *(.ARM.extab* .gnu.linkonce.armextab.*) } > flash
  /* .ARM.exidx is 4-bytes aligned, so __exidx_start needs to be
     aligned too. Note that assigning the location counter also makes
     ld attach the following symbols to the next section (instead of the
     previous section which is the default), so will properly
     consider the location counter of .ARM.exidx for __exidx_start and
      __exidx_end and not the previous section's one. */
  . = ALIGN(0x4);
  PROVIDE_HIDDEN (__exidx_start = .);
  .ARM.exidx   : { *(.ARM.exidx* .gnu.linkonce.armexidx.*) } > flash
  PROVIDE_HIDDEN (__exidx_end = .);

  .init  : { KEEP(*(.init)) } > flash
  .fini  : { KEEP(*(.fini)) } > flash

  .eh_frame_hdr :
  {
     __eh_frame_hdr = .;
    *(.eh_frame_hdr)
  } > flash

  __eh_frame_hdr_start = SIZEOF(.eh_frame_hdr) > 0 ? ADDR(.eh_frame_hdr) : 0;
  __eh_frame_hdr_end = SIZEOF(.eh_frame_hdr) > 0 ? . : 0;

  .eh_frame         :
  {
     __eh_frame_start = .;
     KEEP (*(.eh_frame))
     __eh_frame_end = .;
  } > flash

  .preinit_array (ALIGN(4)) : {
     PROVIDE_HIDDEN (__preinit_array_start = .);
     KEEP (*(.preinit_array))
     PROVIDE_HIDDEN (__preinit_array_end = .);
  } > flash

  .init_array (ALIGN(4)) : {
     PROVIDE_HIDDEN (__init_array_start = .);
     KEEP (*(SORT(.init_array.*)))
     KEEP (*(.init_array))
     PROVIDE_HIDDEN (__init_array_end = .);
  } > flash

  .fini_array (ALIGN(4)) : {
     PROVIDE_HIDDEN (__fini_array_start = .);
     KEEP (*(SORT(.fini_array.*)))
     KEEP (*(.fini_array))
     PROVIDE_HIDDEN (__fini_array_end = .);
  } > flash

  .rodata :
  {
    *(.lit)
    *(.rodata .rodata.* .gnu.linkonce.r*)
    . = ALIGN(0x4);
    __rom_end = .;
  } > flash

  __data_load = __rom_end;
  .data : AT (__data_load)
  {
    __data_start = .;
    *(.data .data.* .gnu.linkonce.d*)

    /* Ensure that the end of the data section is always word aligned.
       Initial values are stored in 4-bytes blocks so we must guarantee
       that these blocks do not fall out the section (otherwise they are
       truncated and the initial data for the last block are lost). */

    . = ALIGN(0x4);
    __data_end = .;
  } > sram_da
  __data_words = (__data_end - __data_start) >> 2;

  __ccmdata_load = __rom_end + (__data_words << 2);
  /* The ECC regions the start-up zeroes with 64-bit stores (start-common.S,
     ecc_init): the whole AXI SRAM and the whole ITCM of the memory map. */
  __axisram_start = ORIGIN(axisram);
  /* Where the start-up's ECC zeroing of the AXI SRAM begins: the start,
     since the flash loader copies .axisram afterwards. */
  __ecc_axisram_zero_start = ORIGIN(axisram);
  __axisram_end = ORIGIN(axisram) + LENGTH(axisram);
  __itcm_start = ORIGIN(itcm);
  __itcm_end = ORIGIN(itcm) + LENGTH(itcm);

  .axisram : AT (__ccmdata_load)
  {
    __ccmdata_start = .;
    /* Large or shared data in the AXI SRAM (STM32H7 family). The symbols
       keep the generator's __ccmdata_* names: the start-up copies the
       section with them. The .ccmdata input name is accepted too. */
    *(.axisram .axisram.*)
    *(.ccmdata .ccmdata.*)

    /* Ensure that the end of the data section is always word aligned.
       Initial values are stored in 4-bytes blocks so we must guarantee
       that these blocks do not fall out the section (otherwise they are
       truncated and the initial data for the last block are lost). */

    . = ALIGN(0x4);
    __ccmdata_end = .;
  } > ccm_da
  __ccmdata_words = (__ccmdata_end - __ccmdata_start) >> 2;
  /* The start-up's copy of this section (upstream's start-rom.S) loads
     the word count with a single movw: 65 535 words at most, and a
     larger count is reduced modulo 65 536 with no error - the tail of
     the section would stay zero. Refused here instead. */
  ASSERT (__ccmdata_words < 65536,
          "initialised .axisram above 256 KB: the start-up's copy counts 16 bits (start-rom.S movw)")

  .bss (NOLOAD): {
   . = ALIGN(0x8);
   __bss_start = .;

   *(.bss .bss.*)
   *(COMMON)

   . = ALIGN(0x8);    /* Align the stack to 64 bits */
   __bss_end = .;

   /* Two words the start-up fills before .bss is zeroed, so outside it:
      the ITCM and AXI SRAM sizes it initialised (from TCM_AXI_SHARED). */
   __ecc_itcm_bytes = .;
   . += 4;
   __ecc_axisram_bytes = .;
   . += 4;

   /* The interrupt and environment stacks start on a multiple of the
      stack guard's window (__stack_guard_bytes, a --defsym from the
      runtime's project file; 8 without it), so that the window sits
      exactly at each stack's bottom and costs exactly one window. */
   . = ALIGN(DEFINED (__stack_guard_bytes) ? __stack_guard_bytes : 8);
   __interrupt_stack_start = .;
   *(.noinit.interrupt_stacks)
   . = ALIGN(0x8);
   __interrupt_stack_end = .;

   /* The fault stack: the fault trap switches to it before the report, so
      a fault's handling never runs on the stack that overflowed. Its size
      is the crate's Fault_Stack_Size (__fault_stack_size, a --defsym from
      the runtime's project file; 4 KB without it). Above the interrupt
      stack, so that an overflow of its own lands there, not in .bss. */
   . = ALIGN(0x8);
   __fault_stack_start = .;
   . += DEFINED (__fault_stack_size) ? __fault_stack_size : 4096;
   . = ALIGN(0x8);
   __fault_stack_end = .;

   . = ALIGN(DEFINED (__stack_guard_bytes) ? __stack_guard_bytes : 8);
   __stack_start = .;
   . += DEFINED (__stack_size) ? __stack_size : _DEFAULT_STACK_SIZE;
   . = ALIGN(0x8);
   __stack_end = .;
   /* With the guard on, every guarded stack holds at least four windows;
      the environment stack's size is decided here, so it is checked here. */
   ASSERT (!DEFINED (__stack_guard_bytes)
           || (__stack_end - __stack_start) >= 4 * __stack_guard_bytes,
           "environment stack smaller than four guard windows (__stack_size against Stack_Guard_Bytes)");

   _end = .;
   __heap_start = .;
   __heap_end = ORIGIN(sram_bs) + LENGTH(sram_bs);
  } > sram_bs

  __bss_words = (__bss_end - __bss_start) >> 2;

  /* The RAMs a DMA can reach - SRAM1 and SRAM2 (D2, contiguous) and SRAM4
     (D3); a DMA cannot address the DTCM, where everything else lives. No
     initial values: the application enables their clocks (RCC_AHB2ENR
     SRAM1EN/SRAM2EN for the first two) and writes them whole-word before any
     sub-word use, their ECC being undefined after power-up. They are
     cacheable in the default memory map: a DMA buffer here needs the cache
     maintenance, or an MPU region of its own (the stack guard uses 0 to 2). */
  .sram12 (NOLOAD) : {
    . = ALIGN(8);
    __sram12_start = .;
    *(.sram12 .sram12.*)
    . = ALIGN(8);
    __sram12_end = .;
  } > sram12

  .sram4 (NOLOAD) : {
    . = ALIGN(8);
    __sram4_start = .;
    *(.sram4 .sram4.*)
    . = ALIGN(8);
    __sram4_end = .;
  } > sram4

  /* DWARF debug sections.
     Symbols in the DWARF debugging sections are relative to the beginning
     of the section so we begin them at 0.  */

  /* DWARF 1.  */
  .debug          0 : { *(.debug) }
  .line           0 : { *(.line) }

  /* GNU DWARF 1 extensions.  */
  .debug_srcinfo  0 : { *(.debug_srcinfo) }
  .debug_sfnames  0 : { *(.debug_sfnames) }

  /* DWARF 1.1 and DWARF 2.  */
  .debug_aranges  0 : { *(.debug_aranges) }
  .debug_pubnames 0 : { *(.debug_pubnames) }

  /* DWARF 2.  */
  .debug_info     0 : { *(.debug_info .gnu.linkonce.wi.*) }
  .debug_abbrev   0 : { *(.debug_abbrev) }
  .debug_line     0 : { *(.debug_line .debug_line.* .debug_line_end) }
  .debug_frame    0 : { *(.debug_frame) }
  .debug_str      0 : { *(.debug_str) }
  .debug_loc      0 : { *(.debug_loc) }
  .debug_macinfo  0 : { *(.debug_macinfo) }

  /* SGI/MIPS DWARF 2 extensions.  */
  .debug_weaknames 0 : { *(.debug_weaknames) }
  .debug_funcnames 0 : { *(.debug_funcnames) }
  .debug_typenames 0 : { *(.debug_typenames) }
  .debug_varnames  0 : { *(.debug_varnames) }

  /* DWARF 3.  */
  .debug_pubtypes 0 : { *(.debug_pubtypes) }
  .debug_ranges   0 : { *(.debug_ranges) }

  /* DWARF 5.  */
  .debug_addr     0 : { *(.debug_addr) }
  .debug_line_str 0 : { *(.debug_line_str) }
  .debug_loclists 0 : { *(.debug_loclists) }
  .debug_macro    0 : { *(.debug_macro) }
  .debug_names    0 : { *(.debug_names) }
  .debug_rnglists 0 : { *(.debug_rnglists) }
  .debug_str_offsets 0 : { *(.debug_str_offsets) }
  .debug_sup      0 : { *(.debug_sup) }

  .gnu.attributes 0 : { KEEP (*(.gnu.attributes)) }
  /DISCARD/ : { *(.note.GNU-stack) *(.gnu_debuglink) *(.gnu.lto_*) }
}
