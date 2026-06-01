;;; repeatable-lite-test.el --- Tests for repeatable-lite -*- lexical-binding: t; -*-

;; Copyright (C) 2025-2026 Charlie Holland

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
            ((symbol-function 'which-key--start-timer) #'ignore))
    (let ((which-key-persistent-popup nil)
          (which-key-idle-delay 0.5)
          (which-key-idle-secondary-delay 0.5)
          (repeatable-lite--saved-settings
           (list :idle-delay 0.5 :idle-secondary-delay 0.5
                 :persistent-popup t :echo-keystrokes 0)))
      (repeatable-lite--kill-which-key)
      (should (eq which-key-persistent-popup t)))))

(ert-deftest repeatable-lite-test-kill-which-key/resets-prefix-arg ()
  "Killing which-key should clear current-prefix-arg."
  (cl-letf (((symbol-function 'get-buffer) (lambda (_) nil))
            ((symbol-function 'which-key--start-timer) #'ignore))
    (let ((which-key-persistent-popup nil)
          (which-key-idle-delay 0.5)
          (which-key-idle-secondary-delay 0.5)
          (repeatable-lite--saved-settings
           (list :idle-delay 0.5 :idle-secondary-delay 0.5
                 :persistent-popup nil :echo-keystrokes 0))
          (current-prefix-arg '(4)))
      (repeatable-lite--kill-which-key)
      (should (eq current-prefix-arg nil)))))

(ert-deftest repeatable-lite-test-kill-which-key/sets-idle-delay ()
  "Killing which-key should restore saved idle delay."
  (cl-letf (((symbol-function 'get-buffer) (lambda (_) nil))
            ((symbol-function 'which-key--start-timer) #'ignore))
    (let ((which-key-persistent-popup nil)
          (which-key-idle-delay 0.5)
          (which-key-idle-secondary-delay 0.5)
          (repeatable-lite--saved-settings
           (list :idle-delay 0.8 :idle-secondary-delay 0.5
                 :persistent-popup nil :echo-keystrokes 0)))
      (repeatable-lite--kill-which-key)
      (should (= which-key-idle-delay 0.8)))))

(ert-deftest repeatable-lite-test-kill-which-key/kills-buffer ()
  "Killing which-key should kill the which-key buffer if it exists."
  (let ((buf (get-buffer-create " *which-key*")))
    (cl-letf (((symbol-function 'which-key--start-timer) #'ignore))
      (let ((which-key-buffer-name " *which-key*")
            (which-key-persistent-popup nil)
            (which-key-idle-delay 0.5)
            (which-key-idle-secondary-delay 0.5)
            (repeatable-lite--saved-settings nil))
        (repeatable-lite--kill-which-key)
        (should-not (buffer-live-p buf))))))


(ert-deftest repeatable-lite-test-kill-which-key/skips-restore-when-inactive ()
  "Killing which-key should not modify delays when saved-settings is nil."
  (cl-letf (((symbol-function 'get-buffer) (lambda (_) nil)))
    (let ((which-key-idle-delay 1000)
          (which-key-idle-secondary-delay 0.1)
          (which-key-persistent-popup nil)
          (repeatable-lite--saved-settings nil))
      (repeatable-lite--kill-which-key)
      (should (= which-key-idle-delay 1000))
      (should (= which-key-idle-secondary-delay 0.1)))))


;;; D. Process Undefined — C-u Prefix Handling

(ert-deftest repeatable-lite-test-process-undefined/c-u-sets-prefix ()
  "C-u during repeatable loop should accumulate prefix arg."
  (cl-letf (((symbol-function 'which-key-reload-key-sequence)
             #'ignore))
    (let ((current-prefix-arg nil))
      (repeatable-lite--process-undefined (vector ?h 21))
      (should (equal current-prefix-arg '(4))))))

(ert-deftest repeatable-lite-test-process-undefined/double-c-u ()
  "Double C-u should produce prefix arg (16)."
  (cl-letf (((symbol-function 'which-key-reload-key-sequence)
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


;;; F. Which-Key Settings Save/Restore

(ert-deftest repeatable-lite-test-settings/saves-on-first-call ()
  "First call to --which-key-settings should save current values."
  (cl-letf (((symbol-function 'which-key--start-timer) #'ignore))
    (let ((which-key-idle-delay 0.8)
          (which-key-idle-secondary-delay 0.7)
          (which-key-persistent-popup nil)
          (echo-keystrokes 0.5)
          (repeatable-lite--saved-settings nil))
      (repeatable-lite--which-key-settings)
      (should (equal (plist-get repeatable-lite--saved-settings :idle-delay) 0.8))
      (should (equal (plist-get repeatable-lite--saved-settings :idle-secondary-delay) 0.7))
      (should (eq (plist-get repeatable-lite--saved-settings :persistent-popup) nil))
      (should (equal (plist-get repeatable-lite--saved-settings :echo-keystrokes) 0.5)))))

(ert-deftest repeatable-lite-test-settings/does-not-overwrite-on-second-call ()
  "Second call should not overwrite the already-saved values."
  (cl-letf (((symbol-function 'which-key--start-timer) #'ignore))
    (let ((which-key-idle-delay 0.8)
          (which-key-idle-secondary-delay 0.7)
          (which-key-persistent-popup nil)
          (echo-keystrokes 0.5)
          (repeatable-lite--saved-settings nil))
      (repeatable-lite--which-key-settings)
      ;; Values are now modified; call again
      (repeatable-lite--which-key-settings)
      ;; Should still have original saved values, not 0.1
      (should (equal (plist-get repeatable-lite--saved-settings :idle-delay) 0.8)))))

(ert-deftest repeatable-lite-test-settings/modifies-which-key-vars ()
  "Calling --which-key-settings should set which-key vars for repeatable display."
  (cl-letf (((symbol-function 'which-key--start-timer) #'ignore))
    (let ((which-key-idle-delay 0.8)
          (which-key-idle-secondary-delay 0.7)
          (which-key-persistent-popup nil)
          (echo-keystrokes 0.5)
          (repeatable-lite--saved-settings nil))
      (repeatable-lite--which-key-settings)
      (should (= which-key-idle-delay 0.1))
      (should (= which-key-idle-secondary-delay 0.1))
      (should (eq which-key-persistent-popup t))
      (should (= echo-keystrokes 1000)))))


;;; G. Mode Activation

(ert-deftest repeatable-lite-test-mode/adds-advice-on-enable ()
  "Enabling the mode should add advice to key functions."
  (unwind-protect
      (progn
        (repeatable-lite-mode 1)
        (should (advice-member-p #'repeatable-lite--which-key-settings
                                 'which-key-C-h-dispatch))
        (should (advice-member-p #'repeatable-lite--kill-which-key
                                 #'keyboard-quit))
        (should (advice-member-p #'repeatable-lite--process-undefined
                                 #'undefined)))
    (repeatable-lite-mode -1)))

(ert-deftest repeatable-lite-test-mode/removes-advice-on-disable ()
  "Disabling the mode should remove advice from key functions."
  (repeatable-lite-mode 1)
  (repeatable-lite-mode -1)
  (should-not (advice-member-p #'repeatable-lite--which-key-settings
                               'which-key-C-h-dispatch))
  (should-not (advice-member-p #'repeatable-lite--kill-which-key
                               #'keyboard-quit))
  (should-not (advice-member-p #'repeatable-lite--process-undefined
                               #'undefined)))


;;; H. Read Key Sequence — Empty Guard

(ert-deftest repeatable-lite-test-read-key-sequence/empty-vector ()
  "Empty key sequence should call kill-which-key and exit loop."
  (let ((killed nil))
    (cl-letf (((symbol-function 'read-key-sequence-vector)
               (lambda (&rest _) []))
              ((symbol-function 'repeatable-lite--kill-which-key)
               (lambda (&rest _) (setq killed t))))
      (repeatable-lite--read-key-sequence)
      (should killed))))

(ert-deftest repeatable-lite-test-read-key-sequence/nil-vector ()
  "Nil key sequence should call kill-which-key and exit loop."
  (let ((killed nil))
    (cl-letf (((symbol-function 'read-key-sequence-vector)
               (lambda (&rest _) nil))
              ((symbol-function 'repeatable-lite--kill-which-key)
               (lambda (&rest _) (setq killed t))))
      (repeatable-lite--read-key-sequence)
      (should killed))))

;;; I. Read Key Sequence — Dispatch

(ert-deftest repeatable-lite-test-read-key-sequence/c-u-routes-to-process-undefined ()
  "A trailing C-u should be routed to --process-undefined with the key vector."
  (let ((captured 'none))
    (cl-letf (((symbol-function 'read-key-sequence-vector)
               (lambda (&rest _) (vector ?\C-u)))
              ((symbol-function 'repeatable-lite--process-undefined)
               (lambda (ksv) (setq captured ksv))))
      (repeatable-lite--read-key-sequence)
      (should (equal captured (vector ?\C-u))))))

(ert-deftest repeatable-lite-test-read-key-sequence/c-h-invokes-prefix-help-command ()
  "A trailing C-h should invoke `prefix-help-command'."
  (let ((called nil))
    (cl-letf (((symbol-function 'read-key-sequence-vector)
               (lambda (&rest _) (vector ?\C-h))))
      (let ((prefix-help-command (lambda () (setq called t))))
        (repeatable-lite--read-key-sequence))
      (should called))))

(ert-deftest repeatable-lite-test-read-key-sequence/plain-command-kills-then-runs ()
  "A bound non-wrapper command should dismiss the popup, then run."
  (let ((killed nil) (ran nil))
    (cl-letf (((symbol-function 'read-key-sequence-vector)
               (lambda (&rest _) (vector ?z)))
              ((symbol-function 'keymap-lookup)
               (lambda (_map key &rest _)
                 (when (string= key "z") 'some-plain-command)))
              ((symbol-function 'repeatable-lite--kill-which-key)
               (lambda (&rest _) (setq killed t)))
              ((symbol-function 'call-interactively)
               (lambda (cmd &rest _) (setq ran cmd))))
      (repeatable-lite--read-key-sequence)
      (should killed)
      (should (eq ran 'some-plain-command)))))

(ert-deftest repeatable-lite-test-read-key-sequence/wrapped-command-preserves-popup ()
  "A repeatable-lite-wrap command should run WITHOUT dismissing the popup."
  (let ((killed nil) (ran nil))
    (cl-letf (((symbol-function 'read-key-sequence-vector)
               (lambda (&rest _) (vector ?z)))
              ((symbol-function 'keymap-lookup)
               (lambda (_map key &rest _)
                 (when (string= key "z") 'repeatable-lite-wrap-foo)))
              ((symbol-function 'repeatable-lite--kill-which-key)
               (lambda (&rest _) (setq killed t)))
              ((symbol-function 'call-interactively)
               (lambda (cmd &rest _) (setq ran cmd))))
      (repeatable-lite--read-key-sequence)
      (should-not killed)
      (should (eq ran 'repeatable-lite-wrap-foo)))))

(ert-deftest repeatable-lite-test-read-key-sequence/unbound-key-exits ()
  "An unbound key should kill which-key and exit the loop."
  (let ((killed nil))
    (cl-letf (((symbol-function 'read-key-sequence-vector)
               (lambda (&rest _) (vector ?z)))
              ((symbol-function 'keymap-lookup) (lambda (&rest _) nil))
              ((symbol-function 'message) (lambda (&rest _) nil))
              ((symbol-function 'repeatable-lite--kill-which-key)
               (lambda (&rest _) (setq killed t))))
      (repeatable-lite--read-key-sequence)
      (should killed))))

(ert-deftest repeatable-lite-test-read-key-sequence/nested-keymap-no-popup-replays ()
  "Descending into a nested prefix with no live popup should kill+replay and exit."
  (let ((replay 'none))
    (cl-letf (((symbol-function 'read-key-sequence-vector)
               (lambda (&rest _) (vector ?x)))
              ((symbol-function 'keymap-lookup)
               (lambda (_map key &rest _)
                 (when (string= key "x") (make-sparse-keymap))))
              ((symbol-function 'repeatable-lite--popup-live-p) (lambda () nil))
              ((symbol-function 'repeatable-lite--kill-which-key)
               (lambda (&optional r) (setq replay r))))
      (repeatable-lite--read-key-sequence)
      (should (equal replay (vector ?x))))))

(ert-deftest repeatable-lite-test-read-key-sequence/nested-keymap-with-popup-continues ()
  "Descending into a nested prefix with a live popup should show it and loop."
  (let ((shown nil) (n 0))
    (cl-letf (((symbol-function 'read-key-sequence-vector)
               (lambda (&rest _)
                 (setq n (1+ n))
                 (if (= n 1) (vector ?x) [])))
              ((symbol-function 'keymap-lookup)
               (lambda (_map key &rest _)
                 (when (string= key "x") (make-sparse-keymap))))
              ((symbol-function 'repeatable-lite--popup-live-p) (lambda () t))
              ((symbol-function 'which-key--create-buffer-and-show)
               (lambda (&rest _) (setq shown t)))
              ((symbol-function 'which-key-reload-key-sequence) #'ignore)
              ((symbol-function 'repeatable-lite--kill-which-key) #'ignore))
      (repeatable-lite--read-key-sequence)
      (should shown)
      (should (= n 2)))))

(ert-deftest repeatable-lite-test-wrapped-command-p/recognizes-wrappers ()
  "--wrapped-command-p should match only repeatable-lite-wrap- symbols."
  (should (repeatable-lite--wrapped-command-p 'repeatable-lite-wrap-foo))
  (should-not (repeatable-lite--wrapped-command-p 'foo))
  (should-not (repeatable-lite--wrapped-command-p "repeatable-lite-wrap-foo"))
  (should-not (repeatable-lite--wrapped-command-p nil)))

(provide 'repeatable-lite-test)

;;; repeatable-lite-test.el ends here
