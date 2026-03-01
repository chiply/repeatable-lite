# repeatable-lite

[![CI](https://github.com/chiply/repeatable-lite/actions/workflows/ci.yml/badge.svg)](https://github.com/chiply/repeatable-lite/actions/workflows/ci.yml)
[![License: GPL-3.0](https://img.shields.io/badge/License-GPL%203.0-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

A lightweight Emacs package for making prefix key commands repeatable with which-key integration.

## Overview

After executing a command within a prefix keymap, you stay in that keymap and can immediately press another key to execute another command without re-typing the prefix.

## Installation

### With elpaca (use-package)

```elisp
(use-package repeatable-lite
  :ensure (:host github :repo "chiply/repeatable-lite")
  :config (repeatable-lite-mode 1))
```

### With straight.el (use-package)

```elisp
(use-package repeatable-lite
  :straight (:host github :repo "chiply/repeatable-lite")
  :config (repeatable-lite-mode 1))
```

### Manual

Clone the repository and add it to your `load-path`:

```elisp
(add-to-list 'load-path "/path/to/repeatable-lite")
(require 'repeatable-lite)
(repeatable-lite-mode 1)
```

## Usage

The main entry point is the `**` macro, which wraps any interactive command to make it repeatable within its prefix keymap.

### Example with general.el

```elisp
(general-define-key
 "C-c w h" (** windmove-left)
 "C-c w l" (** windmove-right)
 "C-c w j" (** windmove-down)
 "C-c w k" (** windmove-up))
```

After pressing `C-c w h` to move left, you can press `h`/`l`/`j`/`k` repeatedly without the `C-c w` prefix. Press any key outside the keymap to exit.

### How it works

1. You press a prefixed key like `C-c w h`
2. The wrapped command executes (e.g., `windmove-left`)
3. The prefix keymap stays active — which-key shows available keys
4. Press another key in the map to repeat, or any other key to exit

## Requirements

- Emacs 30.1+ (which-key is built-in since Emacs 30.1)

## License

GPL-3.0-or-later
