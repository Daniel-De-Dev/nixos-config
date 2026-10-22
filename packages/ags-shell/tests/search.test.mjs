import assert from "node:assert/strict";
import { test } from "node:test";
import { fuzzyRank } from "../src/lib/search.ts";

const rank = (items, query) => fuzzyRank(items, query, (item) => item);

test("empty queries retain source order without changing the input", () => {
  const items = ["Brave", "Ghostty", "Neovim"];
  assert.deepEqual(rank(items, " \t "), items);
  assert.notEqual(rank(items, ""), items);
});

test("ordered subsequences match and missing or reversed characters do not", () => {
  assert.deepEqual(rank(["Brave", "browser", "Ghostty"], "brv"), ["Brave"]);
  assert.deepEqual(rank(["Brave"], "vrb"), []);
  assert.deepEqual(rank(["Brave"], "brvv"), []);
});

test("exact and contiguous matches precede scattered matches", () => {
  assert.deepEqual(rank(["b r a v e", "Open Brave", "Brave"], "brave"), [
    "Brave", "Open Brave", "b r a v e",
  ]);
});

test("case and accents are ignored", () => {
  assert.deepEqual(rank(["Résumé — Éditeur"], "RESUME edtr"), ["Résumé — Éditeur"]);
});

test("all words must match, including words from different window fields", () => {
  const windows = [
    { title: "NixOS manual", class: "Brave" },
    { title: "NixOS terminal", class: "Ghostty" },
  ];
  const text = (window) => `${window.title} ${window.class}`;
  assert.deepEqual(fuzzyRank(windows, "brv nix", text), [windows[0]]);
  assert.deepEqual(fuzzyRank(windows, "brv missing", text), []);
});

test("equal scores keep source order and punctuation is literal", () => {
  assert.deepEqual(rank(["ab first", "ab second"], "ab"), ["ab first", "ab second"]);
  assert.deepEqual(rank(["C++", "C language"], "c++"), ["C++"]);
  assert.deepEqual(rank([], "anything"), []);
});
