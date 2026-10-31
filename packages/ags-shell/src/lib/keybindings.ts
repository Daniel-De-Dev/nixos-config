export type Keybinding = {
  description: string;
  shortcut: string;
  context: string;
  action?: { id: number; description: string };
};

type RawBinding = {
  description?: string;
  dispatcher?: string;
  arg?: string;
  key?: string;
  keycode?: number;
  modmask?: number;
  submap?: string;
  release?: boolean;
  repeat?: boolean;
  mouse?: boolean;
  longPress?: boolean;
  catch_all?: boolean;
};

const bindingFields: Record<keyof RawBinding, "string" | "number" | "boolean"> =
  {
    description: "string",
    dispatcher: "string",
    arg: "string",
    key: "string",
    keycode: "number",
    modmask: "number",
    submap: "string",
    release: "boolean",
    repeat: "boolean",
    mouse: "boolean",
    longPress: "boolean",
    catch_all: "boolean",
  };

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function isRawBinding(value: unknown): value is RawBinding {
  return (
    isRecord(value) &&
    Object.entries(bindingFields).every(
      ([key, type]) => !(key in value) || typeof value[key] === type,
    )
  );
}

const modifiers: [number, string][] = [
  [64, "SUPER"],
  [4, "CTRL"],
  [8, "ALT"],
  [1, "SHIFT"],
  [2, "CAPS"],
  [16, "MOD2"],
  [32, "MOD3"],
  [128, "MOD5"],
];

function shortcutOf(binding: RawBinding): string {
  const keys = modifiers
    .filter(([mask]) => (Number(binding.modmask) & mask) !== 0)
    .map(([, name]) => name);
  const key =
    binding.key || (binding.keycode ? `code:${String(binding.keycode)}` : "");
  keys.push(binding.catch_all ? "catchall" : key || "(unreported key)");
  return keys.join(" + ");
}

export function parseActionIds(response: string): number[] {
  const ids: unknown = JSON.parse(response);
  if (
    !Array.isArray(ids) ||
    !ids.every(
      (id: unknown): id is number =>
        typeof id === "number" && Number.isSafeInteger(id) && id > 0,
    )
  )
    throw new Error("Expected a shortcut action ID array");
  return ids;
}

// Lua accepts decimal byte escapes, rather than JSON's Unicode escape syntax.
function luaString(text: string): string {
  const escaped = Array.from(text, (character) => {
    const code = character.charCodeAt(0);
    return code < 32 || code === 127 || character === '"' || character === "\\"
      ? `\\${code.toString().padStart(3, "0")}`
      : character;
  }).join("");
  return `"${escaped}"`;
}

export function activationRequest(binding: Keybinding): string | null {
  if (!binding.action) return null;
  const { id, description } = binding.action;
  if (!Number.isSafeInteger(id) || id <= 0) return null;
  return `eval nixos_shortcuts.run(${String(id)}, ${luaString(description)})`;
}

export function parseKeybindings(
  response: string,
  actionIds: readonly number[] = [],
): Keybinding[] {
  const bindings: unknown = JSON.parse(response);
  if (!Array.isArray(bindings))
    throw new Error("Expected a Hyprland bindings array");

  return bindings
    .map((value: unknown) => {
      if (!isRawBinding(value)) {
        throw new Error("Invalid Hyprland binding");
      }
      const binding = value;
      const nativeDescription =
        typeof binding.description === "string" ? binding.description : "";
      const text = nativeDescription.trim();
      // Local declarations append their original key specification in brackets.
      const described = /^(.*) \[([^\]]+)\]$/s.exec(text);
      const description =
        described?.[1] ||
        text ||
        (binding.dispatcher === "__lua"
          ? "Undescribed Lua binding"
          : binding.dispatcher) ||
        "Undescribed binding";
      const context = [
        binding.submap ? `Submap: ${binding.submap}` : "",
        binding.release === true ? "on release" : "",
        binding.repeat === true ? "repeat" : "",
        binding.longPress === true ? "long press" : "",
        binding.mouse === true ? "mouse" : "",
      ]
        .filter(Boolean)
        .join(" · ");

      const id = Number(binding.arg);
      const canRun =
        binding.dispatcher === "__lua" &&
        actionIds.includes(id) &&
        !binding.submap &&
        !binding.mouse &&
        !binding.release &&
        !binding.longPress &&
        !binding.catch_all;

      return {
        description,
        shortcut: described?.[2] || shortcutOf(binding),
        context,
        ...(canRun ? { action: { id, description: nativeDescription } } : {}),
      };
    })
    .sort(
      (a, b) =>
        a.description.localeCompare(b.description) ||
        a.shortcut.localeCompare(b.shortcut),
    );
}
