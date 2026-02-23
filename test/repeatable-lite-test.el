;;; repeatable-lite-test.el --- Tests for repeatable-lite -*- lexical-binding: t; -*-

;; Copyright (C) 2025 Charlie Holland

;;; Commentary:

;; ERT tests for repeatable-lite.

;;; Code:

(require 'ert)
(require 'repeatable-lite)


;;; A. Macro Expansion

(ert-deftest repeatable-lite-test-macro/creates-function ()
  "The ** macro should create a function named **<function>."
  (** ignore)
  (should (fboundp '**ignore)))

(ert-deftest repeatable-lite-test-macro/function-is-interactive ()
  "The ** macro generated function should be interactive."
  (** ignore)
  (should (commandp '**ignore)))

(ert-deftest repeatable-lite-test-macro/unique-names ()
  "Different functions should produce uniquely named wrappers."
  (** forward-char)
  (** backward-char)
  (should (fboundp '**forward-char))
  (should (fboundp '**backward-char))
  (should-not (eq (symbol-function '**forward-char)
                  (symbol-function '**backward-char))))

(ert-deftest repeatable-lite-test-macro/expansion-shape ()
  "The ** macro should expand to a defun form."
  (let ((expanded (macroexpand '(** some-command))))
    (should (eq (car expanded) 'defun))
    (should (eq (cadr expanded) '**some-command))))


;;; B. State Variables

(ert-deftest repeatable-lite-test-prefix-var/initial-nil ()
  "repeatable-current-prefix should start as nil."
  (let ((repeatable-current-prefix nil))
    (should (eq repeatable-current-prefix nil))))


;;; C. Kill Which-Key Cleanup

(ert-deftest repeatable-lite-test-kill-which-key/resets-persistent-popup ()
  "Killing which-key should set which-key-persistent-popup to t."
  (cl-letf (((symbol-function 'get-buffer) (lambda (_) nil))
            ((symbol-function 'which-key-mode) #'ignore)
            ((symbol-function 'cancel-timer) #'ignore))
    (let ((which-key-persistent-popup nil)
          (which-key--timer nil)
          (which-key-idle-delay 0.5)
          (which-key-idle-secondary-delay 0.5))
      (repeatable-lite--kill-which-key)
      (should (eq which-key-persistent-popup t)))))

(ert-deftest repeatable-lite-test-kill-which-key/resets-prefix-arg ()
  "Killing which-key should clear current-prefix-arg."
  (cl-letf (((symbol-function 'get-buffer) (lambda (_) nil))
            ((symbol-function 'which-key-mode) #'ignore)
            ((symbol-function 'cancel-timer) #'ignore))
    (let ((which-key-persistent-popup nil)
          (which-key--timer nil)
          (which-key-idle-delay 0.5)
          (which-key-idle-secondary-delay 0.5)
          (current-prefix-arg '(4)))
      (repeatable-lite--kill-which-key)
      (should (eq current-prefix-arg nil)))))

(ert-deftest repeatable-lite-test-kill-which-key/sets-idle-delay ()
  "Killing which-key should set idle delay to a large value."
  (cl-letf (((symbol-function 'get-buffer) (lambda (_) nil))
            ((symbol-function 'which-key-mode) #'ignore)
            ((symbol-function 'cancel-timer) #'ignore))
    (let ((which-key-persistent-popup nil)
          (which-key--timer nil)
          (which-key-idle-delay 0.5)
          (which-key-idle-secondary-delay 0.5))
      (repeatable-lite--kill-which-key)
      (should (= which-key-idle-delay 10000)))))

(ert-deftest repeatable-lite-test-kill-which-key/kills-buffer ()
  "Killing which-key should kill the which-key buffer if it exists."
  (let ((buf (get-buffer-create " *which-key*")))
    (cl-letf (((symbol-function 'which-key-mode) #'ignore)
              ((symbol-function 'cancel-timer) #'ignore))
      (let ((which-key-buffer-name " *which-key*")
            (which-key-persistent-popup nil)
            (which-key--timer nil)
            (which-key-idle-delay 0.5)
            (which-key-idle-secondary-delay 0.5))
        (repeatable-lite--kill-which-key)
        (should-not (buffer-live-p buf))))))


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


;;; E. Reload Key Sequence

(ert-deftest repeatable-lite-test-reload/sets-unread-events ()
  "Reloading a key sequence should populate unread-command-events."
  (let ((unread-command-events nil)
        (current-prefix-arg nil))
    (repeatable-lite--reload-key-sequence [?a ?b])
    (should (= (length unread-command-events) 2))
    (should (eq (cdr (nth 0 unread-command-events)) ?a))
    (should (eq (cdr (nth 1 unread-command-events)) ?b))))

(ert-deftest repeatable-lite-test-reload/preserves-prefix-arg ()
  "Reloading should set prefix-arg to current-prefix-arg."
  (let ((unread-command-events nil)
        (current-prefix-arg '(4))
        (prefix-arg nil))
    (repeatable-lite--reload-key-sequence [?x])
    (should (equal prefix-arg '(4)))))

(provide 'repeatable-lite-test)

;;; repeatable-lite-test.el ends here
