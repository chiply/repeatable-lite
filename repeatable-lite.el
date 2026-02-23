;;; repeatable-lite.el --- Repeatable prefix commands with which-key -*- lexical-binding: t; -*-

;; Copyright (C) 2025 Charlie Holland

;; Author: Charlie Holland <mister.chiply@gmail.com>
;; Maintainer: Charlie Holland <mister.chiply@gmail.com>
;; URL: https://github.com/chiply/repeatable-lite
;; x-release-please-start-version
;; Version: 0.1.2
;; x-release-please-end
;; Package-Requires: ((emacs "29.1") (which-key "3.5.0"))
;; Keywords: convenience, keys

;;; Commentary:

;; repeatable-lite provides a lightweight system for making prefix key commands
;; repeatable.  After executing a command within a prefix keymap, you stay in
;; that keymap and can immediately press another key to execute another command
;; without re-typing the prefix.
;;
;; The main entry point is the `**' macro, which wraps any interactive command
;; to make it repeatable within its prefix keymap.
;;
;; Example usage with general.el:
;;
;;   (general-define-key
;;    "C-c w h" (** windmove-left)
;;    "C-c w l" (** windmove-right)
;;    "C-c w j" (** windmove-down)
;;    "C-c w k" (** windmove-up))
;;
;; After pressing C-c w h to move left, you can press h/l/j/k repeatedly
;; without the C-c w prefix.  Press any key outside the keymap to exit.
;;
;; Which-key integration shows available keys while in the repeatable loop.

;;; Code:

(require 'seq)
(require 'which-key)

(defvar repeatable-lite-current-prefix nil
  "The current prefix key sequence during a repeatable loop.")

(defvar repeatable-lite--saved-idle-delay nil
  "Saved value of `which-key-idle-delay' before repeatable-lite modifies it.")

(defvar repeatable-lite--saved-idle-secondary-delay nil
  "Saved value of `which-key-idle-secondary-delay'.")

(defvar repeatable-lite--saved-persistent-popup nil
  "Saved value of `which-key-persistent-popup'.")

(defun repeatable-lite--which-key-settings ()
  "Configure which-key for repeatable display.
Saves the current which-key settings before modifying them."
  (setq repeatable-lite--saved-idle-delay which-key-idle-delay
        repeatable-lite--saved-idle-secondary-delay which-key-idle-secondary-delay
        repeatable-lite--saved-persistent-popup which-key-persistent-popup)
  (which-key-mode -1)
  (setq which-key-idle-delay 0.1)
  (setq which-key-idle-secondary-delay 0.1)
  (setq which-key-persistent-popup t)
  (which-key-mode +1))

(defun repeatable-lite--prefix-help (&optional key-seq)
  "Show which-key help for KEY-SEQ and read the next key."
  (interactive)
  (setq prefix-help-command 'which-key-C-h-dispatch)
  (which-key--create-buffer-and-show key-seq)
  (which-key-reload-key-sequence key-seq)
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
  (setq which-key-persistent-popup nil)
  (when (and (boundp 'which-key--timer) (timerp which-key--timer))
    (cancel-timer which-key--timer))
  (which-key-mode -1)
  (setq which-key-idle-delay (or repeatable-lite--saved-idle-delay 1.0)
        which-key-idle-secondary-delay (or repeatable-lite--saved-idle-secondary-delay 0.05)
        which-key-persistent-popup (or repeatable-lite--saved-persistent-popup nil))
  (which-key-mode +1)
  (setq prefix-help-command 'repeatable-lite--versatile-C-h)
  (setq current-prefix-arg nil))

(defun repeatable-lite--versatile-C-h ()
  "Handle C-h in a repeatable context with multiple dispatch options."
  (interactive)
  (let* ((keys (this-command-keys-vector))
         (prefix (seq-take keys (1- (length keys))))
         (key (read-key "C-h (which-key):")))
    (cond ((eq key ?\C-h) (repeatable-lite--prefix-help prefix))
          (t (message "Invalid key")))))

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
      (unless (condition-case nil
                  (string-match "^\\*" (symbol-name local-binding))
                (error nil))
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
(defmacro ** (function)
  "Make FUNCTION repeatable within its prefix keymap.
After calling the wrapped command, the prefix keymap stays active
so you can press another key without re-typing the prefix.

FUNCTION can be a symbol or a lambda.

Usage:
  (define-key my-map \"h\" (** windmove-left))
  (define-key my-map \"l\" (** windmove-right))"
  `(defun ,(intern (format "**%s" function)) ()
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
and `undefined' so that the `**' macro can keep the prefix keymap
active after a command executes."
  :global t
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
