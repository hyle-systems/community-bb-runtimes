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
 *                   Copyright (C) 2003-2020 AdaCore                        *
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

/* The RAM map of every STM32H723/725/730/733/735 (RM0468 Table 6), for
   both loaders: ITCM 64 KB, DTCM 128 KB, AXI SRAM 128 KB + 192 KB shared
   with the ITCM through option bytes (all on the AXI side at reset),
   SRAM1+SRAM2 2 x 16 KB contiguous in the D2 domain, SRAM4 16 KB in the D3
   domain. */

/* The program's data, zeroed data, the interrupt, main and task stacks
   and the heap live in the DTCM: one cycle away and never cached, so the
   runtime's own state is deterministic and free of cache coherency
   issues. The RAM loader's code goes in the AXI SRAM: it could run from
   the DTCM (PM0253's memory map), but would compete with the data and
   the stacks for its 128 KB. */

MEMORY
{
  itcm     (rwx) : ORIGIN = 0x00000000, LENGTH = 64K
  dtcm     (rw)  : ORIGIN = 0x20000000, LENGTH = 128K
  axisram  (rwx) : ORIGIN = 0x24000000, LENGTH = 320K
  sram12   (rwx) : ORIGIN = 0x30000000, LENGTH = 32K
  sram4    (rwx) : ORIGIN = 0x38000000, LENGTH = 16K
}

REGION_ALIAS("sram_tx", axisram)
REGION_ALIAS("sram_ro", axisram)
REGION_ALIAS("sram_da", dtcm)
REGION_ALIAS("sram_bs", dtcm)
REGION_ALIAS("ccm_da", axisram)
