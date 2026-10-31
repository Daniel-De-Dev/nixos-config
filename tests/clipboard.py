"""History byte retention, privacy and selection handling; no display required."""

import base64
import importlib.util
import io
import json
import os
import shutil
import sqlite3
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

from PIL import Image, PngImagePlugin

spec = importlib.util.spec_from_file_location(
  "clipboard", "packages/clipboard/clipboard.py"
)
clipboard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(clipboard)


class ClipboardTest(unittest.TestCase):
  def setUp(self):
    self.runtime = tempfile.TemporaryDirectory()
    self.env = patch.dict(
      os.environ,
      {
        "XDG_RUNTIME_DIR": self.runtime.name,
        "WAYLAND_DISPLAY": "clipboard-test",
        "XDG_CACHE_HOME": self.runtime.name + "/cache",
      },
    )
    self.env.start()

  def tearDown(self):
    self.env.stop()
    self.runtime.cleanup()

  def add(self, db, data=b"ordinary text", mime="text/plain", source_path=""):
    clipboard.store(db, data, mime, "data", source_path=source_path)
    return db.execute("SELECT max(id) FROM entries").fetchone()[0]

  def test_sensitive_empty_and_oversized_data_are_not_stored(self):
    with clipboard.database() as db:
      for state in ("sensitive", "nil", "clear", "unknown", ""):
        clipboard.store(db, b"secret", "text/plain", state)
      self.add(db, b"")
      self.add(db, b"x" * (clipboard.MAX_ITEM_BYTES + 1))
      self.assertEqual(clipboard.snapshot(db)["total"], 0)

  def test_bytes_mime_and_paths_survive_without_shell_interpolation(self):
    payloads = [
      (b"\t\n  trailing spaces  \n", "text/plain;charset=utf-8"),
      (b"\x89PNG\r\n\x1a\n\x00\xff", "image/png"),
      (b"file:///home/user/a%20video.mp4\r\n", "text/uri-list"),
      (b"$(touch /tmp/clipboard-test); `id`\n", "text/plain"),
    ]
    with clipboard.database() as db:
      for data, mime in payloads:
        entry_id = self.add(db, data, mime)
        with patch.object(clipboard.subprocess, "run") as run:
          clipboard.copy_entry(db, entry_id)
          self.assertEqual(run.call_args.args[0], ["wl-copy", "--type", mime])
          self.assertEqual(run.call_args.kwargs["input"], data)

  def test_shared_fuzzy_search_contract_matches_the_ags_windows(self):
    cases = json.loads(Path("packages/ags-shell/tests/search-cases.json").read_text())
    for example in cases:
      with self.subTest(example["name"]):
        result = clipboard.fuzzy_rank(
          example["items"], example["query"], lambda item: item
        )
        self.assertEqual(result, example["expected"])

  def test_fuzzy_relevance_precedes_recency_and_empty_query_retains_it(self):
    with clipboard.database() as db:
      exact = self.add(db, b"hello")
      scattered = self.add(db, b"h e l l o")
      self.assertEqual(
        [item["id"] for item in clipboard.snapshot(db)["entries"]], [scattered, exact]
      )
      self.assertEqual(
        [item["id"] for item in clipboard.snapshot(db, "hello")["entries"]],
        [exact, scattered],
      )

  def test_fuzzy_searches_complete_payloads_without_serializing_them(self):
    with clipboard.database() as db:
      self.add(db, ("prefix " * 100 + "targetsecret").encode())
      result = clipboard.snapshot(db, "trgscrt")
      self.assertEqual(len(result["entries"]), 1)
      self.assertNotIn("targetsecret", json.dumps(result))
      self.add(
        db, b"file:///home/user/Screenshots/Screenshot%20One.png", "text/uri-list"
      )
      self.assertEqual(
        clipboard.snapshot(db, "scrnst png")["entries"][0]["preview"],
        "Screenshot One.png",
      )

  def test_search_checks_complete_text_and_decoded_file_paths(self):
    with clipboard.database() as db:
      self.add(db, ("prefix " * 100 + "Needle ÆØÅ").encode())
      self.add(db, b"file:///home/user/My%20Video.mp4\r\n", "text/uri-list")
      self.assertEqual(len(clipboard.snapshot(db, "needle æøå")["entries"]), 1)
      files = clipboard.snapshot(db, "my video")["entries"]
      self.assertEqual(files[0]["kind"], "video")
      self.assertEqual(files[0]["preview"], "My Video.mp4")
      self.assertEqual(files[0]["path"], "/home/user/My Video.mp4")

  def test_duplicates_move_to_front_and_do_not_retain_a_plain_text_secret_copy(self):
    with clipboard.database() as db:
      first = self.add(db, b"file:///tmp/video.mp4", "text/uri-list")
      middle = self.add(db, b"other")
      last = self.add(db, b"file:///tmp/video.mp4")
      state = clipboard.snapshot(db)
      self.assertGreater(last, middle)
      self.assertGreater(middle, first)
      self.assertEqual(state["total"], 2)
      self.assertEqual(state["entries"][0]["mime"], "text/uri-list")

  def test_pause_survives_client_restarts_and_stops_capture(self):
    with clipboard.database() as db:
      db.execute("INSERT INTO settings VALUES ('paused', 1)")
    with clipboard.database() as db:
      self.add(db, b"not recorded")
      self.assertTrue(clipboard.snapshot(db)["paused"])
      self.assertEqual(clipboard.snapshot(db)["total"], 0)

  def test_age_count_and_total_byte_limits(self):
    with clipboard.database() as db:
      self.add(db, b"expired")
      db.execute("UPDATE entries SET created = 0")
      self.add(db, b"new")
      self.assertEqual(clipboard.snapshot(db)["total"], 1)
      with patch.object(clipboard, "MAX_ITEMS", 2):
        self.add(db, b"second")
        self.add(db, b"third")
      self.assertEqual(clipboard.snapshot(db)["total"], 2)
      with patch.object(clipboard, "MAX_BYTES", 5):
        self.add(db, b"12345")
      self.assertEqual(clipboard.snapshot(db)["total"], 1)

  def test_delete_preserves_unrelated_active_clipboards(self):
    with clipboard.database() as db:
      entry_id = self.add(db, b"old secret")
      with (
        patch.object(
          clipboard,
          "paste",
          side_effect=lambda *args: (
            b"text/plain\n" if "--list-types" in args else b"new unrelated text"
          ),
        ),
        patch.object(clipboard, "clear_selection") as clear,
      ):
        clipboard.delete_entries(db, [entry_id])
        clear.assert_not_called()
      self.assertEqual(clipboard.snapshot(db)["total"], 0)

  def test_delete_clears_matching_primary_and_regular_selections(self):
    with clipboard.database() as db:
      entry_id = self.add(db, b"old secret")
      with (
        patch.object(
          clipboard,
          "paste",
          side_effect=lambda *args: (
            b"text/plain\n" if "--list-types" in args else b"old secret"
          ),
        ),
        patch.object(clipboard, "clear_selection") as clear,
      ):
        clipboard.delete_entries(db, [entry_id])
        self.assertEqual(clear.call_count, 2)
        self.assertEqual(clear.call_args_list[0].kwargs, {"primary": False})
        self.assertEqual(clear.call_args_list[1].kwargs, {"primary": True})

  def test_delete_overwrites_stored_payload_in_database_pages(self):
    secret = b"clipboard-test-unique-secret-5938" * 100
    with clipboard.database() as db:
      entry_id = self.add(db, secret)
    path = clipboard.directory() / "history.sqlite"
    self.assertIn(secret, path.read_bytes())
    with (
      clipboard.database() as db,
      patch.object(clipboard, "paste", return_value=None),
    ):
      clipboard.delete_entries(db, [entry_id])
    self.assertNotIn(secret, path.read_bytes())
    self.assertFalse(Path(str(path) + "-journal").exists())

  def test_clear_all_clears_both_selections_and_all_history(self):
    with clipboard.database() as db:
      self.add(db)
      with patch.object(clipboard, "clear_selection") as clear:
        clipboard.delete_entries(db)
        self.assertEqual(clear.call_count, 2)
      self.assertEqual(clipboard.snapshot(db)["total"], 0)

  def test_queued_capture_after_clearing_is_not_reinserted(self):
    stdin = Mock(buffer=io.BytesIO(b"old secret"))
    with (
      patch.dict(
        os.environ, {"CLIPBOARD_STATE": "data", "CLIPBOARD_TYPE": "text/plain"}
      ),
      patch.object(clipboard.sys, "argv", ["ags-clipboard", "store"]),
      patch.object(clipboard.sys, "stdin", stdin),
      patch.object(clipboard, "paste", return_value=None),
    ):
      clipboard.main()
    with clipboard.database() as db:
      self.assertEqual(clipboard.snapshot(db)["total"], 0)

  def test_clear_all_wipes_legacy_cliphist_only_when_present(self):
    legacy = Path(os.environ["XDG_CACHE_HOME"]) / "cliphist" / "db"
    legacy.parent.mkdir(parents=True)
    legacy.write_bytes(b"legacy database")
    with (
      clipboard.database() as db,
      patch.object(clipboard, "clear_selection"),
      patch.object(clipboard.subprocess, "run") as run,
    ):
      clipboard.delete_entries(db)
      self.assertEqual(
        run.call_args.args[0],
        [
          "cliphist",
          "-config-path",
          "/dev/null",
          "-db-path",
          str(legacy),
          "wipe",
        ],
      )

  def test_history_deletion_survives_a_clipboard_clear_failure(self):
    with clipboard.database() as db:
      self.add(db, b"deleted even if display is unavailable")
    with (
      self.assertRaises(RuntimeError),
      clipboard.database() as db,
      patch.object(clipboard, "clear_selection", side_effect=OSError("no display")),
    ):
      clipboard.delete_entries(db)
    with clipboard.database() as db:
      self.assertEqual(clipboard.snapshot(db)["total"], 0)

  def test_older_cutoff_keeps_selection_and_newer_entries_even_under_search(self):
    with clipboard.database() as db:
      self.add(db, b"hidden older entry")
      selected = self.add(db, b"selected")
      newer = self.add(db, b"newer")
    with (
      patch.object(clipboard.sys, "argv", ["ags-clipboard", "older", str(selected)]),
      patch.object(clipboard, "paste", return_value=None),
    ):
      clipboard.main()
    with clipboard.database() as db:
      self.assertEqual(
        [row["id"] for row in clipboard.snapshot(db)["entries"]],
        [newer, selected],
      )

  def test_store_fails_closed_when_mime_or_sensitive_state_is_missing(self):
    with (
      patch.dict(os.environ, {"CLIPBOARD_STATE": "", "CLIPBOARD_TYPE": ""}),
      patch.object(clipboard.sys, "argv", ["ags-clipboard", "store"]),
    ):
      clipboard.main()
    with clipboard.database() as db:
      self.assertEqual(clipboard.snapshot(db)["total"], 0)

  def test_private_storage_and_preview_display_isolation(self):
    with clipboard.database() as db:
      self.add(db)
    path = clipboard.directory()
    self.assertEqual(path.stat().st_mode & 0o777, 0o700)
    self.assertEqual((path / "history.sqlite").stat().st_mode & 0o777, 0o600)
    with patch.dict(os.environ, {"WAYLAND_DISPLAY": "another-display"}):
      self.assertNotEqual(clipboard.directory(), path)
      with clipboard.database() as db:
        self.assertEqual(clipboard.snapshot(db)["total"], 0)

  def image_bytes(self, size=(320, 180), format="PNG"):
    output = io.BytesIO()
    image = Image.new("RGB", size, (10, 80, 150))
    if format == "PNG":
      metadata = PngImagePlugin.PngInfo()
      metadata.add_text("Comment", "private image metadata")
      image.save(output, format=format, pnginfo=metadata)
    else:
      image.save(output, format=format)
    return output.getvalue()

  def test_raw_images_have_readable_names_dimensions_and_preserved_pixels(self):
    data = self.image_bytes(format="JPEG")
    with clipboard.database() as db:
      self.add(db, data, "image/jpeg")
      entry = clipboard.snapshot(db)["entries"][0]
      self.assertEqual(entry["preview"], "JPEG image · 320 × 180")
      self.assertEqual(entry["path"], "")
      row = db.execute("SELECT * FROM entries").fetchone()
    png = clipboard.render_preview(row)
    with Image.open(io.BytesIO(png)) as image:
      self.assertEqual(image.size, (64, 36))

  def test_saved_screenshot_name_survives_watcher_recapture_and_missing_file(self):
    path = str(Path(self.runtime.name) / "Screenshot #1 æøå.png")
    data = self.image_bytes()
    with clipboard.database() as db:
      self.add(db, data, "image/png", source_path=path)
      self.add(db, data, "image/png")
      entry = clipboard.snapshot(db, "screenshot #1")["entries"][0]
      self.assertEqual(entry["preview"], "Screenshot #1 æøå.png")
      self.assertEqual(entry["path"], path)
      row = db.execute("SELECT * FROM entries").fetchone()
    self.assertTrue(clipboard.render_preview(row).startswith(b"\x89PNG"))

  def test_thumbnail_strips_metadata_keeps_aspect_and_stays_bounded(self):
    data = self.image_bytes(size=(180, 320))
    png = clipboard.image_preview(io.BytesIO(data))
    self.assertLessEqual(len(png), clipboard.MAX_PREVIEW_BYTES)
    with Image.open(io.BytesIO(png)) as image:
      self.assertEqual(image.size, (27, 48))
      self.assertNotIn("Comment", image.info)

  def test_native_preview_worker_caches_only_small_png_in_history(self):
    with clipboard.database() as db:
      entry_id = self.add(db, self.image_bytes(), "image/png")
    preview = clipboard.preview_entry(entry_id)
    png = base64.b64decode(preview, validate=True)
    with Image.open(io.BytesIO(png)) as image:
      self.assertEqual(image.size, (64, 36))
    with clipboard.database() as db:
      self.assertEqual(db.execute("SELECT thumbnail FROM entries").fetchone()[0], png)
    with patch.object(clipboard.subprocess, "run") as run:
      self.assertEqual(clipboard.preview_entry(entry_id), preview)
      run.assert_not_called()

  def test_real_recording_reference_has_a_video_frame_thumbnail(self):
    path = Path(self.runtime.name) / "Recording #1.mp4"
    subprocess.run(
      [
        "ffmpeg",
        "-nostdin",
        "-v",
        "error",
        "-f",
        "lavfi",
        "-i",
        "color=c=blue:s=128x72:r=5",
        "-frames:v",
        "2",
        "-c:v",
        "mpeg4",
        "-threads",
        "1",
        str(path),
      ],
      check=True,
      stdout=subprocess.DEVNULL,
      stderr=subprocess.DEVNULL,
      timeout=5,
    )
    with clipboard.database() as db:
      self.add(db, (path.as_uri() + "\r\n").encode(), "text/uri-list")
      row = db.execute("SELECT * FROM entries").fetchone()
      entry = clipboard.snapshot(db)["entries"][0]
      self.assertEqual(entry["preview"], path.name)
      self.assertEqual(entry["path"], str(path))
      self.assertEqual(entry["kind"], "video")
    with Image.open(io.BytesIO(clipboard.render_preview(row))) as image:
      self.assertEqual(image.size, (64, 36))

  def test_copy_file_preserves_image_pasting_and_recording_uri_encoding(self):
    image = Path(self.runtime.name) / "Screen #1.png"
    data = self.image_bytes()
    image.write_bytes(data)
    with (
      patch.object(clipboard.subprocess, "run") as run,
      patch.object(clipboard, "paste", return_value=data),
    ):
      clipboard.copy_file(str(image))
      self.assertEqual(run.call_args.args[0], ["wl-copy", "--type", "image/png"])
    with clipboard.database() as db:
      self.assertEqual(clipboard.snapshot(db)["entries"][0]["path"], str(image))
    video = Path(self.runtime.name) / "Recording #1 æøå.mp4"
    video.write_bytes(b"recording")
    uri = (video.as_uri() + "\r\n").encode()
    with (
      patch.object(clipboard.subprocess, "run") as run,
      patch.object(clipboard, "paste", return_value=uri),
    ):
      clipboard.copy_file(str(video))
      self.assertEqual(run.call_args.args[0], ["wl-copy", "--type", "text/uri-list"])
      self.assertEqual(run.call_args.kwargs["input"], uri)
      self.assertIn(b"%23", uri)

  def test_missing_remote_and_unsupported_files_do_not_run_a_decoder(self):
    with clipboard.database() as db:
      for data in (
        b"https://example.invalid/image.png",
        b"file:///missing/movie.mp4",
        b"file:///tmp/document.txt",
      ):
        entry_id = self.add(db, data, "text/uri-list")
        row = db.execute("SELECT * FROM entries WHERE id = ?", (entry_id,)).fetchone()
        with patch.object(clipboard.subprocess, "run") as run:
          self.assertEqual(clipboard.render_preview(row), b"")
          run.assert_not_called()

  def test_deletion_during_thumbnail_render_does_not_reinsert_pixels(self):
    data = self.image_bytes()
    with clipboard.database() as db:
      entry_id = self.add(db, data, "image/png")

    def render_then_delete(*_args, **_kwargs):
      png = clipboard.image_preview(io.BytesIO(data))
      with clipboard.database() as db:
        db.execute("DELETE FROM entries WHERE id = ?", (entry_id,))
      return subprocess.CompletedProcess([], 0, stdout=png)

    with patch.object(clipboard.subprocess, "run", side_effect=render_then_delete):
      self.assertEqual(clipboard.preview_entry(entry_id), "")
    with clipboard.database() as db:
      self.assertEqual(clipboard.snapshot(db)["total"], 0)

  def test_thumbnail_timeouts_fall_back_without_repeating_decode(self):
    with clipboard.database() as db:
      entry_id = self.add(db, b"invalid image", "image/png")
    with patch.object(
      clipboard.subprocess,
      "run",
      side_effect=subprocess.TimeoutExpired("preview", 4),
    ) as run:
      self.assertEqual(clipboard.preview_entry(entry_id), "")
      self.assertEqual(clipboard.preview_entry(entry_id), "")
      self.assertEqual(run.call_count, 1)

  def test_legacy_runtime_database_migrates_without_losing_history(self):
    path = clipboard.directory() / "history.sqlite"
    with sqlite3.connect(path) as db:
      db.execute(
        "CREATE TABLE entries (id INTEGER PRIMARY KEY AUTOINCREMENT, created REAL, mime TEXT, digest TEXT UNIQUE, data BLOB)"
      )
      db.execute(
        "INSERT INTO entries (created, mime, digest, data) VALUES (?, ?, ?, ?)",
        (clipboard.time.time(), "text/plain", "hash", b"old entry"),
      )
    with clipboard.database() as db:
      self.assertEqual(clipboard.snapshot(db)["entries"][0]["preview"], "old entry")
      self.assertEqual(clipboard.snapshot(db)["entries"][0]["path"], "")

  def test_thumbnail_and_source_metadata_are_erased_with_the_entry(self):
    marker = b"cached-thumbnail-pixel-marker" * 30
    path_marker = "/Screenshots/private-filename-marker.png"
    with clipboard.database() as db:
      entry_id = self.add(db, self.image_bytes(), "image/png", source_path=path_marker)
      db.execute("UPDATE entries SET thumbnail = ? WHERE id = ?", (marker, entry_id))
    path = clipboard.directory() / "history.sqlite"
    self.assertIn(marker, path.read_bytes())
    with (
      clipboard.database() as db,
      patch.object(clipboard, "paste", return_value=None),
    ):
      clipboard.delete_entries(db, [entry_id])
    self.assertNotIn(marker, path.read_bytes())
    self.assertNotIn(path_marker.encode(), path.read_bytes())

  def test_screenshot_passes_its_saved_path_even_without_grimblast_stdout(self):
    scripts = Path(self.runtime.name) / "bin"
    scripts.mkdir()
    calls = Path(self.runtime.name) / "clipboard-calls"
    bash = shutil.which("bash")
    stubs = {
      "grimblast": 'for arg; do last="$arg"; done\nprintf image > "$last"\n',
      "ags-clipboard": 'printf "%s\\n" "$@" > "$CLIPBOARD_CALLS"\n',
      "notify-send": "exit 0\n",
    }
    for name, text in stubs.items():
      path = scripts / name
      path.write_text(f"#!{bash}\n" + text)
      path.chmod(0o700)
    home = Path(self.runtime.name) / "home directory"
    subprocess.run(
      [bash, "modules/desktop/hyprland/src/scripts/screenshot.sh", "area"],
      env={
        **os.environ,
        "HOME": str(home),
        "PATH": str(scripts) + os.pathsep + os.environ["PATH"],
        "CLIPBOARD_CALLS": str(calls),
      },
      check=True,
      stdout=subprocess.DEVNULL,
      stderr=subprocess.DEVNULL,
      timeout=3,
    )
    action, filename = calls.read_text().splitlines()
    self.assertEqual(action, "copy-file")
    self.assertEqual(Path(filename).parent, home / "Screenshots")
    self.assertTrue(Path(filename).name.startswith("Screenshot_"))
    self.assertTrue(Path(filename).is_file())


if __name__ == "__main__":
  unittest.main()
