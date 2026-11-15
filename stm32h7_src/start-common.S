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

/* Start-up code for the STM32H72x/H73x, called by start-rom.S and
   start-ram.S before they set up .data and .bss. It undoes what a
   bootloader may have left, configures the core supply, initialises the
   RAM ECC, the caches and the MPU stack guard. Derived from bb-runtimes'
   arm/stm32/start-common.S (the submodule at v16.1.0-1, d7ab8df). */

	.syntax unified
	.cpu cortex-m7
	.thumb

	.text
	.thumb_func
	.globl	_stm32_start_common
	.type _stm32_start_common, %function
_stm32_start_common:

        /* Both callers branch here with nothing on the stack. The routine
           clobbers r0 .. r8 and r11, callee-saved ones included, and sets
           the main stack pointer; the callers rely on both. */

        /* Park unless privileged and in thread mode. From a bootloader's
           exception handler, that exception would stay active (no PendSV,
           SVC or SysTick could pre-empt the start-up, and CONTROL's stack
           selection would be ignored); unprivileged (CONTROL.nPRIV), the
           first system control space access, the ICIALLU below, would
           BusFault into the bootloader's vector table. Reading IPSR and
           CONTROL needs no privilege. Then invalidate the instruction
           cache, which an image entered by a branch can find on, holding
           what was at these addresses before (a bootloader may have just
           written this image); after a reset it is off. init_cache sets
           the caches up. */
        mrs     r0, ipsr
        cmp     r0, #0
        bne     __gnat_handover_in_handler
        mrs     r0, control
        tst     r0, #1                  /* nPRIV */
        bne     __gnat_handover_unprivileged
        ldr     r0, =0xE000EF50         /* ICIALLU */
        movs    r1, #0
        str     r1, [r0]
        dsb
        isb

        /* Hand-over: undo the state a bootloader that branched here may
           have left, which would interrupt the start-up or which the
           runtime assumes at its reset value; after a reset none of this
           changes anything. SysTick, NVIC, ICSR: PM0253 4.4.1, 4.2, 4.3.3.
           CONTROL = 0: privileged, main stack, no floating-point context.
           The main stack pointer goes to the top of the environment stack:
           start-rom.S never loads it, the core does so only on a reset.
           The MPU goes off before the first RAM write, so that a region
           left over the ITCM or the AXI SRAM cannot fault the ECC zeroing
           (guard_init programs the guard again). FPCCR: lazy stacking
           (ASPEN, LSPEN, as at reset, PM0253 4.7.2), which the tasking
           context switch relies on, with no lazy save pending (LSPACT).
           FPDSCR and SCR to their reset values, so that the tasking
           runtime's idle WFI inherits no deep sleep or sleep on exit.
           CCR (PM0253 4.3.7) loses UNALIGN_TRP, which makes every
           unaligned access the compiler emits (packed records) a
           UsageFault, and BFHFNMIGN; its other bits stay (the caches are
           handled below, the tasking runtime sets its own). */
        ldr     r0, =0xE000E010         /* SYST_CSR */
        movs    r1, #0
        str     r1, [r0]
        ldr     r0, =0xE000E180         /* NVIC_ICER0; ICPR0 at +0x100 */
        mov     r1, #0xFFFFFFFF
        movs    r2, #8
