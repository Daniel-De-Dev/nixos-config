// Keep desktop-entry metadata separate from the native launch operation.
export type ApplicationInfo = {
  should_show(): boolean;
  get_display_name(): string;
  get_name(): string;
  get_description(): string | null;
  get_id(): string | null;
  get_executable(): string | null;
};

export type Application<T extends ApplicationInfo> = {
  info: T;
  id: string;
  name: string;
  description: string;
  searchText: string;
};

export function indexApplications<T extends ApplicationInfo>(
  applications: readonly T[],
): Application<T>[] {
  return applications
    .filter((info) => info.should_show())
    .map((info) => {
      const id = info.get_id() || "";
      const nativeName = info.get_name();
      const name = info.get_display_name() || nativeName || id;
      const description = info.get_description() || "";
      const executable = info.get_executable() || "";
      return {
        info,
        id,
        name,
        description: description || executable || id,
        searchText: [name, nativeName, description, executable, id].join(" "),
      };
    })
    .sort((a, b) => a.name.localeCompare(b.name) || a.id.localeCompare(b.id));
}
