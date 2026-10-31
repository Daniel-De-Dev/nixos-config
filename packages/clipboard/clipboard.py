"""Private, bounded clipboard storage. Only wl-clipboard touches Wayland.

Keep bytes and MIME types intact, never interpolate clipboard data into commands,
and keep history out of persistent caches. SQLite secure_delete overwrites freed
pages; the rollback journal stays in memory. This is not a forensic erase claim.
"""

import argparse
import base64
import fcntl
import hashlib
import io
import json
import mimetypes
import os
import signal
import sqlite3
import subprocess
import sys
import time
import unicodedata
import warnings
from contextlib import contextmanager
from pathlib import Path
from urllib.parse import unquote, urlsplit

from PIL import Image, ImageOps

MAX_ITEMS = 200
MAX_BYTES = 64 * 1024 * 1024
MAX_ITEM_BYTES = 5 * 1024 * 1024
MAX_AGE = 24 * 60 * 60
PREVIEW_SIZE = (64, 48)
MAX_PREVIEW_BYTES = 20 * 1024
FILE_TYPES = ("text/uri-list", "x-special/gnome-copied-files")
Image.MAX_IMAGE_PIXELS = 40_000_000


def directory():
  runtime = Path(os.environ["XDG_RUNTIME_DIR"])
  if not runtime.is_dir() or runtime.stat().st_uid != os.getuid():
    raise RuntimeError("No private session runtime directory")
  display = os.environ.get("WAYLAND_DISPLAY", "wayland-0")
  suffix = hashlib.sha256(display.encode()).hexdigest()[:16]
  path = runtime / f"ags-clipboard-{suffix}"
  path.mkdir(mode=0o700, exist_ok=True)
  if path.is_symlink() or path.stat().st_uid != os.getuid():
    raise RuntimeError("Unsafe clipboard directory")
  path.chmod(0o700)
  return path


@contextmanager
def database():
  os.umask(0o077)
  path = directory()
  # Also serialise mutations of the live clipboard with database writes.
  with (path / "lock").open("a") as lock:
    fcntl.flock(lock, fcntl.LOCK_EX)
    db = sqlite3.connect(path / "history.sqlite")
    db.row_factory = sqlite3.Row
    try:
      db.execute("PRAGMA secure_delete=ON")
      db.execute("PRAGMA journal_mode=MEMORY")
      db.executescript("""
                CREATE TABLE IF NOT EXISTS entries (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    created REAL NOT NULL,
                    mime TEXT NOT NULL,
                    digest TEXT UNIQUE NOT NULL,
                    data BLOB NOT NULL,
                    source_path TEXT NOT NULL DEFAULT '',
                    thumbnail BLOB
                );
                CREATE TABLE IF NOT EXISTS settings (
                    key TEXT PRIMARY KEY,
                    value INTEGER NOT NULL
                );
            """)
      columns = {row["name"] for row in db.execute("PRAGMA table_info(entries)")}
      if "source_path" not in columns:
        db.execute(
          "ALTER TABLE entries ADD COLUMN source_path TEXT NOT NULL DEFAULT ''"
        )
      if "thumbnail" not in columns:
        db.execute("ALTER TABLE entries ADD COLUMN thumbnail BLOB")
      yield db
      db.commit()
    finally:
      db.close()


def prune(db):
  db.execute("DELETE FROM entries WHERE created < ?", (time.time() - MAX_AGE,))
  rows = db.execute(
    "SELECT id, length(data) + coalesce(length(thumbnail), 0) AS size FROM entries ORDER BY id DESC"
  )
  used = 0
  for index, row in enumerate(rows.fetchall()):
    used += row["size"]
    if index >= MAX_ITEMS or used > MAX_BYTES:
      db.execute("DELETE FROM entries WHERE id <= ?", (row["id"],))
      break


def paused(db):
  row = db.execute("SELECT value FROM settings WHERE key = 'paused'").fetchone()
  return bool(row and row[0])


def paste(*args):
  # Failures and clipboard payloads are never written to the journal.
  result = subprocess.run(
    ["wl-paste", "--no-newline", *args], check=False, capture_output=True, timeout=3
  )
  return result.stdout if result.returncode == 0 else None


