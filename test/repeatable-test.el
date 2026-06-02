;;; repeatable-test.el --- Tests for repeatable -*- lexical-binding: t; -*-

;; Copyright (C) 2025-2026 Charlie Holland

;;; Commentary:

;; ERT tests for repeatable.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'repeatable)


;;; A. Macro Expansion

(ert-deftest repeatable-test-macro/creates-function ()
  "The repeatable-wrap macro should create a function named repeatable-wrap-<function>."
  (repeatable-wrap ignore)
  (should (fboundp 'repeatable-wrap-ignore)))

(ert-deftest repeatable-test-macro/function-is-interactive ()
  "The repeatable-wrap macro generated function should be interactive."
  (repeatable-wrap ignore)
  (should (commandp 'repeatable-wrap-ignore)))

(ert-deftest repeatable-test-macro/unique-names ()
  "Different functions should produce uniquely named wrappers."
  (repeatable-wrap forward-char)
  (repeatable-wrap backward-char)
  (should (fboundp 'repeatable-wrap-forward-char))
  (should (fboundp 'repeatable-wrap-backward-char))
  (should-not (eq (symbol-function 'repeatable-wrap-forward-char)
                  (symbol-function 'repeatable-wrap-backward-char))))

(ert-deftest repeatable-test-macro/expansion-shape ()
  "The repeatable-wrap macro should expand to a defalias form (defun expands to defalias)."
  (let ((expanded (macroexpand '(repeatable-wrap some-command))))
    (should (eq (car expanded) 'defalias))))


;;; B. State Variables

(ert-deftest repeatable-test-prefix-var/initial-nil ()
  "repeatable-current-prefix should start as nil."
  (let ((repeatable-current-prefix nil))
    (should (eq repeatable-current-prefix nil))))


;;; C. Kill Which-Key Cleanup

(ert-deftest repeatable-test-kill-which-key/resets-persistent-popup ()
  "Killing which-key should restore saved which-key-persistent-popup."
  (cl-letf (((symbol-function 'get-buffer) (lambda (_) nil))
            ((symbol-function 'which-key--start-timer) #'ignore))
    (let ((which-key-persistent-popup nil)
          (which-key-idle-delay 0.5)
          (which-key-idle-secondary-delay 0.5)
          (repeatable--saved-settings
           (list :idle-delay 0.5 :idle-secondary-delay 0.5
                 :persistent-popup t :echo-keystrokes 0)))
      (repeatable--kill-which-key)
      (should (eq which-key-persistent-popup t)))))

(ert-deftest repeatable-test-kill-which-key/resets-prefix-arg ()
  "Killing which-key should clear current-prefix-arg."
  (cl-letf (((symbol-function 'get-buffer) (lambda (_) nil))
            ((symbol-function 'which-key--start-timer) #'ignore))
    (let ((which-key-persistent-popup nil)
          (which-key-idle-delay 0.5)
          (which-key-idle-secondary-delay 0.5)
          (repeatable--saved-settings
           (list :idle-delay 0.5 :idle-secondary-delay 0.5
                 :persistent-popup nil :echo-keystrokes 0))
          (current-prefix-arg '(4)))
      (repeatable--kill-which-key)
      (should (eq current-prefix-arg nil)))))

(ert-deftest repeatable-test-kill-which-key/sets-idle-delay ()
  "Killing which-key should restore saved idle delay."
  (cl-letf (((symbol-function 'get-buffer) (lambda (_) nil))
            ((symbol-function 'which-key--start-timer) #'ignore))
    (let ((which-key-persistent-popup nil)
          (which-key-idle-delay 0.5)
          (which-key-idle-secondary-delay 0.5)
          (repeatable--saved-settings
           (list :idle-delay 0.8 :idle-secondary-delay 0.5
                 :persistent-popup nil :echo-keystrokes 0)))
      (repeatable--kill-which-key)
      (should (= which-key-idle-delay 0.8)))))

(ert-deftest repeatable-test-kill-which-key/kills-buffer ()
  "Killing which-key should kill the which-key buffer if it exists."
  (let ((buf (get-buffer-create " *which-key*")))
    (cl-letf (((symbol-function 'which-key--start-timer) #'ignore))
      (let ((which-key-buffer-name " *which-key*")
            (which-key-persistent-popup nil)
            (which-key-idle-delay 0.5)
            (which-key-idle-secondary-delay 0.5)
            (repeatable--saved-settings nil))
        (repeatable--kill-which-key)
        (should-not (buffer-live-p buf))))))


(ert-deftest repeatable-test-kill-which-key/skips-restore-when-inactive ()
  "Killing which-key should not modify delays when saved-settings is nil."
  (cl-letf (((symbol-function 'get-buffer) (lambda (_) nil)))
    (let ((which-key-idle-delay 1000)
          (which-key-idle-secondary-delay 0.1)
          (which-key-persistent-popup nil)
          (repeatable--saved-settings nil))
      (repeatable--kill-which-key)
      (should (= which-key-idle-delay 1000))
      (should (= which-key-idle-secondary-delay 0.1)))))


;;; D. Process Undefined — C-u Prefix Handling

(ert-deftest repeatable-test-process-undefined/c-u-sets-prefix ()
  "C-u during repeatable loop should accumulate prefix arg."
  (cl-letf (((symbol-function 'which-key-reload-key-sequence)
             #'ignore))
    (let ((current-prefix-arg nil))
      (repeatable--process-undefined (vector ?h 21))
      (should (equal current-prefix-arg '(4))))))

(ert-deftest repeatable-test-process-undefined/double-c-u ()
  "Double C-u should produce prefix arg (16)."
  (cl-letf (((symbol-function 'which-key-reload-key-sequence)
             #'ignore))
    (let ((current-prefix-arg '(4)))
      (repeatable--process-undefined (vector ?h 21))
      (should (equal current-prefix-arg '(16))))))


;;; E. Reload Key Sequence (via which-key-reload-key-sequence)

(ert-deftest repeatable-test-reload/sets-unread-events ()
  "Reloading a key sequence should populate unread-command-events."
  (let ((unread-command-events nil)
        (current-prefix-arg nil))
    (which-key-reload-key-sequence [?a ?b])
    (should (= (length unread-command-events) 2))
    (should (eq (cdr (nth 0 unread-command-events)) ?a))
    (should (eq (cdr (nth 1 unread-command-events)) ?b))))

(ert-deftest repeatable-test-reload/preserves-prefix-arg ()
  "Reloading should set prefix-arg to current-prefix-arg."
  (let ((unread-command-events nil)
        (current-prefix-arg '(4))
        (prefix-arg nil))
    (which-key-reload-key-sequence [?x])
    (should (equal prefix-arg '(4)))))


;;; F. Which-Key Settings Save/Restore

(ert-deftest repeatable-test-settings/saves-on-first-call ()
  "First call to --which-key-settings should save current values."
  (cl-letf (((symbol-function 'which-key--start-timer) #'ignore))
    (let ((which-key-idle-delay 0.8)
          (which-key-idle-secondary-delay 0.7)
          (which-key-persistent-popup nil)
          (echo-keystrokes 0.5)
          (repeatable--saved-settings nil))
      (repeatable--which-key-settings)
      (should (equal (plist-get repeatable--saved-settings :idle-delay) 0.8))
      (should (equal (plist-get repeatable--saved-settings :idle-secondary-delay) 0.7))
      (should (eq (plist-get repeatable--saved-settings :persistent-popup) nil))
      (should (equal (plist-get repeatable--saved-settings :echo-keystrokes) 0.5)))))

(ert-deftest repeatable-test-settings/does-not-overwrite-on-second-call ()
  "Second call should not overwrite the already-saved values."
  (cl-letf (((symbol-function 'which-key--start-timer) #'ignore))
    (let ((which-key-idle-delay 0.8)
          (which-key-idle-secondary-delay 0.7)
          (which-key-persistent-popup nil)
          (echo-keystrokes 0.5)
          (repeatable--saved-settings nil))
      (repeatable--which-key-settings)
      ;; Values are now modified; call again
      (repeatable--which-key-settings)
      ;; Should still have original saved values, not 0.1
      (should (equal (plist-get repeatable--saved-settings :idle-delay) 0.8)))))

(ert-deftest repeatable-test-settings/modifies-which-key-vars ()
  "Calling --which-key-settings should set which-key vars for repeatable display."
  (cl-letf (((symbol-function 'which-key--start-timer) #'ignore))
    (let ((which-key-idle-delay 0.8)
          (which-key-idle-secondary-delay 0.7)
          (which-key-persistent-popup nil)
          (echo-keystrokes 0.5)
          (repeatable--saved-settings nil))
      (repeatable--which-key-settings)
      (should (= which-key-idle-delay 0.1))
      (should (= which-key-idle-secondary-delay 0.1))
      (should (eq which-key-persistent-popup t))
      (should (= echo-keystrokes 1000)))))


;;; G. Mode Activation

(ert-deftest repeatable-test-mode/adds-advice-on-enable ()
  "Enabling the mode should add advice to key functions."
  (unwind-protect
      (progn
        (repeatable-mode 1)
        (should (advice-member-p #'repeatable--which-key-settings
                                 'which-key-C-h-dispatch))
        (should (advice-member-p #'repeatable--kill-which-key
                                 #'keyboard-quit))
        (should (advice-member-p #'repeatable--process-undefined
                                 #'undefined)))
    (repeatable-mode -1)))

(ert-deftest repeatable-test-mode/removes-advice-on-disable ()
  "Disabling the mode should remove advice from key functions."
  (repeatable-mode 1)
  (repeatable-mode -1)
  (should-not (advice-member-p #'repeatable--which-key-settings
                               'which-key-C-h-dispatch))
  (should-not (advice-member-p #'repeatable--kill-which-key
                               #'keyboard-quit))
  (should-not (advice-member-p #'repeatable--process-undefined
                               #'undefined)))


;;; H. Read Key Sequence — Empty Guard

(ert-deftest repeatable-test-read-key-sequence/empty-vector ()
  "Empty key sequence should call kill-which-key and exit loop."
  (let ((killed nil))
    (cl-letf (((symbol-function 'read-key-sequence-vector)
               (lambda (&rest _) []))
              ((symbol-function 'repeatable--kill-which-key)
               (lambda (&rest _) (setq killed t))))
      (repeatable--read-key-sequence)
      (should killed))))

(ert-deftest repeatable-test-read-key-sequence/nil-vector ()
  "Nil key sequence should call kill-which-key and exit loop."
  (let ((killed nil))
    (cl-letf (((symbol-function 'read-key-sequence-vector)
               (lambda (&rest _) nil))
              ((symbol-function 'repeatable--kill-which-key)
               (lambda (&rest _) (setq killed t))))
      (repeatable--read-key-sequence)
      (should killed))))

;;; I. Read Key Sequence — Dispatch

(ert-deftest repeatable-test-read-key-sequence/c-u-routes-to-process-undefined ()
  "A trailing C-u should be routed to --process-undefined with the key vector."
  (let ((captured 'none))
    (cl-letf (((symbol-function 'read-key-sequence-vector)
               (lambda (&rest _) (vector ?\C-u)))
              ((symbol-function 'repeatable--process-undefined)
               (lambda (ksv) (setq captured ksv))))
      (repeatable--read-key-sequence)
      (should (equal captured (vector ?\C-u))))))

(ert-deftest repeatable-test-read-key-sequence/c-h-invokes-prefix-help-command ()
  "A trailing C-h should invoke `prefix-help-command'."
  (let ((called nil))
    (cl-letf (((symbol-function 'read-key-sequence-vector)
               (lambda (&rest _) (vector ?\C-h))))
      (let ((prefix-help-command (lambda () (setq called t))))
        (repeatable--read-key-sequence))
      (should called))))

(ert-deftest repeatable-test-read-key-sequence/plain-command-kills-then-runs ()
  "A bound non-wrapper command should dismiss the popup, then run."
  (let ((killed nil) (ran nil))
    (cl-letf (((symbol-function 'read-key-sequence-vector)
               (lambda (&rest _) (vector ?z)))
              ((symbol-function 'keymap-lookup)
               (lambda (_map key &rest _)
                 (when (string= key "z") 'some-plain-command)))
              ((symbol-function 'repeatable--kill-which-key)
               (lambda (&rest _) (setq killed t)))
              ((symbol-function 'call-interactively)
               (lambda (cmd &rest _) (setq ran cmd))))
      (repeatable--read-key-sequence)
      (should killed)
      (should (eq ran 'some-plain-command)))))

(ert-deftest repeatable-test-read-key-sequence/wrapped-command-preserves-popup ()
  "A repeatable-wrap command should run WITHOUT dismissing the popup."
  (let ((killed nil) (ran nil))
    (cl-letf (((symbol-function 'read-key-sequence-vector)
               (lambda (&rest _) (vector ?z)))
              ((symbol-function 'keymap-lookup)
               (lambda (_map key &rest _)
                 (when (string= key "z") 'repeatable-wrap-foo)))
              ((symbol-function 'repeatable--kill-which-key)
               (lambda (&rest _) (setq killed t)))
              ((symbol-function 'call-interactively)
               (lambda (cmd &rest _) (setq ran cmd))))
      (repeatable--read-key-sequence)
      (should-not killed)
      (should (eq ran 'repeatable-wrap-foo)))))

(ert-deftest repeatable-test-read-key-sequence/unbound-key-exits ()
  "An unbound key should kill which-key and exit the loop."
  (let ((killed nil))
    (cl-letf (((symbol-function 'read-key-sequence-vector)
               (lambda (&rest _) (vector ?z)))
              ((symbol-function 'keymap-lookup) (lambda (&rest _) nil))
              ((symbol-function 'message) (lambda (&rest _) nil))
              ((symbol-function 'repeatable--kill-which-key)
               (lambda (&rest _) (setq killed t))))
      (repeatable--read-key-sequence)
      (should killed))))

(ert-deftest repeatable-test-read-key-sequence/nested-keymap-no-popup-replays ()
  "Descending into a nested prefix with no live popup should kill+replay and exit."
  (let ((replay 'none))
    (cl-letf (((symbol-function 'read-key-sequence-vector)
               (lambda (&rest _) (vector ?x)))
              ((symbol-function 'keymap-lookup)
               (lambda (_map key &rest _)
                 (when (string= key "x") (make-sparse-keymap))))
              ((symbol-function 'repeatable--popup-live-p) (lambda () nil))
              ((symbol-function 'repeatable--kill-which-key)
               (lambda (&optional r) (setq replay r))))
      (repeatable--read-key-sequence)
      (should (equal replay (vector ?x))))))

(ert-deftest repeatable-test-read-key-sequence/nested-keymap-with-popup-continues ()
  "Descending into a nested prefix with a live popup should show it and loop."
  (let ((shown nil) (n 0))
    (cl-letf (((symbol-function 'read-key-sequence-vector)
               (lambda (&rest _)
                 (setq n (1+ n))
                 (if (= n 1) (vector ?x) [])))
              ((symbol-function 'keymap-lookup)
               (lambda (_map key &rest _)
                 (when (string= key "x") (make-sparse-keymap))))
              ((symbol-function 'repeatable--popup-live-p) (lambda () t))
              ((symbol-function 'which-key--create-buffer-and-show)
               (lambda (&rest _) (setq shown t)))
              ((symbol-function 'which-key-reload-key-sequence) #'ignore)
              ((symbol-function 'repeatable--kill-which-key) #'ignore))
      (repeatable--read-key-sequence)
      (should shown)
      (should (= n 2)))))

(ert-deftest repeatable-test-wrapped-command-p/recognizes-wrappers ()
  "--wrapped-command-p should match only repeatable-wrap- symbols."
  (should (repeatable--wrapped-command-p 'repeatable-wrap-foo))
  (should-not (repeatable--wrapped-command-p 'foo))
  (should-not (repeatable--wrapped-command-p "repeatable-wrap-foo"))
  (should-not (repeatable--wrapped-command-p nil)))

(provide 'repeatable-test)

;;; repeatable-test.el ends here
