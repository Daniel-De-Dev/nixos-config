import { Gdk, Widget } from "astal/gtk3";
import Gio from "gi://Gio?version=2.0";
import GioUnix from "gi://GioUnix?version=2.0";
import GLib from "gi://GLib?version=2.0";
import { Variable, bind, execAsync } from "astal";
import ActionRow from "../components/ActionRow";
import ShellWindow from "../components/ShellWindow";
import { indexApplications, type Application } from "../lib/applications";
import { fuzzyRank } from "../lib/search";

const MAX_RESULTS = 50;

export default function ApplicationLauncher() {
  const directLaunch = GLib.getenv("AGS_SHELL_LAUNCH_MODE") === "direct";
  const logHint = directLaunch
    ? "See the terminal that started the preview."
    : "See the AGS service journal.";
  const query = Variable("");
  const applications = Variable<Application<Gio.AppInfo>[]>([]);
  const error = Variable("");
  let launching = false;
  const matches = Variable.derive([applications, query], (items, q) =>
    fuzzyRank(items, q, (item) => item.searchText),
  );

  function refresh() {
    try {
      applications.set(indexApplications(Gio.AppInfo.get_all()));
      error.set("");
    } catch (err) {
      applications.set([]);
      error.set(`Cannot read installed applications. ${logHint}`);
      console.error(`Cannot read installed applications: ${err}`);
    }
  }

  function launch(application?: Application<Gio.AppInfo>) {
    if (!application || launching) return;
    const display = Gdk.Display.get_default();
    launching = true;
    window.hide();
    const start = async () => {
      try {
        display?.sync();
        if (!application.id)
          throw new Error("Application has no desktop entry ID");
        if (directLaunch) {
          // Keep the nested display and private bus; GIO handles desktop entries.
          const context = display?.get_app_launch_context() ?? null;
          if (!application.info.launch([], context))
            throw new Error("The desktop entry could not be launched");
        } else {
          const filename =
            application.info instanceof GioUnix.DesktopAppInfo
              ? application.info.get_filename()
              : null;
          if (!filename) throw new Error("Desktop entry has no file path");
          const gio = GLib.find_program_in_path("gio");
          if (!gio) throw new Error("GIO launcher is unavailable");
          await execAsync([
            "uwsm",
            "app",
            "-t",
            "service",
            "--",
            gio,
            "launch",
            filename,
          ]);
        }
      } catch (err) {
        console.error(
          `Cannot launch ${application.id || application.name}: ${err}`,
        );
        window.show();
        error.set(`Cannot start ${application.name}. ${logHint}`);
      } finally {
        launching = false;
      }
    };
    GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
      void start();
      return GLib.SOURCE_REMOVE;
    });
  }

  const search = new Widget.Entry({
    className: "shell-search",
    placeholderText: "Search applications...",
    onChanged: (self) => query.set(self.text),
    onActivate: () => launch(matches.get()[0]),
  });
  const list = new Widget.Scrollable({
    className: "shell-scrollable",
    hexpand: true,
    vexpand: true,
    child: new Widget.Box({
      vertical: true,
      children: bind(matches).as((items) => [
        ...items.slice(0, MAX_RESULTS).map((application) =>
          ActionRow({
            title: application.name,
            description: application.description,
            icon:
              application.info.get_icon() ??
              Gio.ThemedIcon.new("application-x-executable"),
            onActivate: () => launch(application),
          }),
        ),
        new Widget.Label({
          label: "No matching applications",
          className: "shell-hint",
          visible: items.length === 0,
        }),
        new Widget.Label({
          label: `Showing the first ${MAX_RESULTS} of ${items.length} applications. Type to narrow your search.`,
          className: "shell-hint",
          wrap: true,
          visible: items.length > MAX_RESULTS,
        }),
      ]),
    }),
  });
  const window = ShellWindow({
    name: "application-launcher",
    title: "Applications",
    subtitle: "Fuzzy search installed applications",
    hint: "Enter to launch first result · Tab to choose · Esc to close",
    initialFocus: search,
    onClose: () => {
      search.text = "";
      query.set("");
      error.set("");
      list.get_vadjustment().set_value(0);
    },
    content: new Widget.Box({
      vertical: true,
      children: [
        search,
        new Widget.Label({
          label: bind(error),
          visible: bind(error).as(Boolean),
          className: "shell-hint",
          wrap: true,
        }),
        list,
      ],
    }),
  });
  window.connect("map", refresh);
  const monitor = Gio.AppInfoMonitor.get();
  const changed = monitor.connect("changed", () => {
    if (window.visible) refresh();
  });
  window.connect("destroy", () => {
    monitor.disconnect(changed);
    matches.drop();
    applications.drop();
    query.drop();
    error.drop();
  });
  return window;
}
