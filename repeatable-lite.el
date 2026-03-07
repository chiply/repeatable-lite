;;; repeatable-lite.el --- Repeatable prefix commands with which-key -*- lexical-binding: t; -*-

;; Copyright (C) 2025 Charlie Holland

;; Author: Charlie Holland <mister.chiply@gmail.com>
;; Maintainer: Charlie Holland <mister.chiply@gmail.com>
;; URL: https://github.com/chiply/repeatable-lite
;; x-release-please-start-version
;; Version: 0.2.3
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

(defgroup repeatable-lite nil
  "Repeatable prefix commands with which-key."
  :group 'convenience
  :prefix "repeatable-lite-")

(defvar repeatable-lite-current-prefix nil
  "The current prefix key sequence during a repeatable loop.")

(defvar repeatable-lite--saved-idle-delay nil
  "Saved value of `which-key-idle-delay' before repeatable-lite modifies it.")

(defvar repeatable-lite--saved-idle-secondary-delay nil
  "Saved value of `which-key-idle-secondary-delay'.")

(defvar repeatable-lite--saved-persistent-popup nil
  "Saved value of `which-key-persistent-popup'.")

(defvar repeatable-lite--active nil
  "Non-nil when a repeatable loop has modified which-key settings.")

(defcustom repeatable-lite-help-backends
  '((?\C-h "C-h" "which-key" repeatable-lite--prefix-help))
  "Alist of help backends for `repeatable-lite--versatile-C-h'.
Each entry is (KEY KEY-LABEL DESCRIPTION HANDLER).
KEY is the character to match after the initial C-h press.
KEY-LABEL is the display string for the key.
DESCRIPTION names the backend.
HANDLER is called with two arguments: KEYMAP and PREFIX."
  :type '(repeat (list character string string function))
  :group 'repeatable-lite)

(defun repeatable-lite--restart-which-key-timer ()
  "Restart the which-key idle timer with current delay settings.
Avoids toggling `which-key-mode' which has side effects like
resetting `prefix-help-command'."
  (when (and (boundp 'which-key--timer) (timerp which-key--timer))
    (cancel-timer which-key--timer))
  (setq which-key--timer
        (run-with-idle-timer which-key-idle-delay t #'which-key--update)))

(defun repeatable-lite--which-key-settings ()
  "Configure which-key for repeatable display.
Saves the current which-key settings before modifying them."
  (unless repeatable-lite--active
    (setq repeatable-lite--saved-idle-delay which-key-idle-delay
          repeatable-lite--saved-idle-secondary-delay which-key-idle-secondary-delay
          repeatable-lite--saved-persistent-popup which-key-persistent-popup
          repeatable-lite--active t))
  (setq which-key-idle-delay 0.1
        which-key-idle-secondary-delay 0.1
        which-key-persistent-popup t)
  (repeatable-lite--restart-which-key-timer))

(defun repeatable-lite--prefix-help (_keymap prefix)
  "Show which-key help for PREFIX and read the next key.
KEYMAP is ignored; PREFIX is the key sequence to display bindings for."
  (interactive)
  (setq prefix-help-command 'which-key-C-h-dispatch)
  (which-key--create-buffer-and-show prefix)
  (which-key-reload-key-sequence prefix)
  (repeatable-lite--read-key-sequence))

(defun repeatable-lite--reload-key-sequence (key-seq)
  "Reload KEY-SEQ into the command loop."
  (let ((next-event (mapcar (lambda (ev) (cons t ev)) key-seq)))
    (setq prefix-arg current-prefix-arg
          unread-command-events next-event)))

(defun repeatable-lite--kill-which-key ()
  "Kill the which-key buffer and restore original which-key state."
  (interactive)
  (let ((buf (get-buffer which-key-buffer-name)))
    (when (bufferp buf) (kill-buffer buf)))
  (when repeatable-lite--active
    (setq which-key-idle-delay repeatable-lite--saved-idle-delay
          which-key-idle-secondary-delay repeatable-lite--saved-idle-secondary-delay
          which-key-persistent-popup repeatable-lite--saved-persistent-popup
          repeatable-lite--active nil)
    (repeatable-lite--restart-which-key-timer))
  (setq prefix-help-command 'repeatable-lite--versatile-C-h)
  (setq current-prefix-arg nil))

(defun repeatable-lite--versatile-C-h ()
  "Dispatch to a help backend after \\`C-h' in a prefix sequence.
Available backends are configured via `repeatable-lite-help-backends'."
  (interactive)
  (let* ((keys (this-command-keys-vector))
         (prefix (seq-take keys (1- (length keys))))
         (orig-km (key-binding prefix 'accept-default))
         (km (when orig-km (copy-keymap orig-km)))
         (prompt (concat
                  (mapconcat
                   (lambda (entry)
                     (format "%s (%s)" (nth 1 entry) (nth 2 entry)))
                   repeatable-lite-help-backends
                   ", ")
                  ":"))
         (key (read-key prompt))
         (backend (assq key repeatable-lite-help-backends)))
    (if backend
        (funcall (nth 3 backend) km prefix)
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
      (repeatable-lite--reload-key-sequence
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
  "Read and dispatch a key sequence during a repeatable loop."
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
      (unless (and (symbolp local-binding)
                   (string-prefix-p "repeatable-lite-wrap-" (symbol-name local-binding)))
        (repeatable-lite--kill-which-key))
      (call-interactively local-binding))
     (global-binding
      (cond
       ((keymapp global-binding)
        (repeatable-lite--kill-which-key)
        (repeatable-lite--reload-key-sequence last-key-vector)
        (setq prefix-help-command 'repeatable-lite--versatile-C-h))
       (t
        (repeatable-lite--kill-which-key)
        (execute-kbd-macro last-key-vector)
        (setq prefix-help-command 'repeatable-lite--versatile-C-h))))
     ((string= last-key "C-S-x")
      (repeatable-lite--kill-which-key)
      (repeatable-lite--reload-key-sequence [24])
      (setq prefix-help-command 'repeatable-lite--versatile-C-h))
     (t
      (message "No binding in local or global maps %s" key)
      (repeatable-lite--kill-which-key)))))

;;;###autoload
(defmacro repeatable-lite-wrap (function)
  "Make FUNCTION repeatable within its prefix keymap.
After calling the wrapped command, the prefix keymap stays active
so you can press another key without re-typing the prefix.

FUNCTION can be a symbol or a lambda.

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
       (repeatable-lite--reload-key-sequence prefix)
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
