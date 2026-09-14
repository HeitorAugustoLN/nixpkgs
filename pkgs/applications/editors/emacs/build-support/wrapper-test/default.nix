{
  runCommand,
  emacs,
  writeText,
  cowsay,
  hack-font,
  replaceVars,
  xvfb-run,
}:

let
  mkEpkg =
    pname: src: melpaBuild:
    melpaBuild {
      inherit pname src;
      version = "0.1.0"; # a dummy value
      turnCompilationWarningToError = true;
    };
in
runCommand "test-emacs-withPackages-wrapper"
  {
    nativeBuildInputs = [
      xvfb-run
      (emacs.pkgs.withPackages (epkgs: [
        epkgs.dash
        epkgs.flx-ido
        hack-font
        (mkEpkg "with-packages" (replaceVars ./with-packages.el {
          inherit (builtins) storeDir;
        }) epkgs.melpaBuild)
        (mkEpkg "early-default" ./early-default.el epkgs.melpaBuild)
        (mkEpkg "default" ./default.el epkgs.melpaBuild)
        cowsay
        (epkgs.treesit-grammars.with-grammars (ps: [ ps.tree-sitter-nix ]))
      ]))
    ];
    env = {
      # emulate a default NixOS env where INFOPATH is set like this (not ending with a ":")
      INFOPATH = "/fake-info-dir1:/fake-info-dir2";
      EMACS_TEST_VERBOSE = 1; # make ERT output verbose
    };
  }
  ''
    # The sandbox has no display server, but `font-family-list' (used by
    # `with-packages-fonts-of-requested-packages-are-available') needs a
    # GUI frame: a `--daemon' starts frameless, and `font-family-list' is
    # answered by the selected frame's font backend (nil on a frameless
    # daemon, as in `emacs -nw').  So run everything under Xvfb and give
    # the daemon a frame on that display before the tests run.

    cat > run-test.sh <<'EOF'
    set -e

    # Give Emacs a HOME to emulate a real user environment.
    HOME="$PWD"

    nonBatchEmacsSocket="$PWD/non-batch-emacs-socket"
    emacs --daemon="$nonBatchEmacsSocket"

    emacs --batch --load=with-packages \
      --eval="(setq with-packages-non-batch-emacs-socket \"$nonBatchEmacsSocket\")" \
      --eval="(message \"daemon frame: %s\"
               (server-eval-at with-packages-non-batch-emacs-socket
                '(progn
                    (select-frame
                     (make-frame-on-display (getenv \"DISPLAY\")))
                    (framep (selected-frame)))))" \
      --funcall=ert-run-tests-batch-and-exit
    EOF

    xvfb-run -d bash run-test.sh

    touch $out
  ''
