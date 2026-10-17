## -*- asm -*- ##############################################################
#                                                                           #
#                 GNAT RUN-TIME LIBRARY (GNARL) COMPONENTS                  #
#                                                                           #
#                                 C A C H E                                 #
#                                                                           #
#                               Assembly File                               #
#                                                                           #
#                      Copyright (C) 2012-2016 AdaCore                      #
#                                                                           #
#  GNAT is free software;  you can  redistribute it  and/or modify it under #
#  terms of the  GNU General Public License as published  by the Free Soft- #
#  ware  Foundation;  either version 3,  or (at your option) any later ver- #
#  sion.  GNAT is distributed in the hope that it will be useful, but WITH- #
#  OUT ANY WARRANTY;  without even the  implied warranty of MERCHANTABILITY #
#  or FITNESS FOR A PARTICULAR PURPOSE.                                     #
#                                                                           #
#  As a special exception under Section 7 of GPL version 3, you are granted #
#  additional permissions described in the GCC Runtime Library Exception,   #
#  version 3.1, as published by the Free Software Foundation.               #
#                                                                           #
#  You should have received a copy of the GNU General Public License and    #
#  a copy of the GCC Runtime Library Exception along with this program;     #
#  see the files COPYING3 and COPYING.RUNTIME respectively.  If not, see    #
#  <http://www.gnu.org/licenses/>.                                          #
#                                                                           #
#############################################################################

	.syntax unified
	.cpu cortex-m7
	.thumb

	.text
	.thumb_func
	.globl	_stm32_start_common
	.type _stm32_start_common, %function
_stm32_start_common:

        /* The vector table from handler.S, in every profile, before the first
           instruction that can fault. Upstream's start-rom.S carries a five-
           entry table for the light runtime whose fault entries hang, and the
           tasking runtimes installed handler.S's table only from
           System.BB.CPU_Primitives, i.e. only in programs that use tasking.
           The memory-management, bus and usage fault exceptions are enabled
           here as well, so that a fault keeps its own name in the report
           instead of escalating to HardFault. */
        ldr     r0, =__vectors
        ldr     r1, =0xE000ED08         /* SCB VTOR */
        str     r0, [r1]
        ldr     r1, =0xE000ED24         /* SCB SHCSR */
        ldr     r2, [r1]
        orr     r2, r2, #0x00070000     /* USGFAULTENA, BUSFAULTENA, MEMFAULTENA */
        str     r2, [r1]
        dsb
        isb

        /************************
        * Enable debug Monitor *
        ************************/

        /* Debug register definition */
        .set    DEMCR,  0xE000EDFC
          
        /* Enable the debug monitor so that bkpt instructions are not treated
        * as hard fault when no debugger is attached */
        ldr     r0, =DEMCR
        ldr     r1, [r0]
        orr     r1, r1, #0x10000 /* Set MON_EN in DEMCR */
        str     r1, [r0]

        /**************/
        /* Enable FPU */
        /**************/

        movw     r0,#0xED88
        movt     r0,#0xE000
        ldr      r1,[r0]
        orr      r1,r1,#(0xF << 20)
        str      r1,[r0]

        dsb
        isb

        /* The STM32H72x/H73x family is Cortex-M7 only: the caches and the
           TCM interfaces are initialised unconditionally. (AdaCore's version
           of this file reads the F4/F7 DBGMCU_IDCODE at 0xE0042000 and
           initialises the caches for the F7 device IDs only; on the H7 the
           identity register is DBGMCU_IDC at 0x5C001000, DEV_ID 0x483.)
           Sequence per PM0253 4.8.5: invalidate the data cache by set/way,
           invalidate the instruction cache, enable both in CCR; then enable
           the TCMs (PM0253 4.9.1; already enabled by hardware at reset on
           the H7, so this only confirms them). */

        /* ECC initialisation of the AXI SRAM and the ITCM (Hyle Systems,
           2026-10-17). Their ECC is computed over 64-bit words (RM0468 2.4:
           8 ECC bits per 64-bit word for AXI-SRAM and ITCM-RAM), so the
           first sub-word write to a word nobody has written since power-up,
           by this start-up's 32-bit copy of .axisram, by a task or by a DMA,
           is a read-modify-write against an ECC that is garbage, and the
           RAMECC monitor flags it (measured: D1 monitor 1 read 0x7 after one
           program that used the AXI SRAM). Both regions are zeroed here with
           64-bit stores while the data cache is still off, so every word
           carries a valid ECC before anything touches it; .axisram is copied
           afterwards. The bounds come from the linker (the family's memory
           map: 320 KB of AXI SRAM and 64 KB of ITCM, the default
           TCM_AXI_SHARED option bytes); a device sharing the memory
           differently faults here, which the fault routing reports at boot.
           About 200 us at 520 MHz. */
