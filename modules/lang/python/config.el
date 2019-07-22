;;; lang/python/config.el -*- lexical-binding: t; -*-

(defvar +python-ipython-repl-args '("-i" "--simple-prompt" "--no-color-info")
  "CLI arguments to initialize ipython with when `+python/open-ipython-repl' is
called.")

(defvar +python-jupyter-repl-args '("--simple-prompt")
  "CLI arguments to initialize 'jupiter console %s' with when
`+python/open-ipython-repl' is called.")


;;
;; Packages

(def-package! python
  :defer t
  :init
  (setq python-environment-directory doom-cache-dir
        python-indent-guess-indent-offset-verbose nil)
  :config
  (set-electric! 'python-mode :chars '(?:))
  (set-repl-handler! 'python-mode #'+python/open-repl)
  (set-docsets! 'python-mode "Python 3" "NumPy" "SciPy")

  (set-pretty-symbols! 'python-mode
    ;; Functional
    :def "def"
    :lambda "lambda"
    ;; Types
    :null "None"
    :true "True" :false "False"
    :int "int" :str "str"
    :float "float"
    :bool "bool"
    :tuple "tuple"
    ;; Flow
    :not "not"
    :in "in" :not-in "not in"
    :and "and" :or "or"
    :for "for"
    :return "return" :yield "yield")

  ;; Stop the spam!
  (setq python-indent-guess-indent-offset-verbose nil)

  (when (featurep! +lsp)
    (add-hook 'python-mode-local-vars-hook #'lsp!))

  ;; Default to Python 3. Prefer the versioned Python binaries since some
  ;; systems stupidly make the unversioned one point at Python 2.
  (when (and (executable-find "python3")
             (string= python-shell-interpreter "python"))
    (setq python-shell-interpreter "python3"))

  (add-hook 'python-mode-hook
    (defun +python-use-correct-flycheck-executables-h ()
      "Use the correct Python executables for Flycheck."
      (let ((executable python-shell-interpreter))
        (save-excursion
          (save-match-data
            (when (or (looking-at "#!/usr/bin/env \\(python[^ \n]+\\)")
                      (looking-at "#!\\([^ \n]+/python[^ \n]+\\)"))
              (setq executable (substring-no-properties (match-string 1))))))
        ;; Try to compile using the appropriate version of Python for
        ;; the file.
        (setq-local flycheck-python-pycompile-executable executable)
        ;; We might be running inside a virtualenv, in which case the
        ;; modules won't be available. But calling the executables
        ;; directly will work.
        (setq-local flycheck-python-pylint-executable "pylint")
        (setq-local flycheck-python-flake8-executable "flake8"))))

  (define-key python-mode-map (kbd "DEL") nil) ; interferes with smartparens
  (sp-local-pair 'python-mode "'" nil
                 :unless '(sp-point-before-word-p
                           sp-point-after-word-p
                           sp-point-before-same-p))

  ;; Affects pyenv and conda
  (advice-add #'pythonic-activate :after-while #'+modeline-update-env-in-all-windows-h)
  (advice-add #'pythonic-deactivate :after #'+modeline-clear-env-in-all-windows-h)

  (setq-hook! 'python-mode-hook tab-width python-indent-offset))


(def-package! anaconda-mode
  :hook (python-mode-local-vars . +python|init-anaconda-mode-maybe)
  :init
  (setq anaconda-mode-installation-directory (concat doom-etc-dir "anaconda/")
        anaconda-mode-eldoc-as-single-line t)
  :config
  (add-hook 'anaconda-mode-hook #'anaconda-eldoc-mode)
  (set-company-backend! 'anaconda-mode '(company-anaconda))
  (set-lookup-handlers! 'anaconda-mode
    :definition #'anaconda-mode-find-definitions
    :references #'anaconda-mode-find-references
    :documentation #'anaconda-mode-show-doc)
  (set-popup-rule! "^\\*anaconda-mode" :select nil)

  (defun +python|init-anaconda-mode-maybe ()
    (unless (bound-and-true-p lsp-mode)
      (anaconda-mode +1)))

  (defun +python|auto-kill-anaconda-processes ()
    "Kill anaconda processes if this buffer is the last python buffer."
    (when (and (eq major-mode 'python-mode)
               (not (delq (current-buffer)
                          (doom-buffers-in-mode 'python-mode (buffer-list)))))
      (anaconda-mode-stop)))
  (add-hook! 'python-mode-hook
    (add-hook 'kill-buffer-hook #'+python|auto-kill-anaconda-processes nil t))

  (when (featurep 'evil)
    (add-hook 'anaconda-mode-hook #'evil-normalize-keymaps))
  (map! :localleader
        :map anaconda-mode-map
        :prefix "f"
        "d" #'anaconda-mode-find-definitions
        "h" #'anaconda-mode-show-doc
        "a" #'anaconda-mode-find-assignments
        "f" #'anaconda-mode-find-file
        "u" #'anaconda-mode-find-references))


(def-package! pyimport
  :after python
  :config
  (map! :map python-mode-map
        :localleader
        (:prefix ("i" . "insert")
          :desc "Missing imports" "m" #'pyimport-insert-missing)
        (:prefix ("r" . "remove")
          :desc "Unused imports" "r" #'pyimport-remove-unused)))


(def-package! nose
  :commands nose-mode
  :preface (defvar nose-mode-map (make-sparse-keymap))
  :minor ("/test_.+\\.py$" . nose-mode)
  :config
  (set-popup-rule! "^\\*nosetests" :size 0.4 :select nil)
  (set-yas-minor-mode! 'nose-mode)
  (when (featurep 'evil)
    (add-hook 'nose-mode-hook #'evil-normalize-keymaps))

  (map! :localleader
        :map nose-mode-map
        :prefix "t"
        "r" #'nosetests-again
        "a" #'nosetests-all
        "s" #'nosetests-one
        "v" #'nosetests-module
        "A" #'nosetests-pdb-all
        "O" #'nosetests-pdb-one
        "V" #'nosetests-pdb-module))


(def-package! python-pytest
  :defer t
  :init
  (map! :after python
        :localleader
        :map python-mode-map
        :prefix "t"
        "f" #'python-pytest-file
        "k" #'python-pytest-file-dwim
        "t" #'python-pytest-function
        "m" #'python-pytest-function-dwim
        "r" #'python-pytest-repeat
        "p" #'python-pytest-popup))


;;
;; Environment management

(def-package! pipenv
  :commands pipenv-project-p
  :hook (python-mode . pipenv-mode)
  :init (setq pipenv-with-projectile nil)
  :config
  (set-eval-handler! 'python-mode
    '((:command . (lambda () python-shell-interpreter))
      (:exec (lambda ()
               (if-let* ((bin (executable-find "pipenv"))
                         (_ (pipenv-project-p)))
                   (format "PIPENV_MAX_DEPTH=9999 %s run %%c %%o %%s %%a" bin)
                 "%c %o %s %a")))
      (:description . "Run Python script"))))


(def-package! pyvenv
  :after python
  :init
  (when (featurep! :ui modeline)
    (add-hook 'pyvenv-post-activate-hooks #'+modeline-update-env-in-all-windows-h)
    (add-hook 'pyvenv-pre-deactivate-hooks #'+modeline-clear-env-in-all-windows-h))
  :config
  (add-hook 'hack-local-variables-hook #'pyvenv-track-virtualenv)
  (add-to-list 'global-mode-string
               '(pyvenv-virtual-env-name (" venv:" pyvenv-virtual-env-name " "))
               'append))


(def-package! pyenv-mode
  :when (featurep! +pyenv)
  :after python
  :config
  (pyenv-mode +1)
  (when (executable-find "pyenv")
    (add-to-list 'exec-path (expand-file-name "shims" (or (getenv "PYENV_ROOT") "~/.pyenv")))))


(def-package! conda
  :when (featurep! +conda)
  :after python
  :config
  ;; The location of your anaconda home will be guessed from the following:
  ;;
  ;; + `conda-anaconda-home's default value:
  ;;   + ANACONDA_HOME
  ;;   + ~/.anaconda3
  ;; + ~/.anaconda
  ;; + ~/.miniconda
  ;; + ~/usr/bin/anaconda3
  ;; + ~/usr/local/anaconda3
  ;; + ~/usr/local/miniconda3
  ;;
  ;; If none of these work for you, you must set `conda-anaconda-home'
  ;; explicitly. Once set, run M-x `conda-env-activate' to switch between
  ;; environments
  (unless (cl-loop for dir in (list conda-anaconda-home
                                    "~/.anaconda"
                                    "~/.miniconda"
                                    "~/.miniconda3"
                                    "/usr/bin/anaconda3"
                                    "/usr/local/anaconda3"
                                    "/usr/local/miniconda3")
                   if (file-directory-p dir)
                   return (setq conda-anaconda-home dir
                                conda-env-home-directory dir))
    (message "Cannot find Anaconda installation"))

  ;; integration with term/eshell
  (conda-env-initialize-interactive-shells)
  (after! eshell (conda-env-initialize-eshell))
 
  (add-to-list 'global-mode-string
               '(conda-env-current-name (" conda:" conda-env-current-name " "))
               'append))
