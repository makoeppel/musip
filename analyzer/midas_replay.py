"""Replay events from a MIDAS file through a periodic MIDAS frontend."""

import argparse
import math
from pathlib import Path
import sys
import time
from typing import Any, Iterator, Optional

import midas
import midas.event
import midas.file_reader
import midas.frontend


class MidasReplayEquipment(midas.frontend.EquipmentBase):
    """Read and emit one non-internal event from a MIDAS file per callback."""

    def __init__(
        self,
        client: Any,
        filename: Path,
        rate_hz: float,
        repeat: bool,
    ) -> None:
        common = midas.frontend.InitialEquipmentCommon()
        common.equip_type = midas.EQ_PERIODIC
        common.buffer_name = "SYSTEM"
        common.trigger_mask = 0
        common.event_id = 1
        common.period_ms = max(1, math.floor(1000 / rate_hz))
        common.read_when = midas.RO_RUNNING
        common.log_history = 1

        super().__init__(client, "MidasReplay", common)
        self._filename = filename
        self._repeat = repeat
        self._event_interval = 1.0 / rate_hz
        self._next_event_time: Optional[float] = None
        self._saw_event_this_pass = False
        self._file: midas.file_reader.MidasFile
        self._events: Iterator[midas.event.Event]
        self._open_file()

    def _open_file(self) -> None:
        self._file = midas.file_reader.MidasFile(str(self._filename))
        self._events = iter(self._file)
        self._saw_event_this_pass = False

    def readout_func(self) -> Optional[midas.event.Event]:
        now = time.monotonic()
        if self._next_event_time is None:
            self._next_event_time = now
        elif now < self._next_event_time:
            return None
        self._next_event_time += self._event_interval
        while self._next_event_time <= now:
            self._next_event_time += self._event_interval

        while True:
            try:
                event = next(self._events)
            except StopIteration:
                if not self._saw_event_this_pass:
                    raise RuntimeError(
                        f"No replayable events found in MIDAS file: {self._filename}"
                    )
                if not self._repeat:
                    self.set_status("Replay complete", "greenLight")
                    return None
                self._open_file()
                continue

            if event.header.is_midas_internal_event():
                continue

            for bank_name in [
                name for name, bank in event.banks.items() if len(bank.data) == 0
            ]:
                del event.banks[bank_name]

            self._saw_event_this_pass = True
            return event


class MidasReplayFrontend(midas.frontend.FrontendBase):
    def __init__(self, filename: Path, rate_hz: float, repeat: bool) -> None:
        super().__init__("midas_replay")
        self.add_equipment(
            MidasReplayEquipment(self.client, filename, rate_hz, repeat)
        )

    def begin_of_run(self, run_number: int) -> int:
        self.set_all_equipment_status("Running", "greenLight")
        self.client.msg(f"Replaying MIDAS events for run {run_number}")
        return midas.status_codes["SUCCESS"]

    def end_of_run(self, run_number: int) -> int:
        self.set_all_equipment_status("Finished", "greenLight")
        self.client.msg(f"Finished replaying events for run {run_number}")
        return midas.status_codes["SUCCESS"]


def parse_args() -> tuple[argparse.Namespace, list[str]]:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("midas_file", type=Path, help="MIDAS file to replay")
    parser.add_argument(
        "--rate-hz",
        type=float,
        required=True,
        help="Intended average replay rate in events per second (maximum 1000)",
    )
    parser.add_argument(
        "--repeat",
        action="store_true",
        help="Restart the file after its last replayable event",
    )
    args, midas_args = parser.parse_known_args()

    if not math.isfinite(args.rate_hz) or args.rate_hz <= 0 or args.rate_hz > 1000:
        parser.error("--rate-hz must be finite, greater than 0, and at most 1000")
    if not args.midas_file.is_file():
        parser.error(f"MIDAS file does not exist or is not a file: {args.midas_file}")

    return args, midas_args


if __name__ == "__main__":
    options, midas_args = parse_args()
    sys.argv = [sys.argv[0], *midas_args]
    with MidasReplayFrontend(
        options.midas_file, options.rate_hz, options.repeat
    ) as frontend:
        frontend.run()
