import support.target_info
import pytest


def check_test_conditions(target_info: support.target_info.TargetInfo):
    # The MPU stack guard is an option of the stm32h7xx family's tasking runtimes.
    if target_info.target != "stm32h7xx":
        pytest.skip(f"Test requires target 'stm32h7xx'")
    if not target_info.has_libgnarl:
        pytest.skip(f"Test requires a runtime with libgnarl")


def crate_config_values(target_info: support.target_info.TargetInfo):
    # An 8 KB interrupt stack: on embedded the fault path (the raise, the
    # unwinder and the handler, in handler mode on the interrupt stack)
    # overflows the default 1 KB once a 256-byte window takes its bottom,
    # faults again and escalates to a hard fault - finding 7 (2026-10-21),
    # held by test_fault_stack_default and measured by test_fault_stack_use.
    return {
        f"{target_info.runtime_crate_name}.Stack_Guard": True,
        f"{target_info.runtime_crate_name}.Stack_Guard_Bytes": 256,
        f"{target_info.runtime_crate_name}.Interrupt_Stack_Size": 8192,
    }


def source_dirs(target_info: support.target_info.TargetInfo):
    # The test's own last-chance handler, in the shape each profile's runtime calls it:
    # (Msg, Line) in light and light-tasking, an Exception_Occurrence in embedded.
    return ["lch_embedded"] if target_info.runtime_profile == "embedded" else ["lch_light"]
