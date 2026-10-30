# Compile the changed translation unit against the host's real kernel config.
# This catches patch drift and C errors without rebuilding the entire kernel.
{ kernel }:
kernel.stdenv.mkDerivation {
  pname = "hibernation-kernel-compile-check";
  inherit (kernel)
    version
    src
    patches
    depsBuildBuild
    nativeBuildInputs
    makeFlags
    hardeningDisable
    env
    ;
  __structuredAttrs = true;
  enableParallelBuilding = true;
  # Upstream helper patches allow fuzz. Require an exact match for our exception.
  prePatch = ''
    patch --dry-run -p1 --fuzz=0 < ${../modules/hardware/patches/hibernate-lockdown-opt-in.patch}
  '';
  postPatch = ''
    patchShebangs scripts
  '';
  configurePhase = ''
    runHook preConfigure
    export buildRoot="$NIX_BUILD_TOP/build"
    mkdir -p "$buildRoot"
    cp ${kernel.configfile} "$buildRoot/.config"
    make "''${makeFlags[@]}" olddefconfig
    runHook postConfigure
  '';
  buildPhase = ''
    runHook preBuild
    make -j"$NIX_BUILD_CORES" "''${makeFlags[@]}" kernel/power/hibernate.o
    runHook postBuild
  '';
  installPhase = ''
    install -Dm444 "$buildRoot/kernel/power/hibernate.o" "$out/hibernate.o"
  '';
}