def store(db, data, mime, state, source_path=""):
  if paused(db) or state != "data" or not data or len(data) > MAX_ITEM_BYTES:
    return
  if not mime or any(c in mime for c in "\r\n\0"):
    return
  digest = hashlib.sha256(data).hexdigest()
  previous = db.execute(
    "SELECT mime, source_path, thumbnail FROM entries WHERE digest = ?", (digest,)
  ).fetchone()
  # A file copy may also offer identical plain text. Retain the file MIME.
  if previous and previous["mime"] in FILE_TYPES:
    mime = previous["mime"]
  if previous and not source_path:
    source_path = previous["source_path"]
  thumbnail = previous["thumbnail"] if previous and mime.startswith("image/") else None
  db.execute("DELETE FROM entries WHERE digest = ?", (digest,))
  db.execute(
    "INSERT INTO entries (created, mime, digest, data, source_path, thumbnail) VALUES (?, ?, ?, ?, ?, ?)",
    (time.time(), mime, digest, data, source_path, thumbnail),
  )
  prune(db)


def paths_for(row):
  if row["source_path"]:
    return [row["source_path"]]
  if row["mime"] not in FILE_TYPES:
    return []
  paths = []
  for line in row["data"].decode("utf-8", errors="replace").splitlines():
    if not line or line.startswith("#") or line in ("copy", "cut"):
      continue
    try:
      uri = urlsplit(line)
    except ValueError:
      paths.append(line)
      continue
    if uri.scheme == "file" and uri.netloc in ("", "localhost"):
      paths.append(unquote(uri.path))
    else:
      paths.append(line)
  return paths


def media_kind(mime):
  for kind in ("image", "video", "audio"):
    if mime.startswith(kind + "/"):
      return kind
  return "files"


def image_label(data, mime):
  fallback = {"image/jpeg": "JPEG", "image/jpg": "JPEG"}.get(
    mime, mime.split("/")[-1].upper()
  )
  try:
    with warnings.catch_warnings():
      warnings.simplefilter("error", Image.DecompressionBombWarning)
      with Image.open(io.BytesIO(data)) as image:
        return f"{image.format or fallback} image · {image.width} × {image.height}"
  except (
    OSError,
    ValueError,
    Image.DecompressionBombError,
    Image.DecompressionBombWarning,
  ):
    return f"{fallback} image"


def describe(row):
  mime, data = row["mime"], row["data"]
  paths = paths_for(row)
  if paths:
    path = " · ".join(paths)
    name = Path(paths[0]).name or paths[0]
    if len(paths) > 1:
      name += f" (+{len(paths) - 1} files)"
    content_type = mimetypes.guess_type(paths[0])[0] or "application/octet-stream"
    kind = media_kind(content_type) if len(paths) == 1 else "files"
    return (
      kind,
      " ".join(name.split())[:240],
      name + " " + path + " " + content_type,
      path,
    )
  if mime.startswith("image/"):
    text, kind = image_label(data, mime), "image"
  elif mime.startswith("text/"):
    text, kind = data.decode("utf-8", errors="replace"), "text"
  else:
    kind = media_kind(mime)
    text = "Video" if kind == "video" else "Audio" if kind == "audio" else "Media"
    kind = kind if kind in ("video", "audio") else "media"
  preview = " ".join(text.split())[:240]
  return kind, preview or "Whitespace", text, ""


def image_preview(source):
  # Decode in the separate, time-limited render-preview process, never in GTK.
  with warnings.catch_warnings():
    warnings.simplefilter("error", Image.DecompressionBombWarning)
    with Image.open(source) as image:
      image.thumbnail((64, 64), Image.Resampling.LANCZOS)
      image = ImageOps.exif_transpose(image).convert("RGBA")
      image.thumbnail(PREVIEW_SIZE, Image.Resampling.LANCZOS)
      image.info.clear()
      output = io.BytesIO()
      image.save(output, format="PNG")
      png = output.getvalue()
      return png if len(png) <= MAX_PREVIEW_BYTES else b""


