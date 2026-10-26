import importlib.util
import pathlib
import re
import shutil
import subprocess
import sys
from typing import Dict, List, Optional, Any

import support.target_info


class TestHarness:
    __test__ = False

    def __init__(
        self,
        testcase_dir: pathlib.Path,
        working_dir: pathlib.Path,
        target_info: support.target_info.TargetInfo,
    ):
        self.testcase_name = testcase_dir.name

        self._target_info = target_info

        self._testcase_sources_dir = testcase_dir
        self._testcase_working_dir = working_dir
        self._testcase_working_dir.mkdir(parents=True, exist_ok=True)

        # Load the opt.py file if one is present

        opt_file = self._testcase_sources_dir / "opt.py"
        module_name = self.testcase_name + "_opt"

        if not opt_file.exists():
            module = None
        elif module_name not in sys.modules:
            spec = importlib.util.spec_from_file_location(module_name, opt_file)
            module = importlib.util.module_from_spec(spec)
            sys.modules[module_name] = module
            spec.loader.exec_module(module)
        else:
            module = sys.modules[module_name]

        self._opt_module = module

    def build(self):
        """Invoke alr build on the test case (extra gprbuild arguments from
        the testcase's build_args() go after "--", e.g. -XLOADER=RAM)"""
        args = ["alr", "build"]
        extra = self.build_args()
        if extra:
            args += ["--"] + extra
        return subprocess.run(args=args, cwd=self._testcase_working_dir)

    def setup(self):
        """Setup the test harness"""
        self._generate_gpr()
        self._generate_alire_manifest()

    @property
    def executable_path(self) -> pathlib.Path:
        """Get the path to the executable that is built by the test harness"""
        return self._testcase_working_dir / "obj" / "test"

    def check_test_conditions(self):
        """
        Call check_test_conditions() in the testcase's opt.py file, if it exists.

        This may call pytest.skip() if the test is not applicable in certain
        conditions.
        """
        if self._opt_module is None:
            return

        if not hasattr(self._opt_module, "check_test_conditions"):
            return

        return self._opt_module.check_test_conditions(self._target_info)

    def local_crates(self) -> List[str]:
        """
        Call local_crates() in the testcase's opt.py file, if it exists.

        This returns a list of names of crates that are located in the top level
        in the testcase directory.
        """
        if self._opt_module is None:
            return []

        if not hasattr(self._opt_module, "local_crates"):
            return []

        return self._opt_module.local_crates(self._target_info)

    def external_crates(self) -> Dict[str, str]:
        """
        Call external_crates() in the testcase's opt.py file, if it exists.

        This returns a dictionary of crates in the Alire index and the version
        to use.
        """
        if self._opt_module is None:
            return {}

        if not hasattr(self._opt_module, "external_crates"):
            return {}

        return self._opt_module.external_crates(self._target_info)

    def crate_config_values(self) -> Dict[str, Any]:
        """
        Call crate_config_values() in the testcase's opt.py file, if it exists.

        This returns a dictionary of crate configuration variable names and
        their associated values.
        """
        if self._opt_module is None:
            return {}

        if not hasattr(self._opt_module, "crate_config_values"):
            return {}

        return self._opt_module.crate_config_values(self._target_info)

    def unswitched_units(self) -> List[str]:
        """
        Call unswitched_units() in the testcase's opt.py file, if it exists: the
        units that must not take compiler_switches (the last-chance handler,
        test_lch.adb by default: a handler compiled with -fstack-check re-raises
        from its own prologue when entered below the limit).
        """
        if self._opt_module is None or not hasattr(self._opt_module, "unswitched_units"):
            return ["test_lch.adb"]

        return list(self._opt_module.unswitched_units(self._target_info))

    def io_timeout(self) -> float:
        """
        Call io_timeout() in the testcase's opt.py file, if it exists: the
        seconds the harness waits for the program's output to reach the
        completion marker (5 by default; a test that waits for a slow
        oscillator asks for more).
        """
        if self._opt_module is None or not hasattr(self._opt_module, "io_timeout"):
            return 5.0

        return float(self._opt_module.io_timeout(self._target_info))

    def build_args(self) -> List[str]:
        """
        Call build_args() in the testcase's opt.py file, if it exists.
        This returns a list of extra arguments for gprbuild (e.g. a scenario
        variable such as -XLOADER=RAM).
        """
        if self._opt_module is None:
            return []
        if not hasattr(self._opt_module, "build_args"):
            return []
        return self._opt_module.build_args(self._target_info)

    def compiler_switches(self) -> List[str]:
        """
        Call compiler_switches() in the testcase's opt.py file, if it exists.
        This returns a list of extra Ada compiler switches for the test
        program's own units (e.g. -fstack-check), not for the runtime.
        """
        if self._opt_module is None:
            return []
        if not hasattr(self._opt_module, "compiler_switches"):
            return []
        return self._opt_module.compiler_switches(self._target_info)

    def linker_switches(self) -> List[str]:
        """
        Call linker_switches() in the testcase's opt.py file, if it exists.
        This returns a list of extra linker switches for the test program
        (e.g. a --defsym that sizes the environment stack).
        """
        if self._opt_module is None:
            return []
        if not hasattr(self._opt_module, "linker_switches"):
            return []
        return self._opt_module.linker_switches(self._target_info)

    def source_dirs(self) -> List[str]:
        """
        Call source_dirs() in the testcase's opt.py file, if it exists.

        This returns a list of paths for additional source directories,
        relative to the testcase directory
        """
        if self._opt_module is None:
            return {}

        if not hasattr(self._opt_module, "source_dirs"):
            return {}

        return self._opt_module.source_dirs(self._target_info)

    def _generate_gpr(self):
        """Generate a test.gpr file in the harness's working directory"""
        with open(self._testcase_working_dir / "test.gpr", "w") as f:
            if self._target_info.requires_linker_switches:
                runtime_linker_switches = "Runtime_Build.Linker_Switches"
            else:
                runtime_linker_switches = "()"

            source_dirs = [self._testcase_sources_dir.absolute()]
            source_dirs += [self._testcase_sources_dir / sd for sd in self.source_dirs()]
            extra_linker_switches = "".join(f', "{sw}"' for sw in self.linker_switches())
            # The test's own last-chance handler, if any, keeps the default
            # switches: a handler compiled with -fstack-check re-raises from its
            # own prologue when it is entered below the stack's limit.
            compiler_package = (
                "    package Compiler is\n"
                "        for Switches (\"Ada\") use (" + ", ".join(f'"{sw}"' for sw in self.compiler_switches()) + ");\n"
                + "".join(f"        for Switches (\"{u}\") use ();\n" for u in self.unswitched_units()) +
                "    end Compiler;\n"
                if self.compiler_switches() else "")

            f.write(
                f"""
with "config/test_config.gpr";
with "runtime_build.gpr";
{"with \"ravenscar_build.gpr\";" if self._target_info.has_libgnarl else ""}
project Test is
    for Source_Dirs use ({", ".join(f'"{sd}"' for sd in source_dirs)});
    for Object_Dir use "obj";
    for Create_Missing_Dirs use "True";
    for Main use ("test.adb");

    for Target use Runtime_Build'Target;
    for Runtime ("Ada") use Runtime_Build'Runtime ("Ada");

    Runtime_Linker_Switches := {runtime_linker_switches};

{compiler_package}    package Linker is
        for Switches ("Ada") use Runtime_Linker_Switches &
          ("-Wl,--gc-sections", "-Wl,--fatal-warnings"{extra_linker_switches});
    end Linker;
end Test;
"""
            )

    def _generate_alire_manifest(self):
        """Generate an alire.toml file in the harness's working directory"""

        def config_var_string(
            var_name: str,
            value: Any,
            prefix: Optional[str] = self._target_info.runtime_crate_name,
        ) -> str:
            if prefix is None:
                key = var_name
            else:
                key = f"{prefix}.{var_name}"

            if type(value) == str:
                escaped_value = f'"{value}"'
            elif type(value) == bool:
                escaped_value = str(value).lower()
            else:
                escaped_value = value

            res = f"{key} = {escaped_value}"
            return res

        def escape_path(path):
            return str(path).replace("\\", "\\\\")

        runtime_crate_name = self._target_info.runtime_crate_name
        runtime_crate_dir = self._target_info.runtime_crate_dir.absolute()

        # A testcase that sets runtime crate configuration values builds its
        # own copy of the runtime crate, from scratch, in its working
        # directory. Sharing the installed crate between tests with different
        # configurations is not reliable: the runtime's units are recompiled,
        # but the library's installed ALIs are not always refreshed in the
        # same build, and the next test's binder then reports
        # "must be recompiled" (seen on stm32h7xx, and again for embedded
        # rows of test_negative_builds.py, which ask for the copy through
        # TargetInfo). Every other test, the repository's configuration
        # rows included and a testcase that configures another crate (the
        # RP2040 HAL testcase sets rp2040_hal.*), keeps sharing the
        # installed crate.
        own_values = any(k.startswith(runtime_crate_name + ".") for k in self.crate_config_values())
        if own_values or self._target_info.private_runtime_crate:
            private_crate = self._testcase_working_dir / runtime_crate_dir.name
            shutil.copytree(
                src=runtime_crate_dir,
                dst=private_crate,
                ignore=shutil.ignore_patterns("obj", "adalib", "lib", "alire", "*.o", "*.ali"),
            )
            runtime_crate_dir = private_crate

        dependencies = {runtime_crate_name: "*"}
        dependencies |= self.external_crates()

        pins = {self._target_info.runtime_crate_name: runtime_crate_dir}

        configuration_values = {
            f"{runtime_crate_name}.{k}": v
            for k, v in self._target_info.configuration_values.items()
        }

        configuration_values |= self.crate_config_values()

        # Copy local crates to the testcase's working directory.
        #
        # GPRbuild does not always seem to rebuild the crate properly when the
        # same crate instance is shared between tests, which can result in
        # errors where the binder is looking for a unit for the wrong runtime
        # from a previous build. To avoid this a fresh copy of the crate is
        # made for each test so that the build files are contained within the
        # test harness's working directory.

        for crate_path in self.local_crates():
            dst = self._testcase_working_dir / crate_path.name
            shutil.copytree(src=crate_path, dst=dst)

            dependencies[crate_path.name] = "*"
            pins[crate_path.name] = str(dst)

        with open(self._testcase_working_dir / "alire.toml", "w") as f:
            f.write(
                f"""
name = "test"
description = "Testcase crate"
version = "0.1.0-dev"

[[depends-on]]
{"\n".join(f'{k} = "{v}"' for k, v in dependencies.items())}

[[pins]]
{"\n".join(f'{k} = {{ path = "{escape_path(v)}" }}' for k, v in pins.items())}

[configuration.values]
{"\n".join(config_var_string(k,v,prefix=None) for k,v in configuration_values.items())}
"""
            )
