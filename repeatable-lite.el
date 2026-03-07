;;; repeatable-lite.el --- Repeatable prefix commands with which-key -*- lexical-binding: t; -*-

;; Copyright (C) 2025 Charlie Holland

;; Author: Charlie Holland <mister.chiply@gmail.com>
;; Maintainer: Charlie Holland <mister.chiply@gmail.com>
;; URL: https://github.com/chiply/repeatable-lite
;; x-release-please-start-version
;; Version: 0.2.5
;; x-release-please-end
;; Package-Requires: ((emacs "30.1"))
;; Keywords: convenience, keys
;;
;; This file is not part of GNU Emacs.
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; repeatable-lite provides a lightweight system for making prefix key commands
;; repeatable.  After executing a command within a prefix keymap, you stay in
;; that keymap and can immediately press another key to execute another command
;; without re-typing the prefix.
;;
;; The main entry point is the `repeatable-lite-wrap' macro, which wraps any
;; interactive command to make it repeatable within its prefix keymap.
;;
;; Example usage with general.el:
;;
;;   (general-define-key
;;    "C-c w h" (repeatable-lite-wrap windmove-left)
;;    "C-c w l" (repeatable-lite-wrap windmove-right)
;;    "C-c w j" (repeatable-lite-wrap windmove-down)
;;    "C-c w k" (repeatable-lite-wrap windmove-up))
;;
;; After pressing C-c w h to move left, you can press h/l/j/k repeatedly
;; without the C-c w prefix.  Press any key outside the keymap to exit.
;;
;; Which-key integration shows available keys while in the repeatable loop.
;;
;; Note: This package uses some which-key internal APIs
;; (`which-key--create-buffer-and-show', `which-key--timer') to manage
;; the popup lifecycle during repeatable loops.  There is no public API
;; for programmatically showing and dismissing the which-key buffer, so
;; these internals are necessary for correct behavior.

;;; Code:

