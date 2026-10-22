"""Compare the supported finite profile against python-jsonschema, not full OAS.

Run with Python >=3.10 and jsonschema==4.26.0. No output files are written.
MoonBit emits original fixtures and results as NDJSON; this process separately
validates those same fixtures using Draft202012Validator. Failure is nonzero.
"""
import json
import os
from pathlib import Path
import subprocess
import sys
from importlib.metadata import version

from jsonschema import Draft202012Validator


def main():
    root = Path(__file__).resolve().parent.parent
    moon = (["pwsh", "-NoProfile", "-File", str(root / "tools/windows/moon.ps1")]
            if os.name == "nt" else ["moon"])
    result = subprocess.run(
        moon + ["run", "tools/contract_oracle", "--target", "wasm-gc", "--frozen"],
        cwd=root, text=True, encoding="utf-8", capture_output=True, check=True)
    if result.stderr:
        print(result.stderr, file=sys.stderr, end="")
    matched = 0
    for line in result.stdout.splitlines():
        row = json.loads(line)
        Draft202012Validator.check_schema(row["schema"])
        expected = Draft202012Validator(row["schema"]).is_valid(row["instance"])
        if expected != row["valid"]:
            raise AssertionError(f"oracle mismatch at schema={row['schemaIndex']}, instance={row['instanceIndex']}")
        matched += 1
    if matched != 351:
        raise AssertionError(f"expected 351 observations, got {matched}")
    print(json.dumps({"reference": "python-jsonschema", "version": version("jsonschema"),
                      "draft": "2020-12", "cases": matched, "matched": matched}))


if __name__ == "__main__":
    main()
