{ stdenv
, fetchurl
, makeDesktopItem
, makeWrapper
, jre # old or modded versions of the game may require Java 8 (https://aur.archlinux.org/packages/minecraft-launcher/#pinned-674960)
, xorg
, zlib
, nss
, nspr
, fontconfig
, gnome2
, cairo
, expat
, alsaLib
, cups
, dbus
, atk
, gtk3-x11
, gtk2-x11
, gdk-pixbuf
, glib
, curl
, freetype
, libpulseaudio
, systemd
, flite ? null
, libXxf86vm ? null
}:

let
  desktopItem = makeDesktopItem {
    name = "minecraft-launcher";
    exec = "minecraft-launcher";
    icon = "minecraft-launcher";
    comment = "Official launcher for Minecraft, a sandbox-building game";
    desktopName = "Minecraft Launcher";
    categories = "Game;Application;";
  };

  envLibPath = stdenv.lib.makeLibraryPath [
      curl
      libpulseaudio
      systemd
      alsaLib # needed for narrator
      flite # needed for narrator
      libXxf86vm # needed only for versions <1.13
    ];

  libPath = stdenv.lib.makeLibraryPath ([
    alsaLib
    atk
    cairo
    cups
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gnome2.GConf
    gnome2.pango
    gtk3-x11
    gtk2-x11
    nspr
    nss
    stdenv.cc.cc
    zlib
  ] ++
  (with xorg; [
    libX11
    libxcb
    libXcomposite
    libXcursor
    libXdamage
    libXext
    libXfixes
    libXi
    libXrandr
    libXrender
    libXtst
    libXScrnSaver
  ]));
in
 stdenv.mkDerivation rec {
  pname = "minecraft-launcher";

  version = "2.1.11314";

  src = fetchurl {
    url = "https://launcher.mojang.com/download/Minecraft.tar.gz";
    sha256 = "1cd0mpxqmci3m3y1xh5nbx68z69v0x1jyzc07siwfbxqkrlrddj9";
  };

  icon = fetchurl {
    url = "https://launcher.mojang.com/download/minecraft-launcher.svg";
    sha256 = "0w8z21ml79kblv20wh5lz037g130pxkgs8ll9s3bi94zn2pbrhim";
  };

  nativeBuildInputs = [ makeWrapper ];

  sourceRoot = ".";

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    mkdir -p $out/opt
    mv minecraft-launcher $out/opt

    ${desktopItem.buildCommand}
    install -D $icon $out/share/icons/hicolor/symbolic/apps/minecraft-launcher.svg

    makeWrapper $out/opt/minecraft-launcher/minecraft-launcher $out/bin/minecraft-launcher \
      --prefix LD_LIBRARY_PATH : ${envLibPath} \
      --prefix PATH : ${stdenv.lib.makeBinPath [ jre ]} \
      --run "cd /tmp" # Do not create `GPUCache` in current directory
  '';

  preFixup = ''
    patchelf \
      --set-interpreter ${stdenv.cc.bintools.dynamicLinker} \
      --set-rpath '$ORIGIN/'":${libPath}" \
      $out/opt/minecraft-launcher/minecraft-launcher
    patchelf \
      --set-rpath '$ORIGIN/'":${libPath}" \
      $out/opt/minecraft-launcher/libcef.so
    patchelf \
      --set-rpath '$ORIGIN/'":${libPath}" \
      $out/opt/minecraft-launcher/liblauncher.so
  '';

  meta = with stdenv.lib; {
    description = "Official launcher for Minecraft, a sandbox-building game";
    homepage = "https://minecraft.net";
    maintainers = with maintainers; [ cpages ryantm infinisil ];
    license = licenses.unfree;
  };

  passthru.updateScript = ./update.sh;
}