def render_preview(row):
  if row["mime"].startswith("image/"):
    return image_preview(io.BytesIO(row["data"]))
  paths = paths_for(row)
  if not paths:
    return b""
  path = Path(paths[0])
  # A copied remote URI is only a label. Do not fetch it for a thumbnail.
  if not path.is_absolute() or not path.is_file():
    return b""
  kind = media_kind(mimetypes.guess_type(str(path))[0] or "")
  if kind == "image":
    return image_preview(path)
  if kind == "video":
    result = subprocess.run(
      [
        "ffmpeg",
        "-nostdin",
        "-v",
        "error",
        "-threads",
        "1",
        "-filter_threads",
        "1",
        "-protocol_whitelist",
        "file,pipe",
        "-i",
        str(path),
        "-an",
        "-sn",
        "-frames:v",
        "1",
        "-vf",
        "scale=64:48:force_original_aspect_ratio=decrease",
        "-f",
        "image2pipe",
        "-c:v",
        "png",
        "pipe:1",
      ],
      check=False,
      capture_output=True,
      timeout=3,
    )
    if result.returncode == 0 and len(result.stdout) <= MAX_PREVIEW_BYTES:
      return image_preview(io.BytesIO(result.stdout))
  return b""


def preview_entry(entry_id):
  with database() as db:
    prune(db)
    row = db.execute("SELECT * FROM entries WHERE id = ?", (entry_id,)).fetchone()
    if row is None:
      return ""
    thumbnail = row["thumbnail"]
  if thumbnail is None:
    try:
      result = subprocess.run(
        [
          sys.executable,
          str(Path(__file__).resolve()),
          "render-preview",
          str(entry_id),
        ],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        timeout=4,
      )
      thumbnail = result.stdout if result.returncode == 0 else b""
      if (
        not thumbnail.startswith(b"\x89PNG\r\n\x1a\n")
        or len(thumbnail) > MAX_PREVIEW_BYTES
      ):
        thumbnail = b""
    except (OSError, subprocess.SubprocessError):
      thumbnail = b""
    with database() as db:
      prune(db)
      db.execute("UPDATE entries SET thumbnail = ? WHERE id = ?", (thumbnail, entry_id))
      prune(db)
  with database() as db:
    row = db.execute(
      "SELECT thumbnail FROM entries WHERE id = ?", (entry_id,)
    ).fetchone()
    # A deletion during decoding must not put thumbnail bytes back into the UI.
    return base64.b64encode(row[0] or b"").decode() if row else ""


def normalize_search(text):
  return "".join(
    character
    for character in unicodedata.normalize("NFKD", text)
    if not unicodedata.category(character).startswith("M")
  ).lower()


def utf16_length(text):
  # Match JavaScript's string indices when filenames contain non-BMP characters.
  return len(text.encode("utf-16-le", errors="surrogatepass")) // 2


def token_score(text, token):
  if text == token:
    return 0
  length = utf16_length(text)
  contiguous = text.find(token)
  if contiguous >= 0:
    return 1 + utf16_length(text[:contiguous]) / (length + 1)
  cursor, first, last = 0, -1, -1
  for character in token:
    position = text.find(character, cursor)
    if position < 0:
      return None
    offset = utf16_length(text[:position])
    if first < 0:
      first = offset
    last = offset
    cursor = position + len(character)
  gaps = last - first + 1 - utf16_length(token)
  return 2 + (gaps + first / (length + 1)) / (length + 1)


def fuzzy_rank(items, query, text_of):
  # Same policy as AGS lib/search.ts; both run tests/search-cases.json.
  tokens = normalize_search(query).split()
  if not tokens:
    return list(items)
  matches = []
  for index, item in enumerate(items):
    text = normalize_search(text_of(item))
    score = 0
    for token in tokens:
      value = token_score(text, token)
      if value is None:
        break
      score += value
    else:
      matches.append((score, index, item))
  return [item for _score, _index, item in sorted(matches, key=lambda match: match[:2])]


