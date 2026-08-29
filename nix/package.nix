# The `logsmith` executable: the app sources plus a wrapper that runs them with
# the prebuilt python environment and the runtime CLIs on the PATH.
#
# On macOS an additional Logsmith.app bundle is installed under
# $out/Applications so the app appears in Finder and Spotlight.  The bundle's
# Info.plist sets LSUIElement=1 so the process never shows a Dock icon when
# launched from the bundle (e.g. via `open -a Logsmith`).  The LaunchAgent
# autostart uses $out/bin/logsmith directly for reliable process management.
{
  pkgs,
  pythonEnv,
  runtimeTools,
  src,
}:
let
  inherit (pkgs) lib;

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
      <key>CFBundleIconFile</key>
      <string>AppIcon</string>
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
      --prefix PATH : ${lib.makeBinPath runtimeTools}

    ${lib.optionalString pkgs.stdenv.isDarwin ''
      # Install a proper .app bundle for Finder / Spotlight discoverability.
      # The bundle sets LSUIElement=1 so launching via `open -a Logsmith` never
      # shows a Dock icon.  The macOS binary inside the bundle is a symlink to
      # $out/bin/logsmith so both entry-points stay in sync.
      app=$out/Applications/Logsmith.app/Contents
      mkdir -p $app/MacOS $app/Resources
      ln -s $out/bin/logsmith $app/MacOS/logsmith
      cp ${infoPlist} $app/Info.plist
      cp $out/share/logsmith/app/assets/app_icon.icns $app/Resources/AppIcon.icns
    ''}

    runHook postInstall
  '';
}