0:      str     r1, [r0, #0x100]
        str     r1, [r0], #4
        subs    r2, r2, #1
        bne     0b
        ldr     r0, =0xE000ED04         /* ICSR */
        ldr     r1, =0x0A000000         /* PENDSVCLR, PENDSTCLR */
        str     r1, [r0]
        movs    r1, #0
        msr     basepri, r1
        msr     control, r1
        isb
        ldr     r0, =__stack_end
        mov     sp, r0
        ldr     r0, =0xE000ED94         /* MPU_CTRL */
        str     r1, [r0]
        ldr     r0, =0xE000EF34         /* FPCCR */
        ldr     r1, [r0]
        orr     r1, r1, #0xC0000000     /* ASPEN, LSPEN */
        bic     r1, r1, #1              /* LSPACT */
        str     r1, [r0]
        movs    r1, #0
        ldr     r0, =0xE000EF3C         /* FPDSCR */
        str     r1, [r0]
        ldr     r0, =0xE000ED10         /* SCR */
        str     r1, [r0]
        ldr     r0, =0xE000ED14         /* CCR */
        ldr     r1, [r0]
        bic     r1, r1, #0x108          /* UNALIGN_TRP, BFHFNMIGN */
        str     r1, [r0]
        dsb
        isb

        /* Install handler.S's vector table in every profile, before the
           first instruction that can fault: upstream's start-rom.S has a
           five-entry table whose fault entries hang (the light runtime's),
           and System.BB.CPU_Primitives installs handler.S's only in
           programs that use tasking. The configurable faults are enabled
           so that each keeps its own name in the report instead of
           escalating to HardFault. PRIMASK and FAULTMASK, which a
           bootloader may set before its jump and the light profile never
           clears, would escalate them all the same (with FAULTMASK, a
           lock-up); with the table in place and every interrupt disabled,
           they are cleared. */
        ldr     r0, =__vectors
        ldr     r1, =0xE000ED08         /* SCB VTOR */
        str     r0, [r1]
        ldr     r1, =0xE000ED24         /* SCB SHCSR */
        ldr     r2, [r1]
        orr     r2, r2, #0x00070000     /* USGFAULTENA, BUSFAULTENA, MEMFAULTENA */
        str     r2, [r1]
        dsb
        isb
        cpsie   i                       /* PRIMASK at its reset value */
        cpsie   f                       /* FAULTMASK at its reset value */

        /* Core supply (RM0468 6.4, Table 30): the crate option
           Supply_Configuration, as __supply_cr3 (a --defsym from the
           runtime's project file), into PWR_CR3 bits 0 to 5, the other
           bits kept. This lower byte goes before the voltage scaling, the
           clock change and, per 6.4.1, any write to RAM, hence first after
           the vector table. */
        ldr     r0, =0x5802480C         /* PWR_CR3 */
        ldr     r1, [r0]
        bic     r1, r1, #0x3F
        ldr     r2, =__supply_cr3
        orr     r1, r1, r2
        str     r1, [r0]
        /* The byte is write-once until a power-on reset (RM0468 6.8.4): if
           a bootloader or a previous image locked another arrangement, the
           write did nothing. Read back before the wait, a mismatch parks
           at its own label rather than at the wait's. */
        ldr     r1, [r0]
        and     r1, r1, #0x3F
        ldr     r2, =__supply_cr3
        cmp     r1, r2
        bne     __gnat_supply_mismatch
        /* Wait for ACTVOSRDY, bounded at 2**21 polls: a few hundred
           milliseconds (not measured) on the 64 MHz reset clock, from the
           flash with seven wait states and the caches off, for a level
           specified in microseconds. ST's HAL bounds the same wait. */
        ldr     r0, =0x58024804         /* PWR_CSR1 */
        ldr     r3, =0x200000
1:      ldr     r1, [r0]
        tst     r1, #0x2000             /* ACTVOSRDY */
        bne     4f
        subs    r3, r3, #1
        bne     1b
        b       __gnat_supply_not_ready
4:

        /* With SDEXTHP (bit 3: the four arrangements where the converter
           also supplies external circuits), wait for SDEXTRDY (PWR_CR3 bit
           16) too, as HAL_PWREx_ConfigSupply does: the external rail must
           be up before the voltage scaling changes. Untested: the
           NUCLEO-H723ZG has no converter. */
        ldr     r2, =__supply_cr3
        tst     r2, #0x08               /* SDEXTHP */
        beq     3f
        ldr     r0, =0x5802480C         /* PWR_CR3 */
        ldr     r3, =0x200000           /* the same bound */
2:      ldr     r1, [r0]
        tst     r1, #0x10000            /* SDEXTRDY */
        bne     3f
        subs    r3, r3, #1
        bne     2b
        b       __gnat_supply_not_ready
3:
        /* Enable both TCM interfaces before the first RAM write (to the
           DTCM). They are on at reset (PM0253 4.9), but a bootloader may
           have turned one off, and a store to a disabled TCM goes out on
           the AXI bus and faults. */
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

        /* The first RAM writes clear the fault report's re-entry latch and
           cause byte (System.BB.Faults.Reporting and Cause): they live in
           .data, loaded only later while the fault vectors are already
           live, and the DTCM keeps them across a warm reset. */
        movs    r1, #0
        ldr     r0, =__gnat_fault_reporting
        strb    r1, [r0]
        ldr     r0, =__gnat_fault_cause
        strb    r1, [r0]

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

        /* AdaCore's version of this file sets the caches up only for the
           F7 device IDs in the F4/F7 DBGMCU_IDCODE (0xE0042000). The
           STM32H72x/H73x has only a Cortex-M7 (DBGMCU_IDC at 0x5C001000,
           DEV_ID 0x483), so the caches and the TCM interfaces (PM0253
           4.9.1, at tcm_init) are set up unconditionally; init_cache
           follows PM0253 4.8.5. */

        /* ECC of the AXI SRAM and the ITCM: 8 bits per 64-bit word (RM0468
           2.4), so the first sub-word write to a word unwritten since
           power-up is a read-modify-write against a garbage ECC, which the
           RAMECC monitor flags. The start-up's 32-bit copy of .axisram, a
           task or a DMA can make one (measured: D1 monitor 1 read 0x7 after
           one program that used the AXI SRAM). Both are zeroed with 64-bit
           stores, the data cache off, before anything touches them;
           .axisram is copied afterwards. On the 64 MHz reset clock, before
           the clock set-up; the duration is not measured. */

        /* \op on every data cache line by set/way (DCISW invalidates,
           DCCISW cleans and invalidates), from CCSIDR's geometry (PM0253
           4.8). Clobbers r0 .. r4, r6 .. r8 and r11. */
        .macro  dcache_setway op
        mov     r0, #0x0
        ldr     r11, =0xE000ED84        /* CSSELR: the data cache */
        str     r0, [r11]
        dsb
        ldr     r11, =0xE000ED80        /* CCSIDR */
        ldr     r2, [r11]
        and     r1, r2, #0x7            /* words per line (log2 - 2) */
        add     r7, r1, #0x4
        ubfx    r4, r2, #3, #10         /* ways - 1 */
        ubfx    r2, r2, #13, #15        /* sets - 1 */
        clz     r6, r4                  /* the way field's offset */
        ldr     r11, =\op
1:      mov     r1, r4
        lsls    r8, r2, r7
2:      lsls    r3, r1, r6
        orrs    r3, r3, r8
        str     r3, [r11]
        subs    r1, r1, #1
        bge     2b
        subs    r2, r2, #1
        bge     1b
        dsb
        .endm

        /* A data cache a bootloader left on is cleaned, invalidated and
           turned off: the zeroing below must reach memory, and the
           invalidate at init_cache would discard dirty lines. After a
           reset the cache is off and its random lines must not be cleaned,
           so this is skipped. */
        ldr     r11, =0xE000ED14        /* CCR */
        ldr     r0, [r11]
        tst     r0, #0x10000            /* DC */
        beq     ecc_init
        dcache_setway 0xE000EF74        /* DCCISW */
        ldr     r11, =0xE000ED14
        ldr     r0, [r11]
        bic     r0, r0, #0x10000
        str     r0, [r11]
        dsb
        isb

ecc_init:
        /* The sizes come from the device, so that every sharing boots with
           every word valid: TCM_AXI_SHARED in FLASH_OPTSR2_CUR (RM0468
           4.9.24) gives 64, 128, 192 or 256 KB of ITCM, the AXI SRAM has
           the rest of 384 KB. Both are kept for inspection (see
           __ecc_itcm_bytes in common-sections.ld). The linker scripts
           describe the default sharing; any other leaves less AXI SRAM
           than they declare. */
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
        /* With less AXI SRAM, .axisram or a RAM-loaded image can reach past
           it and bus-fault before main, so its ends are checked against the
           device's size. __ccmdata_end and __axisram_bss_end are weak, as a
           user script may define neither. */
        .weak   __ccmdata_end
        movw    r0,#:lower16:__axisram_start
        movt    r0,#:upper16:__axisram_start
        adds    r1,r0,r5                /* the device's end of the AXI SRAM */
        ldr     r0,=__ccmdata_end
        cmp     r0,r1
        bhi     __gnat_axisram_mismatch
        ldr     r0,=__ecc_axisram_zero_start
        cmp     r0,r1
        bhi     __gnat_axisram_mismatch
        .weak   __axisram_bss_end
        ldr     r0,=__axisram_bss_end
        cmp     r0,r1
        bhi     __gnat_axisram_mismatch
        movs    r2,#0
        movs    r3,#0
        movw    r0,#:lower16:__axisram_start
        movt    r0,#:upper16:__axisram_start
        adds    r1,r0,r5                /* end = start + the device's size */
        movw    r0,#:lower16:__ecc_axisram_zero_start
        movt    r0,#:upper16:__ecc_axisram_zero_start
                                        /* ROM loader: the start. RAM loader:
                                           past the loaded image */
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

sram_init:
        /* Copy .sram12 and .sram4 from their load images (common-sections.ld)
           in whole words, so that every word gets a valid ECC, with the
           data cache still off. The SRAM1 and SRAM2 clocks are off after
           reset (RM0468 8.7.41): when .sram12 is not empty they are enabled
           first, and read back so that the enable takes effect before the
           first access. SRAM4's is on. The symbols are weak, as a user
           script may define neither section. */
        .weak   __sram12_start
        .weak   __sram12_end
        .weak   __sram12_load
        .weak   __sram4_start
        .weak   __sram4_end
        .weak   __sram4_load
        ldr     r0, =__sram12_start
        ldr     r1, =__sram12_end
        cmp     r0, r1
        bhs     2f
        ldr     r2, =0x580244DC         /* RCC_AHB2ENR */
        ldr     r3, [r2]
        orr     r3, r3, #0x60000000     /* SRAM1EN, SRAM2EN */
        str     r3, [r2]
        ldr     r3, [r2]
        dsb
        ldr     r2, =__sram12_load
0:      cmp     r0, r1
        bhs     2f
        ldr     r3, [r2], #4
        str     r3, [r0], #4
        b       0b
2:      ldr     r0, =__sram4_start
        ldr     r1, =__sram4_end
        ldr     r2, =__sram4_load
0:      cmp     r0, r1
        bhs     1f
        ldr     r3, [r2], #4
        str     r3, [r0], #4
        b       0b
1:      dsb

init_cache:
        /********************
         * Enable I/D cache *
        ********************/

        /* Register definition for cache handling */
        .set    ICIALLU, 0xE000EF50
        .set    CCR,     0xE000ED14

        /* First invalidate the data cache */
        dcache_setway 0xE000EF60        /* DCISW */

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

guard_init:
        /* Stack_Guard, a crate option of the tasking profiles: the two
           static no-access windows, programmed once for every program, MPU
           region 13 at the bottom of the interrupt stack and region 14 at
           the bottom of the environment stack. The tasking runtime checks
           that this ran (Initialize_CPU) and adds each task's window as it
           switches; a light-tasking program with no tasking unit never
           runs that, so this is its only guard. The values mirror
           Set_Guard in s-bbcppr.adb (AP = 000; PM0253 Tables 90 and 93).
           __stack_guard_bytes, the crate's --defsym, is the window with
           the option on (a power of two in 128 .. 512) and 8, an alignment
           only, with it off; below 32 the guard is skipped. The weak
           reference reads 0 under a user linker script that omits it. */
        /* Every region is cleared first, guard on or off (PM0253 4.6.9),
           with the MPU off since the hand-over block: regions a bootloader
           or a debugger's reload without a reset left enabled would revive
           when an application enables the MPU for its own. */
        ldr     r2, =0xE000ED90         /* MPU_TYPE */
        ldr     r3, [r2]
        ubfx    r3, r3, #8, #8          /* DREGION */
        ldr     r2, =0xE000ED98         /* MPU_RNR; RASR at +8 */
        movs    r1, #0
4:      subs    r3, r3, #1
        blo     5f
        str     r3, [r2]
        str     r1, [r2, #8]
        b       4b
5:      dsb
        isb
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
        /* Region 13 only with an interrupt stack: a light-tasking program
           without a tasking unit has none (start = end), and a window there
           would sit on the fault stack that follows. */
        ldr     r3, =__interrupt_stack_start
        ldr     r0, =__interrupt_stack_end
        cmp     r3, r0
        beq     2f
        add     r3, r3, r4
        bic     r3, r3, r4              /* rounded up to the window */
        orr     r3, r3, #0x1D           /* VALID, region 13 */
        str     r3, [r2]
        str     r1, [r2, #4]
2:      ldr     r3, =__stack_start
        add     r3, r3, r4
        bic     r3, r3, r4
        orr     r3, r3, #0x1E           /* VALID, region 14 */
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

        /* Parking loops, each named so that a debugger shows why the
           start-up stopped. */
        .globl  __gnat_handover_in_handler
        .type   __gnat_handover_in_handler, %function
        .thumb_func
__gnat_handover_in_handler:
        b       __gnat_handover_in_handler
        .globl  __gnat_handover_unprivileged
        .type   __gnat_handover_unprivileged, %function
        .thumb_func
__gnat_handover_unprivileged:
        b       __gnat_handover_unprivileged
        .globl  __gnat_supply_mismatch
        .type   __gnat_supply_mismatch, %function
        .thumb_func
__gnat_supply_mismatch:
        b       __gnat_supply_mismatch
        .globl  __gnat_axisram_mismatch
        .type   __gnat_axisram_mismatch, %function
        .thumb_func
__gnat_axisram_mismatch:
        b       __gnat_axisram_mismatch
        /* The voltage levels or the external converter not ready within
           the bound: the arrangement is not the board's. */
        .globl  __gnat_supply_not_ready
        .type   __gnat_supply_not_ready, %function
        .thumb_func
__gnat_supply_not_ready:
        b       __gnat_supply_not_ready
        /* Where the clock set-up's bounded waits end (setup_pll.adb,
           Wait_Bound). */
        .globl  __gnat_hse_not_ready
        .type   __gnat_hse_not_ready, %function
        .thumb_func
__gnat_hse_not_ready:
        b       __gnat_hse_not_ready
        .globl  __gnat_pll_not_locked
        .type   __gnat_pll_not_locked, %function
        .thumb_func
__gnat_pll_not_locked:
        b       __gnat_pll_not_locked
        .globl  __gnat_clock_not_ready
        .type   __gnat_clock_not_ready, %function
        .thumb_func
__gnat_clock_not_ready:
        b       __gnat_clock_not_ready
