export type ClipboardEntry = {
  id: number;
  created: number;
  mime: string;
  size: number;
  kind: "text" | "image" | "video" | "audio" | "files" | "media";
  preview: string;
  path: string;
};

export type ClipboardSnapshot = {
  paused: boolean;
  watching: boolean;
  total: number;
  entries: ClipboardEntry[];
};

function record(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function entry(value: unknown): value is ClipboardEntry {
  if (!record(value)) return false;
  return (
    typeof value["id"] === "number" &&
    Number.isSafeInteger(value["id"]) &&
    value["id"] > 0 &&
    typeof value["created"] === "number" &&
    Number.isFinite(value["created"]) &&
    typeof value["mime"] === "string" &&
    typeof value["size"] === "number" &&
    Number.isSafeInteger(value["size"]) &&
    value["size"] >= 0 &&
    ["text", "image", "video", "audio", "files", "media"].includes(
      String(value["kind"]),
    ) &&
    typeof value["preview"] === "string" &&
    typeof value["path"] === "string"
  );
}

export function parseClipboard(output: string): ClipboardSnapshot {
  const value: unknown = JSON.parse(output);
  if (
    !record(value) ||
    typeof value["paused"] !== "boolean" ||
    typeof value["watching"] !== "boolean" ||
    typeof value["total"] !== "number" ||
    !Number.isSafeInteger(value["total"]) ||
    value["total"] < 0 ||
    !Array.isArray(value["entries"]) ||
    !value["entries"].every(entry) ||
    value["entries"].length > value["total"]
  ) {
    throw new Error("Invalid clipboard response");
  }
  return {
    paused: value["paused"],
    watching: value["watching"],
    total: value["total"],
    entries: value["entries"],
  };
}

export function selectionAfterRemoval(
  previousIds: readonly number[],
  remainingIds: readonly number[],
  selectedId: number,
): number {
  const remaining = new Set(remainingIds);
  if (remaining.has(selectedId)) return selectedId;
  const index = previousIds.indexOf(selectedId);
  if (index >= 0) {
    // Follow the displayed order, including relevance-ranked search results.
    for (const id of previousIds.slice(index + 1)) {
      if (remaining.has(id)) return id;
    }
    for (let i = index - 1; i >= 0; i--) {
      const id = previousIds[i];
      if (id !== undefined && remaining.has(id)) return id;
    }
  }
  return remainingIds[0] ?? 0;
}

export function clipboardDescription(
  item: ClipboardEntry,
  now = Date.now() / 1000,
): string {
  const kind = {
    text: "Text",
    image: "Image",
    video: "Video",
    audio: "Audio",
    files: "Files",
    media: "Media",
  }[item.kind];
  const size =
    item.size < 1000
      ? `${String(item.size)} B`
      : `${(item.size / 1000).toFixed(1)} kB`;
  const minutes = Math.max(0, Math.floor((now - item.created) / 60));
  const age =
    minutes === 0
      ? "Just now"
      : minutes < 60
        ? `${String(minutes)} min ago`
        : `${String(Math.floor(minutes / 60))} h ago`;
  return `${kind} · ${size} · ${age} · ${item.mime}`;
}
