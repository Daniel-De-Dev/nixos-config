import { Gdk, Gtk, Widget } from "astal/gtk3";
import GLib from "gi://GLib?version=2.0";
import Gio from "gi://Gio?version=2.0";
import GdkPixbuf from "gi://GdkPixbuf?version=2.0";
import { Variable, bind, execAsync, type Binding } from "astal";
import ActionRow from "../components/ActionRow";
import ConfirmationDialog from "../components/ConfirmationDialog";
import ShellWindow from "../components/ShellWindow";
import {
  clipboardDescription,
  parseClipboard,
  selectionAfterRemoval,
  type ClipboardSnapshot,
  type ClipboardEntry,
} from "../lib/clipboard";

type PreviewRow = {
  entry: ClipboardEntry;
  row: Widget.Button;
  image: Gtk.Image;
  alive: boolean;
  requested: boolean;
};
type SelectionPosition = {
  ids: number[];
  scroll: number;
  focusRow: boolean;
};

export default function ClipboardManager() {
  const snapshot = Variable<ClipboardSnapshot>({
    paused: false,
    watching: false,
    total: 0,
    entries: [],
  });
  const selected = Variable(0);
  const error = Variable("");
  const busy = Variable(false);
  let restoreFocus: Gtk.Widget | null = null;
  let poll = 0;
  let debounce = 0;
  let generation = 0;
  let refreshing = false;
  let lastOutput = "";
  let lastQuery = "";
  let rows: Widget.Button[] = [];
  let removal: SelectionPosition | null = null;
  let focusIdle = 0;
  let previewRows: PreviewRow[] = [];
  let previewQueue: PreviewRow[] = [];
  let previewEpoch = 0;
  let previewsRunning = 0;
  let previewIdle = 0;
  const previewCache = new Map<number, GdkPixbuf.Pixbuf | null>();

  function pumpPreviews() {
    while (previewsRunning < 2 && previewQueue.length) {
      const job = previewQueue.shift();
      if (!job?.alive) continue;
      const epoch = previewEpoch;
      previewsRunning++;
      const load = async () => {
        try {
          const output = (
            await execAsync(["ags-clipboard", "preview", String(job.entry.id)])
          ).trim();
          if (epoch !== previewEpoch || !visible()) return;
          let pixbuf: GdkPixbuf.Pixbuf | null = null;
          if (output && output.length <= 28000) {
            const stream = Gio.MemoryInputStream.new_from_bytes(
              GLib.Bytes.new(GLib.base64_decode(output)),
            );
            try {
              pixbuf = GdkPixbuf.Pixbuf.new_from_stream_at_scale(
                stream,
                64,
                48,
                true,
                null,
              );
            } finally {
              stream.close(null);
            }
          }
          previewCache.set(job.entry.id, pixbuf);
          if (job.alive && pixbuf) job.image.set_from_pixbuf(pixbuf);
        } catch {
          // Missing, deleted, unsupported, or invalid media keeps its type icon.
          if (epoch === previewEpoch) previewCache.set(job.entry.id, null);
        } finally {
          previewsRunning--;
          pumpPreviews();
        }
      };
      void load();
    }
  }

  function requestPreviews() {
    if (!visible()) return;
    const adjustment = list.get_vadjustment();
    const top = adjustment.get_value();
    if (adjustment.get_page_size() <= 0) return;
    const bottom = top + adjustment.get_page_size();
    for (const job of previewRows) {
      if (!job.alive || job.requested) continue;
      const allocation = job.row.get_allocation();
      if (
        job.entry.id !== selected.get() &&
        (allocation.y + allocation.height < top || allocation.y > bottom)
      )
        continue;
      job.requested = true;
      if (job.entry.id === selected.get()) previewQueue.unshift(job);
      else previewQueue.push(job);
    }
    pumpPreviews();
  }

  function queuePreviews() {
    if (previewIdle) return;
    previewIdle = GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
      previewIdle = 0;
      requestPreviews();
      return GLib.SOURCE_REMOVE;
    });
  }

  function visible() {
    return window.visible;
  }

  function restoreSelection(position: SelectionPosition) {
    if (focusIdle) GLib.source_remove(focusIdle);
    const current = generation;
    // GTK must allocate the replacement rows before their scroll bounds exist.
    focusIdle = GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
      focusIdle = 0;
      if (!visible() || current !== generation || dialog.visible)
        return GLib.SOURCE_REMOVE;
      const adjustment = list.get_vadjustment();
      adjustment.set_value(position.scroll);
      const index = snapshot
        .get()
        .entries.findIndex((item) => item.id === selected.get());
      const row = rows[index];
      if (row) {
        if (position.focusRow && !search.has_focus) row.grab_focus();
        const allocation = row.get_allocation();
        adjustment.clamp_page(allocation.y, allocation.y + allocation.height);
      } else {
        search.grab_focus();
      }
      return GLib.SOURCE_REMOVE;
    });
  }

  async function refresh() {
    if (!visible() || refreshing || busy.get() || dialog.visible) return;
    const current = generation;
    const query = search.text;
    refreshing = true;
    try {
      const output = await execAsync(["ags-clipboard", "list", query]);
      if (!visible() || current !== generation || query !== search.text) return;
      const queryChanged = query !== lastQuery;
      if (output !== lastOutput || queryChanged) {
        const state = parseClipboard(output);
        const position = removal ?? {
          ids: snapshot.get().entries.map((item) => item.id),
          scroll: list.get_vadjustment().get_value(),
          focusRow: rows.some((row) => row.has_focus),
        };
        const restore = removal !== null || position.focusRow;
        lastOutput = output;
        selected.set(
          queryChanged
            ? (state.entries[0]?.id ?? 0)
            : selectionAfterRemoval(
                position.ids,
                state.entries.map((item) => item.id),
                selected.get(),
              ),
        );
        snapshot.set(state);
        lastQuery = query;
        if (queryChanged) list.get_vadjustment().set_value(0);
        else if (restore) restoreSelection(position);
        removal = null;
        queuePreviews();
      }
      if (
        error.get() ===
        "Cannot read clipboard history. Check the clipboard service."
      )
        error.set("");
    } catch {
      if (current === generation && visible())
        error.set(
          "Cannot read clipboard history. Check the clipboard service.",
        );
    } finally {
      refreshing = false;
    }
  }

  async function run(action: string, id = 0) {
    if (busy.get() || dialog.visible) return;
    busy.set(true);
    generation++;
    if (["delete", "older", "clear"].includes(action)) {
      removal = {
        ids: snapshot.get().entries.map((item) => item.id),
        scroll: list.get_vadjustment().get_value(),
        focusRow: !search.has_focus,
      };
      previewEpoch++;
      previewQueue = [];
      previewCache.clear();
      for (const job of previewRows) {
        job.image.clear();
        job.alive = false;
      }
    }
    try {
      await execAsync(["ags-clipboard", action, ...(id ? [String(id)] : [])]);
      error.set("");
      if (action === "copy") window.hide();
    } catch {
      if (window.visible)
        error.set(
          "Clipboard action failed. The entry may have expired; try again.",
        );
    } finally {
      busy.set(false);
      lastOutput = "";
      void refresh();
    }
  }

  function confirm(action: "older" | "clear") {
    if (busy.get() || dialog.visible) return;
    const id = selected.get();
    if (action === "older" && !id) return;
    generation++;
    restoreFocus = window.get_focus();
    content.sensitive = false;
    dialog.open({
      title:
        action === "clear"
          ? "Clear all clipboard history?"
          : "Clear older entries?",
      description:
        action === "clear"
          ? "All saved entries will be deleted, including those hidden by search. The copy/paste and middle-click clipboards will also be emptied. This cannot be undone."
          : "Entries older than the selection will be deleted, including those hidden by search. The selected entry and newer entries will be kept. This cannot be undone.",
      confirmLabel: action === "clear" ? "Clear all" : "Clear older",
      onConfirm: () => {
        void run(action, id);
      },
    });
  }

  function activate() {
    if (selected.get()) void run("copy", selected.get());
  }

  function move(step: number) {
    const items = snapshot.get().entries;
    if (!items.length) return;
    const index = items.findIndex((item) => item.id === selected.get());
    const next = Math.max(0, Math.min(items.length - 1, index + step));
    const item = items[next];
    if (!item) return;
    selected.set(item.id);
    const allocation = rows[next]?.get_allocation();
    if (allocation)
      list
        .get_vadjustment()
        .clamp_page(allocation.y, allocation.y + allocation.height);
    requestPreviews();
  }

  const search = new Widget.Entry({
    className: "shell-search",
    placeholderText: "Search copied text, file paths, or media types...",
    onChanged: () => {
      generation++;
      if (debounce) GLib.source_remove(debounce);
      debounce = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 120, () => {
        debounce = 0;
        void refresh();
        return GLib.SOURCE_REMOVE;
      });
    },
    onActivate: activate,
  });

  function button(
    label: string | Binding<string>,
    tooltip: string,
    onClicked: () => void,
  ) {
    return new Widget.Button({
      label,
      tooltipText: tooltip,
      className: "shell-tool-button",
      sensitive: bind(busy).as((value) => !value),
      onClicked,
    });
  }

  const pause = button(
    bind(snapshot).as((state) => (state.paused ? "Resume" : "Pause")),
    "Pause or resume history capture (Ctrl+P)",
    () => {
      void run("pause");
    },
  );

  const list = new Widget.Scrollable({
    className: "shell-scrollable",
    hexpand: true,
    vexpand: true,
    hscroll: Gtk.PolicyType.NEVER,
    child: new Widget.Box({
      vertical: true,
      children: bind(snapshot).as((state) => {
        previewRows = [];
        rows = state.entries.map((item) => {
          const icon = {
            text: "text-x-generic",
            image: "image-x-generic",
            video: "video-x-generic",
            audio: "audio-x-generic",
            files: "system-file-manager",
            media: "application-octet-stream",
          }[item.kind];
          const image = new Gtk.Image({
            visible: true,
            icon_name: icon,
            pixel_size: 24,
            halign: Gtk.Align.CENTER,
            valign: Gtk.Align.CENTER,
          });
          const description = clipboardDescription(item);
          const row = ActionRow({
            title: item.preview,
            description: item.path
              ? `${item.path} · ${description}`
              : description,
            tooltip: [item.preview, item.path, description]
              .filter(Boolean)
              .join("\n"),
            icon,
            leading: new Widget.Box({
              className: "shell-thumbnail",
              hexpand: false,
              valign: Gtk.Align.CENTER,
              children: [image],
            }),
            selected: bind(selected).as((id) => id === item.id),
            onFocus: () => {
              selected.set(item.id);
              requestPreviews();
            },
            onActivate: () => {
              void run("copy", item.id);
            },
          });
          if (item.kind === "image" || item.kind === "video") {
            const cached = previewCache.get(item.id);
            if (cached) image.set_from_pixbuf(cached);
            const job = {
              entry: item,
              row,
              image,
              alive: true,
              requested: previewCache.has(item.id),
            };
            row.connect("destroy", () => {
              job.alive = false;
            });
            previewRows.push(job);
          }
          return row;
        });
        return [
          ...rows,
          new Widget.Label({
            label: search.text
              ? "No matching entries"
              : "Clipboard history is empty",
            className: "shell-hint",
            visible: !state.entries.length,
          }),
        ];
      }),
    }),
  });

  const dialog = ConfirmationDialog(() => {
    content.sensitive = true;
    const previous = restoreFocus;
    restoreFocus = null;
    if (visible()) {
      if (previous?.get_sensitive() && previous.get_can_focus())
        previous.grab_focus();
      else search.grab_focus();
    }
  });

  const content = new Widget.Box({
    vertical: true,
    children: [
      search,
      new Widget.Box({
        className: "shell-toolbar",
        children: [
          pause,
          button("Delete", "Delete selected entry (Ctrl+Delete)", () => {
            if (selected.get()) void run("delete", selected.get());
          }),
          button(
            "Clear older",
            "Delete entries older than the selection (Ctrl+Shift+Delete)",
            () => {
              confirm("older");
            },
          ),
          button(
            "Clear all",
            "Clear history and both clipboards (Ctrl+Shift+Backspace)",
            () => {
              confirm("clear");
            },
          ),
        ],
      }),
      new Widget.Label({
        label: bind(snapshot).as(
          (state) =>
            `${state.paused ? "Capture paused" : state.watching ? "Capture active" : "Capture unavailable"} · ${String(state.total)} entries · 24 h limit · Session storage`,
        ),
        className: "shell-hint",
        xalign: 0,
      }),
      new Widget.Label({
        label: bind(error),
        visible: bind(error).as(Boolean),
        className: "shell-hint",
        wrap: true,
        xalign: 0,
      }),
      list,
    ],
  });

  const window = ShellWindow({
    name: "clipboard-manager",
    title: "Clipboard",
    subtitle: "Fuzzy search · Text, images, and file references",
    hint: "↑/↓ Select · Enter to Copy · Ctrl+Del to Delete · Esc to Close",
    overlay: dialog.widget,
    onDismiss: () => {
      if (!dialog.visible) return false;
      dialog.cancel();
      return true;
    },
    initialFocus: search,
    onKeyPress: (event) => {
      if (dialog.handleKey(event)) return true;
      const key = event.get_keyval()[1];
      const modifiers = event.get_state()[1];
      const ctrl = Boolean(modifiers & Gdk.ModifierType.CONTROL_MASK);
      const shift = Boolean(modifiers & Gdk.ModifierType.SHIFT_MASK);
      if (ctrl && shift && key === Gdk.KEY_BackSpace) {
        confirm("clear");
      } else if (ctrl && shift && key === Gdk.KEY_Delete) {
        confirm("older");
      } else if (ctrl && key === Gdk.KEY_Delete) {
        if (selected.get()) void run("delete", selected.get());
      } else if (ctrl && (key === Gdk.KEY_p || key === Gdk.KEY_P)) {
        void run("pause");
      } else if (ctrl && (key === Gdk.KEY_f || key === Gdk.KEY_F)) {
        search.grab_focus();
      } else if (key === Gdk.KEY_Up || key === Gdk.KEY_Down) {
        move(key === Gdk.KEY_Down ? 1 : -1);
      } else if (key === Gdk.KEY_Return || key === Gdk.KEY_KP_Enter) {
        // Leave focused toolbar buttons and rows to GTK.
        if (!search.has_focus) return false;
        activate();
      } else {
        return false;
      }
      return true;
    },
    onClose: () => {
      previewEpoch++;
      previewQueue = [];
      previewCache.clear();
      if (previewIdle) GLib.source_remove(previewIdle);
      previewIdle = 0;
      if (focusIdle) GLib.source_remove(focusIdle);
      focusIdle = 0;
      removal = null;
      generation++;
      search.text = "";
      if (poll) GLib.source_remove(poll);
      if (debounce) GLib.source_remove(debounce);
      poll = debounce = 0;
      dialog.cancel();
      error.set("");
      selected.set(0);
      snapshot.set({ paused: false, watching: false, total: 0, entries: [] });
      lastOutput = "";
      lastQuery = "";
      list.get_vadjustment().set_value(0);
    },
    content,
  });
  window.connect("map", () => {
    void refresh();
    poll = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 1000, () => {
      void refresh();
      return GLib.SOURCE_CONTINUE;
    });
  });
  const adjustment = list.get_vadjustment();
  const scrolled = adjustment.connect("value-changed", requestPreviews);
  list.connect("size-allocate", requestPreviews);
  window.connect("destroy", () => {
    if (poll) GLib.source_remove(poll);
    if (debounce) GLib.source_remove(debounce);
    snapshot.drop();
    selected.drop();
    error.drop();
    busy.drop();
    previewEpoch++;
    previewQueue = [];
    previewCache.clear();
    if (previewIdle) GLib.source_remove(previewIdle);
    if (focusIdle) GLib.source_remove(focusIdle);
    adjustment.disconnect(scrolled);
  });
  return window;
}