def snapshot(db, query=""):
  candidates = []
  rows = db.execute("SELECT * FROM entries ORDER BY id DESC").fetchall()
  for row in rows:
    kind, preview, text, path = describe(row)
    candidates.append(
      (
        {
          "id": row["id"],
          "created": row["created"],
          "mime": row["mime"],
          "size": len(row["data"]),
          "kind": kind,
          "preview": preview,
          "path": path,
        },
        text + " " + row["mime"],
      )
    )
  # Only preview metadata crosses the process boundary, including for matches
  # found beyond the visible text prefix.
  entries = [
    entry for entry, _text in fuzzy_rank(candidates, query, lambda item: item[1])
  ]
  with (directory() / "watch.lock").open("a") as lock:
    try:
      fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
      watching = False
    except BlockingIOError:
      watching = True
  return {
    "paused": paused(db),
    "watching": watching,
    "total": len(rows),
    "entries": entries,
  }


def clear_selection(primary=False):
  subprocess.run(
    ["wl-copy", "--clear", *(["--primary"] if primary else [])],
    check=True,
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL,
    timeout=3,
  )


def delete_entries(db, ids=None):
  if ids is None:
    db.execute("DELETE FROM entries")
    db.commit()
    # Wipe both selections, even if their contents were never recorded.
    failed = False
    for primary in (False, True):
      try:
        clear_selection(primary=primary)
      except (OSError, subprocess.SubprocessError):
        failed = True
    # The previous desktop service used cliphist's persistent default cache.
    # Do not import it, but make the explicit Clear all action wipe it too.
    cache = Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache")))
    legacy = cache / "cliphist" / "db"
    if legacy.exists():
      try:
        subprocess.run(
          [
            "cliphist",
            "-config-path",
            "/dev/null",
            "-db-path",
            str(legacy),
            "wipe",
          ],
          check=True,
          stdout=subprocess.DEVNULL,
          stderr=subprocess.DEVNULL,
          timeout=3,
          env={
            key: value
            for key, value in os.environ.items()
            if not key.startswith("CLIPHIST_")
          },
        )
      except (OSError, subprocess.SubprocessError):
        failed = True
    if failed:
      raise RuntimeError(
        "History removed, but a clipboard or legacy cache could not be cleared"
      )
    return
  if not ids:
    return
  placeholders = ",".join("?" for _ in ids)
  removed = db.execute(
    f"SELECT mime, data FROM entries WHERE id IN ({placeholders})", ids
  ).fetchall()
  db.execute(f"DELETE FROM entries WHERE id IN ({placeholders})", ids)
  db.commit()
  failed = False
  for primary in (False, True):
    try:
      selection = ["--primary"] if primary else []
      types = paste("--list-types", *selection)
      offered = set(types.decode().splitlines()) if types else set()
      for mime in {row["mime"] for row in removed} & offered:
        current = paste("--type", mime, *selection)
        if any(row["data"] == current for row in removed):
          clear_selection(primary=primary)
          break
    except (OSError, subprocess.SubprocessError):
      failed = True
  if failed:
    raise RuntimeError("History removed, but a matching clipboard could not be cleared")


def copy_entry(db, entry_id):
  row = db.execute("SELECT * FROM entries WHERE id = ?", (entry_id,)).fetchone()
  if row is None:
    raise RuntimeError("Entry expired or was deleted")
  subprocess.run(
    ["wl-copy", "--type", row["mime"]],
    input=row["data"],
    check=True,
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL,
    timeout=3,
  )


def copy_file(filename):
  path = Path(filename).expanduser().resolve(strict=True)
  if not path.is_file():
    raise RuntimeError("Not a regular file")
  mime = mimetypes.guess_type(str(path))[0] or "application/octet-stream"
  if mime.startswith("image/"):
    with path.open("rb") as source:
      data = source.read(MAX_ITEM_BYTES + 1)
      source.seek(0)
      subprocess.run(
        ["wl-copy", "--type", mime],
        stdin=source,
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        timeout=3,
      )
  else:
    data = (path.as_uri() + "\r\n").encode()
    mime = "text/uri-list"
    subprocess.run(
      ["wl-copy", "--type", mime],
      input=data,
      check=True,
      stdout=subprocess.DEVNULL,
      stderr=subprocess.DEVNULL,
      timeout=3,
    )
  if len(data) <= MAX_ITEM_BYTES:
    with database() as db:
      if not paused(db) and paste("--type", mime) == data:
        store(db, data, mime, "data", source_path=str(path))


