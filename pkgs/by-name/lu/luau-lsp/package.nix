{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  llvmPackages,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "luau-lsp";
  version = "1.45.0";

  src = fetchFromGitHub {
    owner = "JohnnyMorganz";
    repo = "luau-lsp";
    tag = finalAttrs.version;
    hash = "sha256-OJAjTy0vTRb43TTiPeXafWq4kjIpnDXoTprVzbMnaWQ=";
    fetchSubmodules = true;
  };

  NIX_CFLAGS_COMPILE = "-Wno-error";

  cmakeFlags = lib.optionals stdenv.hostPlatform.isDarwin [
    (lib.cmakeFeature "CMAKE_OSX_ARCHITECTURES" stdenv.hostPlatform.darwinArch)
  ];

  nativeBuildInputs = [ cmake ];
  # buildInputs = lib.optionals stdenv.cc.isClang [ llvmPackages.libunwind ];

  buildPhase = ''
    runHook preBuild

    cmake --build . --target Luau.LanguageServer.CLI --config Release

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    install -D luau-lsp $out/bin/luau-lsp

    runHook postInstall
  '';

  meta = {
    description = "Language Server Implementation for Luau";
    homepage = "https://github.com/JohnnyMorganz/luau-lsp";
    changelog = "https://github.com/JohnnyMorganz/luau-lsp/blob/${finalAttrs.version}/CHANGELOG.md";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ HeitorAugustoLN ];
    mainProgram = "luau-lsp";
    platforms = lib.platforms.all;
  };
})
