import subprocess
import filecmp
import os
import tempfile
import pytest
from pathlib import Path

# Path to the built executable (adapt as needed!)
WRITE_TDACS = Path("../build/tools/writetdacs")  # or your actual path

# Path to golden reference files
GOLDEN = Path("data")


def run_tdacs(args, output_path):
    """
    Run write_tdacs with given arguments and write to output_path.
    """
    cmd = [str(WRITE_TDACS)] + args + ["--output", str(output_path)]
    result = subprocess.run(cmd, capture_output=True, text=True)

    if result.returncode != 0:
        raise RuntimeError(
            f"write_tdacs failed:\nstdout:\n{result.stdout}\nstderr:\n{result.stderr}"
        )


def test_checkerboard_matches_golden():
    checker_size = 16
    with tempfile.TemporaryDirectory() as tmpdir:
        out = Path(tmpdir) / "checker.bin"

        # run tool
        run_tdacs(["--checker", str(checker_size)], out)

        # compare to golden file
        golden = GOLDEN / "checker_16.bin"
        assert golden.exists(), f"Golden file missing: {golden}"

        assert filecmp.cmp(out, golden, shallow=False), "Checkerboard TDAC mismatch"


def test_wave_matches_golden():
    wave_size = 16
    with tempfile.TemporaryDirectory() as tmpdir:
        out = Path(tmpdir) / "wave.bin"

        # run tool
        run_tdacs(["--wave", str(wave_size)], out)

        # compare to golden file
        golden = GOLDEN / "wave_16.bin"
        assert golden.exists(), f"Golden file missing: {golden}"

        assert filecmp.cmp(out, golden, shallow=False), "Wave TDAC mismatch"
