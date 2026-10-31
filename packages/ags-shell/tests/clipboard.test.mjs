import assert from "node:assert/strict";
import { test } from "node:test";
import {
  parseClipboard,
  clipboardDescription,
  selectionAfterRemoval,
} from "../src/lib/clipboard.ts";

const entry = {
  id: 42,
  created: 60,
  size: 1200,
  mime: "image/png",
  kind: "image",
  preview: "image/png",
  path: "",
};

test("clipboard metadata validates across the helper boundary", () => {
  const state = { paused: true, watching: true, total: 1, entries: [entry] };
  assert.deepEqual(parseClipboard(JSON.stringify(state)), state);
  for (const invalid of [
    null,
    {},
    { ...state, paused: "true" },
    { ...state, total: 0 },
    { ...state, entries: [{ ...entry, id: -1 }] },
    { ...state, entries: [{ ...entry, kind: "__proto__" }] },
    { ...state, entries: [{ ...entry, size: "1200" }] },
    { ...state, entries: [{ ...entry, path: 42 }] },
  ])
    assert.throws(() => parseClipboard(JSON.stringify(invalid)));
});

test("image and recording filenames and paths survive metadata validation", () => {
  for (const kind of ["image", "video", "audio", "files"]) {
    const file = {
      ...entry,
      kind,
      preview: "Recording #1.mp4",
      path: "/home/user/Videos/Recording #1.mp4",
    };
    assert.deepEqual(
      parseClipboard(
        JSON.stringify({
          paused: false,
          watching: true,
          total: 1,
          entries: [file],
        }),
      ).entries[0],
      file,
    );
  }
});

test("clipboard metadata describes media, size, and age without reading a file", () => {
  assert.equal(
    clipboardDescription(entry, 180),
    "Image · 1.2 kB · 2 min ago · image/png",
  );
  assert.match(
    clipboardDescription({ ...entry, kind: "files" }, 4000),
    /Files.*1 h ago/,
  );
});

test("deletion selects the next displayed row, then the previous row", () => {
  assert.equal(selectionAfterRemoval([30, 20, 10], [20, 10], 30), 20);
  assert.equal(selectionAfterRemoval([30, 20, 10], [30, 10], 20), 10);
  assert.equal(selectionAfterRemoval([30, 20, 10], [30, 20], 10), 20);
  assert.equal(selectionAfterRemoval([10], [], 10), 0);
  // A failed deletion must keep the existing selection.
  assert.equal(selectionAfterRemoval([30, 20, 10], [30, 20, 10], 20), 20);
});

test("deletion follows filtered display order and tolerates concurrent history changes", () => {
  // Search relevance need not match creation order.
  assert.equal(selectionAfterRemoval([10, 30, 20], [10, 20], 30), 20);
  // A newly copied entry must not steal focus from an existing neighbour.
  assert.equal(selectionAfterRemoval([30, 20, 10], [40, 30, 10], 20), 10);
  assert.equal(selectionAfterRemoval([40, 30, 20, 10], [40, 10], 30), 10);
  assert.equal(selectionAfterRemoval([40, 30, 20, 10], [40], 20), 40);
  assert.equal(selectionAfterRemoval([30, 20], [40], 20), 40);
});
