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


/* The sections common-ROM.ld and common-RAM.ld share, included inside
   their SECTIONS after they define __sram12_load, where the .sram12 image
   starts. */

  .bss (NOLOAD): {
   . = ALIGN(0x8);
   __bss_start = .;

   *(.bss .bss.*)
   *(COMMON)

   . = ALIGN(0x8);    /* Align the stack to 64 bits */
   __bss_end = .;

   /* The ITCM and AXI SRAM sizes the ECC zeroing used (start-common.S,
      ecc_init), written before .bss is zeroed, hence outside it. */
   __ecc_itcm_bytes = .;
   . += 4;
   __ecc_axisram_bytes = .;
   . += 4;

   /* The interrupt and environment stacks start on a multiple of the
      guard's window (__stack_guard_bytes, a --defsym from the runtime's
      project file, or 8), so that it sits at each one's bottom and costs
      exactly one window. */
   . = ALIGN(DEFINED (__stack_guard_bytes) ? __stack_guard_bytes : 8);
   __interrupt_stack_start = .;
   *(.noinit.interrupt_stacks)
   . = ALIGN(0x8);
   __interrupt_stack_end = .;

   /* The fault stack (handler.S, __gnat_fault_trap), of the crate's
      Fault_Stack_Size (__fault_stack_size, a --defsym from the runtime's
      project file, or 4 KB). Above the interrupt stack, its own overflow
      lands there, not in .bss. */
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
   /* A guarded stack's four-window minimum (s-bbcppr.adb), checked here
      for the environment stack, whose size the link decides. */
   ASSERT (!DEFINED (__stack_guard_bytes)
           || (__stack_end - __stack_start) >= 4 * __stack_guard_bytes,
           "environment stack smaller than four guard windows (__stack_size against Stack_Guard_Bytes)");

   _end = .;
   __heap_start = .;
   __heap_end = ORIGIN(sram_bs) + LENGTH(sram_bs);
  } > sram_bs

  __bss_words = (__bss_end - __bss_start) >> 2;
  /* The zeroing loop for .bss (upstream's start-rom.S and start-ram.S)
     loads the word count with a single movw: 65 535 words at most, a
     larger count being silently reduced modulo 65 536. The 128 KB DTCM
     cannot reach that; a derived script with a larger home for .bss is
     refused. */
  ASSERT (__bss_words < 65536,
          ".bss above 256 KB: the start-up's zeroing counts 16 bits (start-rom.S and start-ram.S movw)")

  /* SRAM1 and SRAM2 (D2, contiguous) and SRAM4 (D3, the only RAM the
     BDMA reaches, RM0468 2.1) take DMA buffers: DMA1, DMA2 and the BDMA
     cannot address the DTCM, where .data, .bss, the stacks and the heap
     live.
     .sram12 and .sram4 carry their objects' initial values, the implicit
     ones too: GNAT emits a null access or a record's default components
     as data, which a NOLOAD section would drop silently. The start-up
     copies them (start-common.S, sram_init).
     .sram12_noinit and .sram4_noinit are neither loaded nor zeroed: for
     large buffers, or records that must survive a reset (SRAM4 keeps its
     contents while powered). Their ECC is undefined after power-up, so
     write them in whole words before any sub-word use, after enabling
     the SRAM1/SRAM2 clocks (RCC_AHB2ENR SRAM1EN/SRAM2EN, off after reset)
     if .sram12 is empty.
     These RAMs are cacheable in the default memory map: a DMA buffer here
     needs cache maintenance, or an MPU region of its own (the stack guard
     uses MPU regions 12 to 15). */
  .sram12 : AT (__sram12_load) {
    . = ALIGN(8);
    __sram12_start = .;
    *(.sram12 .sram12.*)
    . = ALIGN(8);
    __sram12_end = .;
  } > sram12

  .sram12_noinit (NOLOAD) : {
    . = ALIGN(8);
    *(.sram12_noinit .sram12_noinit.*)
    . = ALIGN(8);
  } > sram12

  __sram4_load = __sram12_load + (__sram12_end - __sram12_start);
  .sram4 : AT (__sram4_load) {
    . = ALIGN(8);
    __sram4_start = .;
    *(.sram4 .sram4.*)
    . = ALIGN(8);
    __sram4_end = .;
  } > sram4

  .sram4_noinit (NOLOAD) : {
    . = ALIGN(8);
    *(.sram4_noinit .sram4_noinit.*)
    . = ALIGN(8);
  } > sram4
  __sram_images_end = __sram4_load + (__sram4_end - __sram4_start);
