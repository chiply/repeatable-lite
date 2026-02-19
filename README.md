# repeatable-lite

A lightweight Emacs package for making prefix key commands repeatable with which-key integration.

## Overview

After executing a command within a prefix keymap, you stay in that keymap and can immediately press another key to execute another command without re-typing the prefix.

## Installation

### Using Eask

```bash
eask install-deps
```

### Using elpaca (with use-package)

```elisp
(use-package repeatable-lite
  :ensure (:host github :repo "chiply/repeatable-lite"))
```

### Manual

Clone this repository and add it to your `load-path`:

```elisp
(add-to-list 'load-path "/path/to/repeatable-lite")
(require 'repeatable-lite)
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

- Emacs 29.1+
- which-key 3.5.0+

## License

GPL-3.0