def watch():
  # One supervisor owns all watchers and expires entries even with the UI closed.
  # Extra watchers retain image/URI offers when an application also offers text.
  with (directory() / "watch.lock").open("a") as lock:
    try:
      fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
      raise RuntimeError("Clipboard watcher is already running") from None
    children = []

    def stop(_signum, _frame):
      raise SystemExit(0)

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    try:
      for mime in (None, "image", "text/uri-list"):
        command = ["wl-paste", "--no-newline"]
        if mime:
          command += ["--type", mime]
        command += [
          "--watch",
          sys.executable,
          str(Path(__file__).resolve()),
          "store",
        ]
        children.append(subprocess.Popen(command))
      while all(child.poll() is None for child in children):
        with database() as db:
          prune(db)
        time.sleep(30)
      raise RuntimeError("Clipboard watcher stopped")
    finally:
      for child in children:
        if child.poll() is None:
          child.terminate()
      for child in children:
        try:
          child.wait(timeout=3)
        except subprocess.TimeoutExpired:
          child.kill()
          child.wait()


def main():
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument(
    "action",
    choices=(
      "watch",
      "store",
      "list",
      "copy",
      "copy-file",
      "preview",
      "render-preview",
      "delete",
      "older",
      "clear",
      "pause",
    ),
  )
  parser.add_argument("argument", nargs="?", default="")
  args = parser.parse_args()
  os.umask(0o077)
  if args.action == "watch":
    watch()
    return
  if args.action == "copy-file":
    copy_file(args.argument)
    return
  if args.action == "preview":
    print(preview_entry(int(args.argument)))
    return
  if args.action == "render-preview":
    with database() as db:
      prune(db)
      row = db.execute(
        "SELECT * FROM entries WHERE id = ?", (int(args.argument),)
      ).fetchone()
    if row is not None:
      sys.stdout.buffer.write(render_preview(row))
    return
  if args.action == "store":
    state = os.environ.get("CLIPBOARD_STATE", "")
    if state != "data":
      return
    mime = os.environ.get("CLIPBOARD_TYPE", "")
    data = sys.stdin.buffer.read(MAX_ITEM_BYTES + 1)
    if len(data) > MAX_ITEM_BYTES:
      return
    with database() as db:
      # A capture queued before a deletion must not reinsert the old data.
      if not paused(db) and data and paste("--type", mime) == data:
        store(db, data, mime, state)
    return
  with database() as db:
    prune(db)
    if args.action == "list":
      print(json.dumps(snapshot(db, args.argument)))
    elif args.action == "copy":
      copy_entry(db, int(args.argument))
    elif args.action in ("delete", "older"):
      entry_id = int(args.argument)
      exists = db.execute("SELECT 1 FROM entries WHERE id = ?", (entry_id,)).fetchone()
      if exists is None:
        raise RuntimeError("Entry expired or was deleted")
      ids = (
        [entry_id]
        if args.action == "delete"
        else [
          row[0]
          for row in db.execute("SELECT id FROM entries WHERE id < ?", (entry_id,))
        ]
      )
      delete_entries(db, ids)
    elif args.action == "clear":
      delete_entries(db)
    elif args.action == "pause":
      db.execute(
        "INSERT OR REPLACE INTO settings (key, value) VALUES ('paused', ?)",
        (not paused(db),),
      )


if __name__ == "__main__":
  try:
    main()
  except (
    KeyError,
    OSError,
    RuntimeError,
    ValueError,
    sqlite3.Error,
    subprocess.SubprocessError,
    Image.DecompressionBombError,
    Image.DecompressionBombWarning,
  ):
    print(
      "Clipboard action failed; check the graphical session and try again.",
      file=sys.stderr,
    )
    sys.exit(1)
