import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location("read_logs", Path(__file__).parents[1] / "read-logs.py")
reader = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reader)


class LogReaderTests(unittest.TestCase):
    def test_rotation_order_and_partial_tail_preserve_readable_history(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            for name, sequence in [("events.2.jsonl", 1), ("events.1.jsonl", 2), ("events.jsonl", 3)]:
                (root / name).write_text(json.dumps({"schemaVersion": 1, "sequence": sequence}) + "\n")
            with (root / "events.jsonl").open("a") as file:
                file.write('{"unfinished":')
            records, malformed = reader.load_records(root)
            self.assertEqual([r["sequence"] for r in records], [1, 2, 3])
            self.assertEqual(malformed, 1)

    def test_one_attempt_includes_capture_but_not_other_attempts_or_successes(self):
        records = [
            {"event": "capture.ready", "fields": {"captureID": "capture-a"}},
            {"operationID": "old", "event": "insertion.verified", "fields": {"captureID": "capture-a"}},
            {"operationID": "CURRENT", "event": "insertion.failed", "fields": {"captureID": "capture-a"}},
            {"event": "capture.ready", "fields": {"captureID": "capture-b"}},
        ]
        result = reader.for_operation(records, "current")
        self.assertEqual([r["event"] for r in result], ["capture.ready", "insertion.failed"])


if __name__ == "__main__":
    unittest.main()
