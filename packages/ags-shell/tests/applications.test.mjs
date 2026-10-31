import assert from "node:assert/strict";
import { test } from "node:test";
import { indexApplications } from "../src/lib/applications.ts";
import { fuzzyRank } from "../src/lib/search.ts";

function info({
  id,
  name,
  displayName = name,
  description = null,
  executable = null,
  visible = true,
}) {
  return {
    get_id: () => id,
    get_name: () => name,
    get_display_name: () => displayName,
    get_description: () => description,
    get_executable: () => executable,
    should_show: () => visible,
  };
}

test("menu entries are filtered, sorted, and retain their native launch object", () => {
  const browser = info({ id: "brave.desktop", name: "Brave" });
  const hidden = info({ id: "helper.desktop", name: "Helper", visible: false });
  const terminal = info({ id: "ghostty.desktop", name: "Ghostty" });
  const input = [terminal, hidden, browser];
  const result = indexApplications(input);
  assert.deepEqual(
    result.map((app) => app.name),
    ["Brave", "Ghostty"],
  );
  assert.equal(result[0].info, browser);
  assert.deepEqual(input, [terminal, hidden, browser]);
});

test("fuzzy queries can span display name, description, executable, and desktop ID", () => {
  const apps = indexApplications([
    info({
      id: "com.mitchellh.ghostty.desktop",
      name: "Ghostty",
      displayName: "Terminal",
      description: "A fast terminal emulator",
      executable: "ghostty",
    }),
    info({
      id: "brave.desktop",
      name: "Brave",
      description: "Browse the web",
      executable: "brave",
    }),
  ]);
  for (const query of ["ghst", "trm fast", "mitchellh", "ghostty.desktop"]) {
    const result = fuzzyRank(apps, query, (app) => app.searchText);
    assert.equal(result[0]?.id, "com.mitchellh.ghostty.desktop", query);
  }
  assert.equal(
    fuzzyRank(apps, "application that does not exist", (app) => app.searchText)
      .length,
    0,
  );
});

test("entries with the same display name keep distinct identities and deterministic order", () => {
  const apps = indexApplications([
    info({ id: "editor-z.desktop", name: "Editor", executable: "editor-z" }),
    info({ id: "editor-a.desktop", name: "Editor", executable: "editor-a" }),
  ]);
  assert.deepEqual(
    apps.map((app) => app.id),
    ["editor-a.desktop", "editor-z.desktop"],
  );
});

test("missing optional metadata has readable fallbacks", () => {
  const [app] = indexApplications([
    info({
      id: null,
      name: "Calculator",
      displayName: "",
      executable: "calculator",
    }),
  ]);
  assert.equal(app.name, "Calculator");
  assert.equal(app.description, "calculator");
  assert.equal(app.id, "");
  assert.equal(indexApplications([]).length, 0);
});