(require 'seq)
(require 'which-key)

;; Declare which-key internal APIs used for popup lifecycle management.
(declare-function which-key--create-buffer-and-show "which-key")
(declare-function which-key--start-timer "which-key")
(declare-function which-key--popup-showing-p "which-key")
(declare-function which-key--current-key-string "which-key")
(declare-function which-key--full-prefix "which-key")
(declare-function which-key--propertize "which-key")

(defgroup repeatable-lite nil
  "Repeatable prefix commands with which-key."
  :group 'convenience
  :prefix "repeatable-lite-")

(defvar repeatable-lite-current-prefix nil
  "The current prefix key sequence during a repeatable loop.")

(defvar repeatable-lite--saved-settings nil
  "Plist of saved which-key settings, or nil when no repeatable loop is active.
A non-nil value also serves as the active flag.")

(defcustom repeatable-lite-help-backends
  '((?\C-h "C-h" "which-key" repeatable-lite--prefix-help))
  "Alist of help backends for `repeatable-lite--versatile-C-h'.
Each entry is (KEY KEY-LABEL DESCRIPTION HANDLER).
KEY is the character to match after the initial \\`C-h' press.
KEY-LABEL is the display string for the key.
DESCRIPTION names the backend.
HANDLER is called with two arguments: KEYMAP and PREFIX."
  :type '(repeat (list character string string function))
  :group 'repeatable-lite)

(defcustom repeatable-lite-dismiss-key ?q
  "Key to dismiss help and return to the active prefix.
In the which-key \\`C-h' dispatch, pressing this key hides the popup
and replays the prefix so the user can continue typing.
In minibuffer-based backends, \\`C-g' serves the same purpose."
  :type 'character
  :group 'repeatable-lite)

(defvar repeatable-lite--help-keymap nil
  "Saved keymap for the current help session, used by backend switching.")

(defvar repeatable-lite--help-prefix nil
  "Saved prefix for the current help session, used by backend switching.")

(defun repeatable-lite--which-key-settings ()
  "Configure which-key for repeatable display.
Saves the current which-key settings before modifying them."
  (unless repeatable-lite--saved-settings
    (setq repeatable-lite--saved-settings
          (list :idle-delay which-key-idle-delay
                :idle-secondary-delay which-key-idle-secondary-delay
                :persistent-popup which-key-persistent-popup
                :echo-keystrokes echo-keystrokes)))
  (setq which-key-idle-delay 0.1
        which-key-idle-secondary-delay 0.1
        which-key-persistent-popup t
        echo-keystrokes 1000)
  (which-key--start-timer))

(defvar repeatable-lite--prefix-help-pending nil
  "Non-nil when waiting for the real command after prefix help.")

(defun repeatable-lite--restore-after-prefix-help ()
  "Restore which-key settings after a prefix command completes.
Skips the initial help command invocation and any which-key paging
commands (undo, page turn, etc.), cleaning up only when a real
command executes."
  (cond
   (repeatable-lite--prefix-help-pending
    (setq repeatable-lite--prefix-help-pending nil))
   ((member this-command which-key--paging-functions)
    nil)
   (t
    (remove-hook 'post-command-hook #'repeatable-lite--restore-after-prefix-help)
    (repeatable-lite--kill-which-key))))

(defun repeatable-lite--which-key-dispatch-or-switch ()
  "Replace `which-key-C-h-dispatch' with combined backend switch support.
Shows a combined prompt with which-key paging commands and switch
keys for other help backends, then dispatches accordingly."
  (interactive)
  (if (not (which-key--popup-showing-p))
      (which-key-C-h-dispatch)
    (let* ((prefix-keys (which-key--current-key-string))
           (full-prefix (which-key--full-prefix
                         prefix-keys current-prefix-arg t))
           (switch-entries
            (seq-filter
             (lambda (e)
               (not (eq (nth 3 e) #'repeatable-lite--prefix-help)))
             repeatable-lite-help-backends))
           (dismiss-label (key-description (vector repeatable-lite-dismiss-key)))
           (switch-prompt
            (when switch-entries
              (concat " "
                      (mapconcat
                       (lambda (e)
                         (format "%s → %s" (nth 1 e) (nth 2 e)))
                       switch-entries ", "))))
           (prompt (concat full-prefix
                           (which-key--propertize
                            (concat
                             (substitute-command-keys
                              which-key-C-h-map-prompt)
                             switch-prompt
                             (format " %s → dismiss" dismiss-label))
                            'face 'which-key-note-face)))
           (ev (read-event prompt))
           (backend (assq ev repeatable-lite-help-backends)))
      (setq this-command 'which-key-C-h-dispatch)
      (cond
       ((eq ev repeatable-lite-dismiss-key)
        (remove-hook 'post-command-hook #'repeatable-lite--restore-after-prefix-help)
        (repeatable-lite--kill-which-key repeatable-lite--help-prefix))
       ((and backend
             (not (eq (nth 3 backend) #'repeatable-lite--prefix-help)))
        (repeatable-lite--switch-from-which-key ev))
       (t
        (let* ((key (if (numberp ev) (string ev) (vector ev)))
               (cmd (lookup-key which-key-C-h-map key))
               (which-key-inhibit t))
          (if cmd
              (funcall cmd key)
            (which-key-turn-page 0))))))))

(defun repeatable-lite--prefix-help (_keymap prefix)
  "Show which-key help for PREFIX.
KEYMAP is ignored; PREFIX is the key sequence to display bindings for.
Returns to the normal command loop so which-key can update via its
idle timer as the user navigates sub-prefixes."
  (interactive)
  (repeatable-lite--which-key-settings)
  (which-key-reload-key-sequence prefix)
  (setq prefix-help-command 'repeatable-lite--which-key-dispatch-or-switch)
  (setq repeatable-lite--prefix-help-pending t)
  (add-hook 'post-command-hook #'repeatable-lite--restore-after-prefix-help))

(defun repeatable-lite--kill-which-key (&optional replay-keys)
  "Kill the which-key buffer and restore original which-key state.
When REPLAY-KEYS is non-nil, reload that key sequence into the
command loop so Emacs continues from those keys."
  (interactive)
  (let ((buf (get-buffer which-key-buffer-name)))
    (when (bufferp buf) (kill-buffer buf)))
  (when repeatable-lite--saved-settings
    (setq which-key-idle-delay (plist-get repeatable-lite--saved-settings :idle-delay)
          which-key-idle-secondary-delay (plist-get repeatable-lite--saved-settings :idle-secondary-delay)
          which-key-persistent-popup (plist-get repeatable-lite--saved-settings :persistent-popup)
          echo-keystrokes (plist-get repeatable-lite--saved-settings :echo-keystrokes)
          repeatable-lite--saved-settings nil)
    (which-key--start-timer))
  (setq prefix-help-command 'repeatable-lite--versatile-C-h
        current-prefix-arg nil)
  (when replay-keys
    (which-key-reload-key-sequence replay-keys)))

(defun repeatable-lite--call-backend (backend km prefix)
  "Call BACKEND with KM and PREFIX, handling switch and dismiss.
If the backend throws to `repeatable-lite-switch' with another
backend key, the target backend is called instead.
If the backend signals `quit' (e.g. \\`C-g' in a minibuffer),
the prefix is replayed so the user can continue typing."
  (let ((next-key (catch 'repeatable-lite-switch
                    (condition-case nil
                        (progn (funcall (nth 3 backend) km prefix) nil)
                      (quit :dismiss)))))
    (cond
     ((eq next-key :dismiss)
      (which-key-reload-key-sequence prefix))
     (next-key
      (let ((target (assq next-key repeatable-lite-help-backends)))
        (when target
          (repeatable-lite--call-backend target km prefix)))))))

(defun repeatable-lite--switch-from-which-key (target-key)
  "Switch from which-key help to the backend at TARGET-KEY."
  (remove-hook 'post-command-hook #'repeatable-lite--restore-after-prefix-help)
  (repeatable-lite--kill-which-key)
  (let ((backend (assq target-key repeatable-lite-help-backends)))
    (when backend
      (repeatable-lite--call-backend
       backend
       repeatable-lite--help-keymap
       repeatable-lite--help-prefix))))

(defun repeatable-lite--switch-from-minibuffer (target-key)
  "Switch from a minibuffer-based backend to the backend at TARGET-KEY.
Throws to the `repeatable-lite-switch' catch tag, unwinding the
minibuffer and any intermediate calls."
  (interactive)
  (throw 'repeatable-lite-switch target-key))

(defun repeatable-lite-setup-minibuffer-switches (current-handler)
  "Set up switch keys in the current minibuffer for other backends.
CURRENT-HANDLER is the handler function of the active backend,
used to exclude it from the switch keys.  Call this from
`minibuffer-with-setup-hook' in minibuffer-based backends.
Keys that conflict with `help-char' are shifted (e.g. \\`C-h' becomes
\\`C-S-h') to avoid the built-in help system intercepting them."
  (dolist (entry repeatable-lite-help-backends)
    (unless (eq (nth 3 entry) current-handler)
      (let* ((key (car entry))
             (bind-key (if (eq key help-char)
                           (logior key (ash 1 25))
                         key)))
        (local-set-key (vector bind-key)
          (lambda () (interactive)
            (repeatable-lite--switch-from-minibuffer key)))))))

(defun repeatable-lite--versatile-C-h ()
  "Dispatch to a help backend after \\`C-h' press in a prefix sequence.
Available backends are configured via `repeatable-lite-help-backends'."
  (interactive)
  (let* ((keys (this-command-keys-vector))
         (prefix (seq-take keys (1- (length keys))))
         (km (key-binding prefix 'accept-default))
         (prompt (concat
                  (mapconcat
                   (lambda (entry)
                     (format "%s (%s)" (nth 1 entry) (nth 2 entry)))
                   repeatable-lite-help-backends
                   ", ")
                  ":"))
         (key (read-key prompt))
         (backend (assq key repeatable-lite-help-backends)))
    (setq repeatable-lite--help-keymap km
          repeatable-lite--help-prefix prefix)
    (if backend
        (repeatable-lite--call-backend backend km prefix)
      (message "Invalid key"))))

(defun repeatable-lite--process-undefined (&optional ksv)
  "Handle undefined key sequence KSV during a repeatable loop."
  (let* ((ksv (or ksv (this-single-command-keys)))
         (last-key-vector (vector (aref ksv (1- (length ksv)))))
         (last-key (key-description last-key-vector)))
    (cond
     ((string= last-key "C-u")
      (setq current-prefix-arg
            (list (* 4 (or (car current-prefix-arg) 1))))
      (which-key-reload-key-sequence
       (vconcat
        (make-vector
         (cond
          ((equal (car current-prefix-arg) 4) 1)
          ((equal (car current-prefix-arg) 16) 2)
          ((equal (car current-prefix-arg) 64) 3)
          (t 4))
         21)
        (seq-take ksv (1- (length ksv))))))
     (t (repeatable-lite--kill-which-key)))))

(defun repeatable-lite--read-key-sequence ()
  "Read and dispatch key sequences during a repeatable loop."
  (let ((continue t))
    (while continue
      (setq continue nil)
      (let* ((ksv (read-key-sequence-vector nil))
             (last-key-vector (vector (aref ksv (1- (length ksv)))))
             (last-key (key-description last-key-vector))
             (key (key-description ksv))
             (local-binding (keymap-lookup nil key))
             (global-binding (keymap-lookup nil last-key)))
        (cond
         ((string= last-key "C-u") (repeatable-lite--process-undefined ksv))
         ((string= last-key "C-h") (funcall prefix-help-command))
         (local-binding
          (cond
           ((keymapp local-binding)
            ;; Sub-prefix: update which-key display and continue reading
            (if (get-buffer which-key-buffer-name)
                (progn
                  (which-key--create-buffer-and-show ksv)
                  (which-key-reload-key-sequence ksv)
                  (setq continue t))
              (repeatable-lite--kill-which-key ksv)))
           (t
            (unless (and (symbolp local-binding)
                         (string-prefix-p "repeatable-lite-wrap-" (symbol-name local-binding)))
              (repeatable-lite--kill-which-key))
            (call-interactively local-binding))))
         (global-binding
          (cond
           ((keymapp global-binding)
            (if (get-buffer which-key-buffer-name)
                (progn
                  (which-key--create-buffer-and-show last-key-vector global-binding)
                  (setq continue t))
              (repeatable-lite--kill-which-key last-key-vector)))
           (t
            (repeatable-lite--kill-which-key)
            (execute-kbd-macro last-key-vector))))
         ;; Some terminals send C-S-x when the user types C-x while a
         ;; repeatable prefix is active.  Replay it as plain C-x (code 24).
         ((string= last-key "C-S-x")
          (repeatable-lite--kill-which-key [24]))
         (t
          (message "No binding in local or global maps %s" key)
          (repeatable-lite--kill-which-key)))))))

;;;###autoload
(defmacro repeatable-lite-wrap (function)
  "Make FUNCTION repeatable within its prefix keymap.
After calling the wrapped command, the prefix keymap stays active
so you can press another key without re-typing the prefix.

FUNCTION must be a symbol naming an interactive command.

Usage:
  (define-key my-map \"h\" (repeatable-lite-wrap windmove-left))
  (define-key my-map \"l\" (repeatable-lite-wrap windmove-right))"
  `(defun ,(intern (format "repeatable-lite-wrap-%s" function)) ()
     (interactive)
     (let* ((keys (this-command-keys-vector))
            (prefix (or repeatable-lite-current-prefix
                        (seq-take keys (1- (length keys))))))
       (call-interactively ',function)
       (setq repeatable-lite-current-prefix nil)
       (setq current-prefix-arg nil)
       (which-key-reload-key-sequence prefix)
       (unless (bufferp (get-buffer which-key-buffer-name))
         (setq prefix-help-command 'repeatable-lite--versatile-C-h))
       (repeatable-lite--read-key-sequence))))

;;;###autoload
(define-minor-mode repeatable-lite-mode
  "Global minor mode enabling repeatable prefix key commands.
When enabled, advises `which-key-C-h-dispatch', `keyboard-quit',
and `undefined' so that the `repeatable-lite-wrap' macro can keep the
prefix keymap active after a command executes."
  :global t
  :group 'repeatable-lite
  :lighter nil
  (if repeatable-lite-mode
      (progn
        (advice-add 'which-key-C-h-dispatch :before #'repeatable-lite--which-key-settings)
        (advice-add #'keyboard-quit :before #'repeatable-lite--kill-which-key)
        (advice-add #'undefined :override #'repeatable-lite--process-undefined))
    (advice-remove 'which-key-C-h-dispatch #'repeatable-lite--which-key-settings)
    (advice-remove #'keyboard-quit #'repeatable-lite--kill-which-key)
    (advice-remove #'undefined #'repeatable-lite--process-undefined)))

(provide 'repeatable-lite)

;;; repeatable-lite.el ends here
