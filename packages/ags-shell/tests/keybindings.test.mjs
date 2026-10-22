import assert from "node:assert/strict";
import { test } from "node:test";
import { activationRequest, parseActionIds, parseKeybindings } from "../src/lib/keybindings.ts";
import { fuzzyRank } from "../src/lib/search.ts";

const parse = (bindings) => parseKeybindings(JSON.stringify(bindings));

test("descriptions retain full Lua keycode and chord specifications", () => {
  const rows = parse([
    { description: "Open workspace 1 [SUPER + code:10]", key: "", keycode: 0, modmask: 64 },
    { description: "Search shortcuts [SUPER + S + K]", key: "K", modmask: 64 },
  ]);
  assert.equal(rows[0].description, "Open workspace 1");
  assert.equal(rows[0].shortcut, "SUPER + code:10");
  assert.equal(rows[1].shortcut, "SUPER + S + K");
});

test("external descriptions use native modifier and key fields", () => {
  assert.deepEqual(parse([{ description: "Take screenshot", key: "Print", modmask: 69 }]), [
    { description: "Take screenshot", shortcut: "SUPER + CTRL + SHIFT + Print", context: "" },
  ]);
  assert.equal(parse([{ keycode: 24, modmask: 8 }])[0].shortcut, "ALT + code:24");
  assert.equal(parse([{ catch_all: true }])[0].shortcut, "catchall");
});

test("missing Lua key fields are reported without guessing a shortcut", () => {
  const [row] = parse([{ dispatcher: "__lua", modmask: 64, key: "", keycode: 0 }]);
  assert.equal(row.description, "Undescribed Lua binding");
  assert.equal(row.shortcut, "SUPER + (unreported key)");
});

test("submaps and input flags remain visible", () => {
  const [row] = parse([{ description: "Resize", key: "R", submap: "resize",
    release: true, repeat: true, longPress: true, mouse: true }]);
  assert.equal(row.context, "Submap: resize · on release · repeat · long press · mouse");
});

test("search can combine fuzzy description, shortcut and submap words", () => {
  const rows = parse([{ description: "Resize window [SUPER + R]", submap: "resize" },
    { description: "Open browser [SUPER + B]" }]);
  const text = (row) => `${row.description} ${row.shortcut} ${row.context}`;
  assert.deepEqual(fuzzyRank(rows, "rsz super", text), [rows[1]]);
});

test("invalid IPC responses fail and empty configurations are valid", () => {
  assert.throws(() => parseKeybindings("not JSON"));
  assert.throws(() => parseKeybindings("{}"));
  assert.throws(() => parse([null]));
  assert.deepEqual(parse([]), []);
});

test("only actions advertised by the compositor can run", () => {
  const raw = JSON.stringify([
    { description: "Open terminal [SUPER + Return]", dispatcher: "__lua", arg: "12" },
    { description: "External action", dispatcher: "__lua", arg: "13" },
    { description: "Legacy action", dispatcher: "exec", arg: "12" },
  ]);
  const rows = parseKeybindings(raw, parseActionIds("[12]"));
  const terminal = rows.find((row) => row.description === "Open terminal");
  assert.deepEqual(terminal.action, { id: 12, description: "Open terminal [SUPER + Return]" });
  assert.equal(activationRequest(terminal), 'eval nixos_shortcuts.run(12, "Open terminal [SUPER + Return]")');
  assert.equal(rows.filter((row) => row.action).length, 1);
  assert.equal(activationRequest(rows.find((row) => row.description === "External action")), null);
});

test("input-dependent bindings cannot run even if an ID is advertised", () => {
  for (const flags of [
    { mouse: true }, { release: true }, { longPress: true },
    { catch_all: true }, { submap: "resize" },
  ]) {
    const [row] = parseKeybindings(JSON.stringify([
      { dispatcher: "__lua", arg: "12", ...flags },
    ]), [12]);
    assert.equal(activationRequest(row), null);
  }
  const [repeat] = parseKeybindings(JSON.stringify([
    { description: "Volume up", dispatcher: "__lua", arg: "12", repeat: true },
  ]), [12]);
  assert.ok(activationRequest(repeat));
  assert.equal(repeat.context, "repeat");
});

test("callback IDs are validated before generating Lua", () => {
  assert.deepEqual(parseActionIds("[]"), []);
  for (const value of ["{}", "null", "[0]", "[-1]", '["12"]', "[1.5]", "[9007199254740992]"]) {
    assert.throws(() => parseActionIds(value));
  }
  const row = { description: "", shortcut: "", context: "", action: { id: 0, description: "" } };
  assert.equal(activationRequest(row), null);
});

test("descriptions stay literal in Lua, including quotes, Unicode and control bytes", () => {
  const row = {
    description: "", shortcut: "", context: "",
    action: { id: 12, description: '"\\\n\u0000\u007f9 café 雪' },
  };
  assert.equal(activationRequest(row), 'eval nixos_shortcuts.run(12, "\\034\\092\\010\\000\\1279 café 雪")');
});
