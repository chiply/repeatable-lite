#!/usr/bin/env bash
# Launch repeatable in a sandboxed bare Emacs (emacs -Q) with a live-eval
# server, loading demo/demo-init.el.  Nothing here touches your real ~/.emacs.d.
#
#   ./demo/run.sh            # GUI session
#   ./demo/run.sh -nw        # terminal session (extra args are passed to emacs)
#
# A named server is started at a fixed, discoverable socket path so an LLM (or
# you) can eval into THIS session without hunting through $TMPDIR:
#
#   emacsclient -s "$(cat demo/.server-socket)" -e '(load-file "/abs/path/repeatable.el")'
#
# Reset the sandbox (force a clean reinstall) with:  rm -rf demo/.sandbox
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SANDBOX="$HERE/.sandbox"
SOCKET="$SANDBOX/server"

mkdir -p "$SANDBOX"
chmod 700 "$SANDBOX"   # Emacs refuses a server socket in a group/other-accessible dir
printf '%s\n' "$SOCKET" > "$HERE/.server-socket"

echo "sandbox : $SANDBOX   (rm -rf to reset)"
echo "server  : emacsclient -s \"$SOCKET\" -e '(...)'"

# Load the demo BEFORE starting the server: an --eval that errors aborts the rest
# of the command line, so the server must come last or it could shadow the demo.
exec emacs -Q \
  --eval "(setq user-emacs-directory \"$SANDBOX/\" package-user-dir \"$SANDBOX/elpa/\")" \
  -l "$HERE/demo-init.el" \
  --eval "(progn (require 'server) (setq server-name \"$SOCKET\") (server-start))" \
  "$@"
