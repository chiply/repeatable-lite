;;; repeatable-lite-test.el --- Tests for repeatable-lite -*- lexical-binding: t; -*-

;; Copyright (C) 2025 Charlie Holland

;;; Commentary:

;; ERT tests for repeatable-lite.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'repeatable-lite)


;;; A. Macro Expansion

(ert-deftest repeatable-lite-test-macro/creates-function ()
  "The repeatable-lite-wrap macro should create a function named repeatable-lite-wrap-<function>."
  (repeatable-lite-wrap ignore)
  (should (fboundp 'repeatable-lite-wrap-ignore)))

(ert-deftest repeatable-lite-test-macro/function-is-interactive ()
  "The repeatable-lite-wrap macro generated function should be interactive."
  (repeatable-lite-wrap ignore)
  (should (commandp 'repeatable-lite-wrap-ignore)))

(ert-deftest repeatable-lite-test-macro/unique-names ()
  "Different functions should produce uniquely named wrappers."
  (repeatable-lite-wrap forward-char)
  (repeatable-lite-wrap backward-char)
  (should (fboundp 'repeatable-lite-wrap-forward-char))
  (should (fboundp 'repeatable-lite-wrap-backward-char))
  (should-not (eq (symbol-function 'repeatable-lite-wrap-forward-char)
                  (symbol-function 'repeatable-lite-wrap-backward-char))))

(ert-deftest repeatable-lite-test-macro/expansion-shape ()
  "The repeatable-lite-wrap macro should expand to a defalias form (defun expands to defalias)."
  (let ((expanded (macroexpand '(repeatable-lite-wrap some-command))))
    (should (eq (car expanded) 'defalias))))


;;; B. State Variables

(ert-deftest repeatable-lite-test-prefix-var/initial-nil ()
  "repeatable-lite-current-prefix should start as nil."
  (let ((repeatable-lite-current-prefix nil))
    (should (eq repeatable-lite-current-prefix nil))))


;;; C. Kill Which-Key Cleanup

(ert-deftest repeatable-lite-test-kill-which-key/resets-persistent-popup ()
  "Killing which-key should restore saved which-key-persistent-popup."
  (cl-letf (((symbol-function 'get-buffer) (lambda (_) nil))
            ((symbol-function 'repeatable-lite--restart-which-key-timer) #'ignore))
    (let ((which-key-persistent-popup nil)
          (which-key-idle-delay 0.5)
          (which-key-idle-secondary-delay 0.5)
          (repeatable-lite--active t)
          (repeatable-lite--saved-persistent-popup t))
      (repeatable-lite--kill-which-key)
      (should (eq which-key-persistent-popup t)))))

(ert-deftest repeatable-lite-test-kill-which-key/resets-prefix-arg ()
  "Killing which-key should clear current-prefix-arg."
  (cl-letf (((symbol-function 'get-buffer) (lambda (_) nil))
            ((symbol-function 'repeatable-lite--restart-which-key-timer) #'ignore))
    (let ((which-key-persistent-popup nil)
          (which-key-idle-delay 0.5)
          (which-key-idle-secondary-delay 0.5)
          (repeatable-lite--active t)
          (current-prefix-arg '(4)))
      (repeatable-lite--kill-which-key)
      (should (eq current-prefix-arg nil)))))

(ert-deftest repeatable-lite-test-kill-which-key/sets-idle-delay ()
  "Killing which-key should restore saved idle delay."
  (cl-letf (((symbol-function 'get-buffer) (lambda (_) nil))
            ((symbol-function 'repeatable-lite--restart-which-key-timer) #'ignore))
    (let ((which-key-persistent-popup nil)
          (which-key-idle-delay 0.5)
          (which-key-idle-secondary-delay 0.5)
          (repeatable-lite--active t)
          (repeatable-lite--saved-idle-delay 0.8))
      (repeatable-lite--kill-which-key)
      (should (= which-key-idle-delay 0.8)))))

(ert-deftest repeatable-lite-test-kill-which-key/kills-buffer ()
  "Killing which-key should kill the which-key buffer if it exists."
  (let ((buf (get-buffer-create " *which-key*")))
    (cl-letf (((symbol-function 'repeatable-lite--restart-which-key-timer) #'ignore))
      (let ((which-key-buffer-name " *which-key*")
            (which-key-persistent-popup nil)
            (which-key-idle-delay 0.5)
            (which-key-idle-secondary-delay 0.5)
            (repeatable-lite--active nil))
        (repeatable-lite--kill-which-key)
        (should-not (buffer-live-p buf))))))


(ert-deftest repeatable-lite-test-kill-which-key/skips-restore-when-inactive ()
  "Killing which-key should not modify delays when --active is nil."
  (cl-letf (((symbol-function 'get-buffer) (lambda (_) nil)))
    (let ((which-key-idle-delay 1000)
          (which-key-idle-secondary-delay 0.1)
          (which-key-persistent-popup nil)
          (repeatable-lite--active nil)
          (repeatable-lite--saved-idle-delay 0.8))
      (repeatable-lite--kill-which-key)
      (should (= which-key-idle-delay 1000))
      (should (= which-key-idle-secondary-delay 0.1)))))


;;; D. Process Undefined — C-u Prefix Handling

(ert-deftest repeatable-lite-test-process-undefined/c-u-sets-prefix ()
  "C-u during repeatable loop should accumulate prefix arg."
  (cl-letf (((symbol-function 'repeatable-lite--reload-key-sequence)
             #'ignore))
    (let ((current-prefix-arg nil))
      ;; Simulate a key sequence ending with C-u (code 21) prefixed by some key
      (repeatable-lite--process-undefined (vector ?h 21))
      (should (equal current-prefix-arg '(4))))))

(ert-deftest repeatable-lite-test-process-undefined/double-c-u ()
  "Double C-u should produce prefix arg (16)."
  (cl-letf (((symbol-function 'repeatable-lite--reload-key-sequence)
             #'ignore))
    (let ((current-prefix-arg '(4)))
      (repeatable-lite--process-undefined (vector ?h 21))
      (should (equal current-prefix-arg '(16))))))


;;; E. Reload Key Sequence (via which-key-reload-key-sequence)

(ert-deftest repeatable-lite-test-reload/sets-unread-events ()
  "Reloading a key sequence should populate unread-command-events."
  (let ((unread-command-events nil)
        (current-prefix-arg nil))
    (which-key-reload-key-sequence [?a ?b])
    (should (= (length unread-command-events) 2))
    (should (eq (cdr (nth 0 unread-command-events)) ?a))
    (should (eq (cdr (nth 1 unread-command-events)) ?b))))

(ert-deftest repeatable-lite-test-reload/preserves-prefix-arg ()
  "Reloading should set prefix-arg to current-prefix-arg."
  (let ((unread-command-events nil)
        (current-prefix-arg '(4))
        (prefix-arg nil))
    (which-key-reload-key-sequence [?x])
    (should (equal prefix-arg '(4)))))

(provide 'repeatable-lite-test)

;;; repeatable-lite-test.el ends here