ecc_init:
        movs    r2,#0
        movs    r3,#0
        movw    r0,#:lower16:__axisram_start
        movt    r0,#:upper16:__axisram_start
        movw    r1,#:lower16:__axisram_end
        movt    r1,#:upper16:__axisram_end
0:      cmp     r0,r1
        bhs     1f
        strd    r2,r3,[r0],#8
        b       0b
1:      movw    r0,#:lower16:__itcm_start
        movt    r0,#:upper16:__itcm_start
        movw    r1,#:lower16:__itcm_end
        movt    r1,#:upper16:__itcm_end
0:      cmp     r0,r1
        bhs     1f
        strd    r2,r3,[r0],#8
        b       0b
1:      dsb

init_cache:
        /********************
         * Enable I/D cache *
        ********************/

        /* Register definition for cache handling */
        .set    CCSIDR,  0xE000ED80
        .set    CSSELR,  0xE000ED84
        .set    DCISW,   0xE000EF60
        .set    ICIALLU, 0xE000EF50
        .set    CCR,     0xE000ED14

        /* First invalidate the data cache */
        mov     r0, #0x0
        ldr     r11, =CSSELR
        str     r0, [r11]       /* Select the data cache size */
        dsb

        ldr     r11, =CCSIDR
        ldr     r2, [r11]       /* Cache size identification */
        and     r1, r2, #0x7    /* Number of words in a cache line */
        add     r7, r1, #0x4

        ubfx    r4, r2, #3, #10  /* r4 = number of ways - 1 of data cache */
        ubfx    r2, r2, #13, #15 /* r2 = number of sets - 1 of data cache */
        clz     r6, r4           /* Calculate bit offset for "way" in DCISW */

        ldr     r11, =DCISW

inv_loop1:                       /* For each set */
        mov     r1, r4
        lsls    r8, r2, r7

inv_loop2:                       /* For each way */
        lsls    r3, r1, r6
        orrs    r3, r3, r8

        str     r3, [r11]        /* Invalidate the D-Cache line */
        subs    r1, r1, #1
        bge     inv_loop2
        subs    r2, r2, #1
        bge     inv_loop1

        dsb

        /* Now invalidate the instruction cache */
        mov     r0, #0x0
        ldr     r11, =ICIALLU
        str     r0, [r11]

        dsb
        isb

        /* Finally enable Instruction and Data cache */
        ldr     r11, =CCR
        ldr     r0, [r11]
        orr     r0, r0, #(0x30000) /* Sets the I and D cache enabled fields */
        str     r0, [r11]

        dsb
        isb

        /* Wait for store to complete and reset pipeline with FPU enabled  */
        dsb
        isb

        /*****************************
         * TCM Memory initialisation *
        *****************************/
tcm_init:
        .set    CM7_ITCMCR, 0xE000EF90
        .set    CM7_DTCMCR, 0xE000EF94

        ldr     r0, =CM7_ITCMCR
        ldr     r1, [r0]
        orr     r1, r1, #0x1 /* set the EN field */
        str     r1, [r0]

        ldr     r0, =CM7_DTCMCR
        ldr     r1, [r0]
        orr     r1, r1, #0x1 /* set the EN field */
        str     r1, [r0]

        dsb
        isb

end:
        bx lr
        .size _stm32_start_common, . - _stm32_start_common
