# The `logsmith` executable: the app sources plus a wrapper that runs them with
# the prebuilt python environment and the runtime CLIs on the PATH.
#
# On macOS an additional Logsmith.app bundle is installed under
# $out/Applications so the app appears in Finder and Spotlight.  The bundle's
# Info.plist sets LSUIElement=1 so the process never shows a Dock icon when
# launched from the bundle. The LaunchAgent uses `open -n -W` so Launch
# Services applies the bundle metadata while launchd tracks its lifetime.
{
  pkgs,
  python,
  pythonEnv,
  runtimeTools,
  src,
}:
let
  inherit (pkgs) lib;

  runtimePath = lib.makeBinPath runtimeTools;
  bundledQt = "${pythonEnv}/${python.sitePackages}/PyQt6/Qt6";

  # Single source of truth for the version is app/version.py.
  version = lib.head (
    builtins.match ''.*version[[:space:]]*=[[:space:]]*"([^"]+)".*'' (
      builtins.readFile "${src}/app/version.py"
    )
  );

  infoPlist = pkgs.writeText "Logsmith-Info.plist" ''
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
      "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>CFBundleIdentifier</key>
      <string>de.otto.logsmith</string>
      <key>CFBundleName</key>
      <string>Logsmith</string>
      <key>CFBundleDisplayName</key>
      <string>Logsmith</string>
      <key>CFBundleExecutable</key>
      <string>logsmith</string>
      <key>CFBundlePackageType</key>
      <string>APPL</string>
      <key>CFBundleShortVersionString</key>
      <string>${version}</string>
      <key>CFBundleVersion</key>
      <string>${version}</string>
      <key>CFBundleIconFile</key>
      <string>AppIcon.icns</string>
      <key>LSUIElement</key>
      <true/>
      <key>NSHighResolutionCapable</key>
      <true/>
    </dict>
    </plist>
  '';
in
pkgs.stdenv.mkDerivation {
  pname = "logsmith";
  inherit version src;

  nativeBuildInputs = [ pkgs.makeWrapper ];
  buildInputs = [ pythonEnv ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share/logsmith
    cp -r app $out/share/logsmith/
    makeWrapper ${pythonEnv}/bin/python $out/bin/logsmith \
      --add-flags $out/share/logsmith/app/run.py \
      --prefix PYTHONPATH : $out/share/logsmith \
      --prefix PATH : ${runtimePath}

    ${lib.optionalString pkgs.stdenv.isDarwin ''
      # Install a proper .app bundle for Finder / Spotlight discoverability.
      # The bundle sets LSUIElement=1 so launching via `open -a Logsmith` never
      # shows a Dock icon. macOS 26 requires the status item to be owned by the
      # original application process, so the bundle uses a native launcher that
      # embeds Python rather than a shell wrapper that replaces itself.
      app=$out/Applications/Logsmith.app/Contents
      mkdir -p $app/MacOS $app/Resources
      substitute ${./macos-launcher.c} launcher.c \
        --replace-fail '@pythonHome@' '${python}' \
        --replace-fail '@qtPluginPath@' '${bundledQt}/plugins' \
        --replace-fail '@qmlImportPath@' '${bundledQt}/qml' \
        --replace-fail '@pythonSitePackages@' '${pythonEnv}/${python.sitePackages}' \
        --replace-fail '@appPath@' "$out/share/logsmith" \
        --replace-fail '@runtimePath@' '${runtimePath}' \
        --replace-fail '@scriptPath@' "$out/share/logsmith/app/run.py"
      $CC launcher.c -o $app/MacOS/logsmith \
        -I${python}/include/python${python.pythonVersion} \
        -L${python}/lib -lpython${python.pythonVersion} \
        -Wl,-rpath,${python}/lib \
        -Wl,-rpath,${bundledQt}/lib
      cp ${infoPlist} $app/Info.plist
      cp $out/share/logsmith/app/assets/app_icon.icns $app/Resources/AppIcon.icns
    ''}

    runHook postInstall
  '';

  meta = {
    description = "Tray application for assuming AWS roles and managing GCP configuration";
    homepage = "https://github.com/otto-de/logsmith";
    license = lib.licenses.asl20;
    mainProgram = "logsmith";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
