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

/* Linker script for the STM32H72x/H73x ROM loader: code, constants and
   initial values in the flash, data, stacks and heap in the DTCM, and the
   .axisram, .sram12 and .sram4 sections in their RAMs. Derived from this
   repository's stm32g4_src/ld/common-ROM.ld. */

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
  /* For the ECC zeroing (start-common.S, ecc_init), which takes the sizes
     from the device. It covers the whole AXI SRAM, as this loader copies
     .axisram in only afterwards. */
  __axisram_start = ORIGIN(axisram);
  __ecc_axisram_zero_start = ORIGIN(axisram);
  __itcm_start = ORIGIN(itcm);

  .axisram : AT (__ccmdata_load)
  {
    __ccmdata_start = .;
    /* Large or shared data in the AXI SRAM. The symbols keep the
       generator's __ccmdata_* names, by which the start-up copies the
       section, and the .ccmdata input name is accepted too. */
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
  /* The copy of this section (upstream's start-rom.S) has the 16-bit word
     count of the .bss zeroing (common-sections.ld): past it, the
     section's tail would stay zero. */
  ASSERT (__ccmdata_words < 65536,
          "initialised .axisram above 256 KB: the start-up's copy counts 16 bits (start-rom.S movw)")

  /* AXI SRAM objects whose only initial value is zero, such as large DMA
     buffers: unlike .axisram, they take no flash and are not copied. The
     ECC zeroing of the whole AXI SRAM leaves them zero. */
  .axisram_bss (NOLOAD) : {
    . = ALIGN(8);
    *(.axisram_bss .axisram_bss.*)
    . = ALIGN(8);
    __axisram_bss_end = .;
  } > ccm_da

  /* The same count limits the copy of .data (start-rom.S). The 128 KB
     DTCM cannot reach it; a derived script with a larger home for .data
     is refused. */
  ASSERT (__data_words < 65536,
          ".data above 256 KB: the start-up's copy counts 16 bits (start-rom.S movw)")

  __sram12_load = __ccmdata_load + (__ccmdata_words << 2);
  /* .bss, the stacks, the heap, .sram12 and .sram4 */
  INCLUDE common-sections.ld
  /* The load images' addresses are expressions, which ld does not check
     against the flash region: an image past its end would link silently. */
  ASSERT (__sram_images_end <= ORIGIN(flash) + LENGTH(flash),
          "initial values exceed the flash: the load images of .data, .axisram, .sram12 and .sram4 run past its end")

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
