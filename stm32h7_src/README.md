# STM32H7xx Runtimes

Work in progress: GNAT runtimes (light, light-tasking, embedded) for the STM32H723 / H725 / H730 / H733 /
H735 line (reference manual RM0468), generated from the compiler's bb-runtimes sources with this
repository's generator. First target: the STM32H723ZG on the NUCLEO-H723ZG (8 MHz external clock from
the on-board ST-LINK, PLL1 to 520 MHz).

The usage and configuration documentation follows the stm32g4xx family's once the crates are generated.
