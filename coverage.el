;;; Package --- Summary
;;
;;; coverage.el - display code coverage (supports phpunit and JavaScript jest)
;;; Commentary:
;; Filename: coverage.el
;; Description: Display code coverage from jest javascript framework or phpunit
;; Author: (Jakub T. Jankiewicz) https://jcubic.pl/me
;; Copyright (C) 2018-2019, Jakub Jankiewicz
;; Created: Wed Jun 20 22:16:41 CEST 2018
;; Version: 0.2
;; Package-Requires: (json highlight xml)
;;
;;    This program is free software: you can redistribute it and/or modify
;;    it under the terms of the GNU General Public License as published by
;;    the Free Software Foundation, either version 3 of the License, or
;;    (at your option) any later version.
;;
;;    This program is distributed in the hope that it will be useful,
;;    but WITHOUT ANY WARRANTY; without even the implied warranty of
;;    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;    GNU General Public License for more details.
;;
;;    You should have received a copy of the GNU General Public License
;;    along with this program.  If not, see <http://www.gnu.org/licenses/>
;;; Code:
(maybe-require-package 'json)
(maybe-require-package 'highlight)

(make-variable-buffer-local
 (defvar jc/statements nil "variable that contain previous coverage"))

(define-minor-mode coverage-mode
  "Show code coverage from jest json file for git controled repo."
  :lighter " cov"
  (if coverage-mode
      (jc/mark-buffer)
    (jc/clear-buffer)))


(defface jc/covered
  '((t :background "dark green"))
  "background color for covered lines"
  :group 'coverage-minor-mode)

(defface jc/not-covered
  '((t :background "dark red"))
  "background color for not covered lines"
  :group
  'coverage-minor-mode)

(defun jc/shell-line (command)
  (replace-regexp-in-string "\n" "" (shell-command-to-string command)))

(defun jc/root-git-repo ()
  (interactive)
  (jc/shell-line "git rev-parse --show-toplevel"))

(defun jc/real-filename (filename)
  (jc/shell-line (concat "readlink -f " filename)))

(defun jc/line-pos-at-line (line)
  (interactive)
  (save-excursion
    (goto-line line)
    (line-beginning-position)))

(defun jc/end-pos-at-line (line)
  (interactive)
  (save-excursion
    (goto-line line)
    (line-end-position)))

(defun jc/clear-buffer ()
  (interactive)
  (save-excursion
    (end-of-buffer)
    (setq jc/statements nil)
    (hlt-unhighlight-region 0 (point))))


(defun jc/mark-buffer ()
  (let ((ext (file-name-extension (buffer-file-name))))
    (cond ((member ext '("js" "ts" "tsx")) (jc/mark-buffer-jest))
          (t (throw 'jest "invalid filename")))))

(defun jc/mark-buffer-jest ()
  (interactive)
  (let* ((dir (jc/root-git-repo))
         (json-object-type 'hash-table)
         (json-array-type 'list)
         (json-key-type 'string)
         (coverage-fname (concat dir "/coverage/coverage-final.json")))
    (if (not (file-exists-p coverage-fname))
        (message "file coverage not found")
      (let* ((json (json-read-file coverage-fname))
             (filename (jc/real-filename (buffer-file-name (current-buffer))))
             (coverage (gethash filename json)))
        (if (not (hash-table-p coverage))
            (message "No coverage found for this file")
          (let ((statments (gethash "statementMap" coverage)))
            (save-excursion
              (let ((coverage-list (gethash "s" coverage))
                    (covered 0)
                    (not-covered 0))
                (maphash (lambda (key value)
                           (if (not (and jc/statements (= (gethash key jc/statements) value)))
                               (let* ((statment (gethash key statments))
                                      (start (gethash "start" statment))
                                      (end (gethash "end" statment))
                                      (start-line-pos (jc/line-pos-at-line (gethash "line" start)))
                                      (start-pos (+ start-line-pos (gethash "column" start)))
                                      (end-line-pos (jc/line-pos-at-line (gethash "line" start)))
                                      (end-pos (+ end-line-pos (gethash "column" end)))
                                      (face (if (= value 0)
                                                'jc/not-covered
                                              'jc/covered)))
                                 (hlt-highlight-region start-pos end-pos face)))
                           (if (= value 0)
                               (setq not-covered (+ 1 not-covered))
                             (setq covered (+ 1 covered))))
                         coverage-list)
                (message "%3.2f%% coverage" (* (/ (float covered) (+ covered not-covered)) 100))
                (setq jc/statements coverage-list)))))))))

(provide 'coverage)
