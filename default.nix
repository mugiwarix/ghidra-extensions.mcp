{
  lib,
  fetchFromGitHub,
  buildGhidraExtension,
  maven,
  ghidra,
  stdenv,
}:

buildGhidraExtension (
  let
    pname = "mcp";
    version = "1.4";

    src = fetchFromGitHub {
      owner = "LaurieWired";
      repo = "GhidraMCP";
      rev = version;
      hash = "sha256-9NzmYQqfvQm5wjmmPWOG1+g9zCzGrUrRZX+m1nRS0m4=";
    };

    ghidraJars = [
      "Ghidra/Features/Base/lib/Base.jar"
      "Ghidra/Features/Decompiler/lib/Decompiler.jar"
      "Ghidra/Framework/Docking/lib/Docking.jar"
      "Ghidra/Framework/Generic/lib/Generic.jar"
      "Ghidra/Framework/Project/lib/Project.jar"
      "Ghidra/Framework/SoftwareModeling/lib/SoftwareModeling.jar"
      "Ghidra/Framework/Utility/lib/Utility.jar"
      "Ghidra/Framework/Gui/lib/Gui.jar"
    ];

    copyGhidraJars = ''
      ghidraRoot=${ghidra}/lib/ghidra
      mkdir -p lib
      for jar in ${lib.concatStringsSep " " (map (j: "\"${j}\"") ghidraJars)}; do
        srcJar="$ghidraRoot/$jar"
        if [ ! -f "$srcJar" ]; then
          echo "Missing $srcJar" >&2
          exit 1
        fi
        cp "$srcJar" "lib/$(basename "$srcJar")"
      done
    '';

    mavenDeps = stdenv.mkDerivation {
      pname = "${pname}-maven-deps";
      inherit src version;
      nativeBuildInputs = [ maven ];

      buildPhase = ''
        runHook preBuild
        mkdir -p "$out/.m2"
        ${copyGhidraJars}
        mvn -Dmaven.repo.local="$out/.m2" -DskipTests clean package assembly:single
        runHook postBuild
      '';

      installPhase = ''
        runHook preInstall
        find "$out" -type f \( \
          -name \*.lastUpdated \
          -o -name resolver-status.properties \
          -o -name _remote.repositories \) \
          -delete
        runHook postInstall
      '';

      dontFixup = true;
      outputHashAlgo = "sha256";
      outputHashMode = "recursive";
      outputHash = "sha256-bcMbLrxvUszD8A16PJMTbo91emX3r7q+UqVZxwQpk+M=";
    };
  in
  {
    inherit pname version src;

    nativeBuildInputs = [ maven ];

    preBuild = ''
      ${copyGhidraJars}
    '';

    buildPhase = ''
      runHook preBuild
      cp -r "${mavenDeps}/.m2" "$TMPDIR/m2"
      chmod -R u+w "$TMPDIR/m2"
      mvn -o -Dmaven.repo.local=$TMPDIR/m2 -DskipTests clean package assembly:single
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib/ghidra/Ghidra/Extensions
      zipFile=$(echo target/*.zip)
      if [ -z "$zipFile" ] || [ ! -f "$zipFile" ]; then
        echo "Expected a single zip in target/, got: $zipFile" >&2
        exit 1
      fi
      unzip -d $out/lib/ghidra/Ghidra/Extensions "$zipFile"
      install -Dm755 ${src}/bridge_mcp_ghidra.py $out/bin/bridge_mcp_ghidra.py
      runHook postInstall
    '';

    meta = with lib; {
      description = "MCP server + Ghidra plugin for autonomous reverse engineering";
      homepage = "https://github.com/LaurieWired/GhidraMCP";
      license = licenses.gpl3Only;
      maintainers = with maintainers; [ mugiwarix ];
      platforms = platforms.unix;
    };
  }
)
