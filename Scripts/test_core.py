#!/usr/bin/env python3
"""Run the XCTest methods with Swift Command Line Tools, without duplicating tests."""
import os
from pathlib import Path
import re
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="morning-reset-tests-") as scratch:
    scratch = Path(scratch)
    tests = sorted((root / "Tests/MorningResetCoreTests").glob("*.swift"))
    calls = []
    for source in tests:
        content = source.read_text()
        suite = re.search(r"final class (\w+): XCTestCase", content).group(1)
        for name, throwing in re.findall(r"func (test\w+)\(\)( throws)?", content):
            expression = ("try " if throwing else "") + f"{suite}().{name}()"
            if throwing:
                calls.append(f'do {{ {expression} }} catch {{ CheckResults.fail("{name}: \\(error)", file: #filePath, line: #line) }}')
            else:
                calls.append(expression)
    runner = scratch / "Runner.swift"
    runner.write_text('import Foundation\n@main struct CoreChecks { static func main() {\n'
                      + "\n".join(calls)
                      + f'\nprint("{len(calls)} test cases; \\(CheckResults.failures) assertion failures")\n'
                      + 'exit(CheckResults.failures == 0 ? 0 : 1)\n} }\n')
    sources = sorted((root / "Sources/MorningResetCore").glob("*.swift"))
    env = dict(os.environ, CLANG_MODULE_CACHE_PATH="/tmp/morning-reset-clang-cache")
    executable = scratch / "core-checks"
    subprocess.run(["swiftc", "-D", "CORE_TEST_RUNNER", "-module-cache-path", "/tmp/morning-reset-swift-cache",
                    "-o", str(executable), *map(str, sources), *map(str, tests),
                    str(root / "Scripts/CoreTestSupport.swift"), str(runner)], check=True, env=env)
    subprocess.run([str(executable)], check=True, env=env)
