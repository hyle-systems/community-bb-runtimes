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

        /* The core's supply arrangement (RM0468 6.4, Table 30), from the crate
           option Supply_Configuration through __supply_cr3 (a --defsym from the
           runtime's project file): the lower byte of PWR_CR3, written once after
           a power-on reset and before the voltage scaling, the clock change and
           - per 6.4.1 - any write to RAM, so it is the first thing after the
           vector table. The upper bits are kept. Then wait until the voltage
           levels are valid (ACTVOSRDY in PWR_CSR1). An arrangement the board is
           not wired for never becomes valid: the wait is where that shows. */
        ldr     r0, =0x5802480C         /* PWR_CR3 */
        ldr     r1, [r0]
        bic     r1, r1, #0x3F
        ldr     r2, =__supply_cr3
        orr     r1, r1, r2
        str     r1, [r0]
        ldr     r0, =0x58024804         /* PWR_CSR1 */
1:      ldr     r1, [r0]
        tst     r1, #0x2000             /* ACTVOSRDY */
        beq     1b

        /* The four arrangements in which the converter supplies external
           circuits (SDEXTHP, bit 3 of the byte): wait for SDEXTRDY (PWR_CR3
           bit 16) as well, as HAL_PWREx_ConfigSupply does - the external
           rail must be up before the voltage scaling changes. Untested
           here: this board has no converter. */
        ldr     r2, =__supply_cr3
        tst     r2, #0x08               /* SDEXTHP */
        beq     3f
        ldr     r0, =0x5802480C         /* PWR_CR3 */
2:      ldr     r1, [r0]
        tst     r1, #0x10000            /* SDEXTRDY */
        beq     2b
3:

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

        /* ECC initialisation of the AXI SRAM and the ITCM, this family's
           addition. Their ECC is computed over 64-bit words (RM0468 2.4:
           8 ECC bits per 64-bit word for AXI-SRAM and ITCM-RAM), so the
           first sub-word write to a word nobody has written since power-up,
           by this start-up's 32-bit copy of .axisram, by a task or by a DMA,
           is a read-modify-write against an ECC that is garbage, and the
           RAMECC monitor flags it (measured: D1 monitor 1 read 0x7 after one
           program that used the AXI SRAM). Both regions are zeroed here with
           64-bit stores while the data cache is still off, so every word
           carries a valid ECC before anything touches it; .axisram is copied
           afterwards. The bounds come from the device's TCM_AXI_SHARED option
           byte (see ecc_init), so every sharing boots with every word valid.
           About 200 us at 520 MHz. */
ecc_init:
        /* The sizes come from the device, not from the map: TCM_AXI_SHARED in
           FLASH_OPTSR2_CUR (RM0468 4.9.24) gives 64, 128, 192 or 256 KB of ITCM
           as (field + 1) * 64 KB, and the AXI SRAM is 384 KB minus that. The
           two numbers are left in __ecc_itcm_bytes and __ecc_axisram_bytes (two
           words the linker places outside .bss, so the later zeroing of .bss
           keeps them) for inspection. The linker scripts describe the default
           sharing; a device set otherwise has less AXI SRAM than they declare. */
        ldr     r0,=0x52002070          /* FLASH_OPTSR2_CUR */
        ldr     r0,[r0]
        and     r0,r0,#3                /* TCM_AXI_SHARED */
        adds    r0,#1
        lsls    r4,r0,#16               /* ITCM bytes = (field + 1) * 64 KB */
        ldr     r5,=0x60000             /* 384 KB */
        subs    r5,r5,r4                /* AXI SRAM bytes */
        ldr     r0,=__ecc_itcm_bytes
        str     r4,[r0]
        ldr     r0,=__ecc_axisram_bytes
        str     r5,[r0]
        movs    r2,#0
        movs    r3,#0
        movw    r0,#:lower16:__axisram_start
        movt    r0,#:upper16:__axisram_start
        adds    r1,r0,r5                /* end = start + the device's size */
        movw    r0,#:lower16:__ecc_axisram_zero_start
        movt    r0,#:upper16:__ecc_axisram_zero_start
                                        /* flash loader: the start; RAM loader:
                                           after the loaded image */
0:      cmp     r0,r1
        bhs     1f
        strd    r2,r3,[r0],#8
        b       0b
1:      movw    r0,#:lower16:__itcm_start
        movt    r0,#:upper16:__itcm_start
        adds    r1,r0,r4                /* end = start + the device's size */
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

guard_init:
        /* Stack_Guard, a crate option of the tasking profiles: the two
           static guards - MPU region 1, a no-access window at the bottom of
           the interrupt stack, and region 2, the same under the environment
           stack - programmed here for every program. The tasking runtime's
           Initialize_CPU programs the same two again and adds each task's
           as it runs; a light-tasking program with no tasking unit never
           runs it, and had no guard at all before this block existed.
           __stack_guard_bytes is the crate's --defsym: the window, 32 .. 1024
           (a power of two) when the option is on, 8 (an alignment only) when
           it is off, and the block is skipped below 32; the weak reference
           reads 0 under a user linker script that omits it. The values
           mirror Set_Guard in s-bbcppr.adb: RBAR = base | VALID | region,
           RASR = XN | SIZE << 1 | ENABLE with AP = 000 (no access for
           anyone), SIZE = log2 (bytes) - 1 (PM0253 Tables 90 and 93),
           MPU_CTRL = ENABLE | PRIVDEFENA. */
        .weak   __stack_guard_bytes
        ldr     r0, =__stack_guard_bytes
        cmp     r0, #32
        blo     end
        clz     r1, r0
        rsb     r1, r1, #30             /* SIZE = log2 (bytes) - 1 */
        lsl     r1, r1, #1
        orr     r1, r1, #0x10000000     /* XN */
        orr     r1, r1, #1              /* ENABLE */
        sub     r4, r0, #1              /* the window's alignment mask */
        ldr     r2, =0xE000ED9C         /* MPU_RBAR; RASR at +4 */
        /* Region 1 only where there is an interrupt stack: a light-tasking
           program without a tasking unit has none (the section is empty,
           start = end), and a window at its start would sit on the fault
           stack that follows it. */
        ldr     r3, =__interrupt_stack_start
        ldr     r0, =__interrupt_stack_end
        cmp     r3, r0
        beq     2f
        add     r3, r3, r4
        bic     r3, r3, r4              /* rounded up to the window */
        orr     r3, r3, #0x11           /* VALID, region 1 */
        str     r3, [r2]
        str     r1, [r2, #4]
2:      ldr     r3, =__stack_start
        add     r3, r3, r4
        bic     r3, r3, r4
        orr     r3, r3, #0x12           /* VALID, region 2 */
        str     r3, [r2]
        str     r1, [r2, #4]
        movs    r3, #5                  /* ENABLE, PRIVDEFENA */
        ldr     r2, =0xE000ED94         /* MPU_CTRL */
        str     r3, [r2]
        dsb
        isb

end:
        bx lr
        .size _stm32_start_common, . - _stm32_start_common
