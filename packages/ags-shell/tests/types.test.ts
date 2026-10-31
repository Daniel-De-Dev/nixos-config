import { Variable } from "astal";
import { Widget } from "astal/gtk3";
import Gio from "gi://Gio?version=2.0";
import GioUnix from "gi://GioUnix?version=2.0";
import GLib from "gi://GLib?version=2.0";
import { indexApplications } from "../src/lib/applications";

// These checks fail if unresolved imports or permissive types erase inference.
export function checkTypes(): void {
  const applications = Variable(indexApplications(Gio.AppInfo.get_all()));
  const query = Variable("");
  Variable.derive([applications, query], (items, text) => {
    // @ts-expect-error Application metadata has no such property.
    items[0]?.missingProperty;
    // @ts-expect-error The query is inferred as a string.
    text.toFixed();
    return items.filter((item) => item.searchText.includes(text));
  });

  // @ts-expect-error GTK width requests must be numbers.
  new Widget.Window({ widthRequest: "wide" });
  // @ts-expect-error GIO application IDs must be strings.
  GioUnix.DesktopAppInfo.new(123);
  // @ts-expect-error GLib environment variable names must be strings.
  GLib.getenv(123);
}
