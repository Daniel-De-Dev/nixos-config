{
  lib,
  astal,
  buildNpmPackage,
  makeWrapper,
  nodejs_24,
  symlinkJoin,
  glib,
  gobject-introspection,
  gtk3,
  gtk4,
}:
let
  # Use the same introspection files as the pinned runtime, including transitive
  # GTK dependencies. Astal's shared application declarations refer to both GTKs.
  dependenciesOf =
    package:
    [ (lib.getDev package) ]
    ++ lib.concatMap dependenciesOf (package.propagatedBuildInputs or [ ]);
  girFiles = symlinkJoin {
    name = "ags-shell-gir-files";
    paths = lib.unique (
      lib.concatMap dependenciesOf [
        astal.astal3
        astal.astal4
        astal.hyprland
        astal.io
        glib
        gobject-introspection
        gtk3
        gtk4
      ]
    );
  };
in
buildNpmPackage {
  pname = "ags-shell-tooling";
  version = "0.2.0";
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./package.json
      ./package-lock.json
      ./generate-types.mjs
    ];
  };
  nodejs = nodejs_24;
  npmDepsHash = "sha256-j+fYmqSJQrrKn8+IMp3BhjaJXTyCfT5IDaPmqrdbvSQ=";
  nativeBuildInputs = [ makeWrapper ];
  dontNpmBuild = true;

  buildPhase = ''
    runHook preBuild
    node generate-types.mjs ${astal.gjs}/share/astal/gjs ${girFiles}/share/gir-1.0
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin"
    cp -R node_modules "$out/node_modules"
    for command in tsc eslint typescript-language-server; do
      makeWrapper "$out/node_modules/.bin/$command" "$out/bin/$command" \
        --prefix PATH : ${lib.makeBinPath [ nodejs_24 ]}
    done
    runHook postInstall
  '';
}
