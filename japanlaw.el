;;; japanlaw.el --- Japan law from law.e-gov.go.jp -*- Coding: utf-8 -*-

;; Copyright (C) 2007, 2008  Kazushi NODA
;;               2012-2013 Masahiro Hayashi <mhayashi1120@gmail.com>

;; Author: Kazushi NODA (http://www.ne.jp/asahi/alpha/kazu/)
;; Maintainer: Masahiro Hayashi <mhayashi1120@gmail.com>
;; Created: 2007-10-31
;; Version: 0.8.8
;; Keywords: docs help
;; Package-Requires: ((revive "20121022.1311"))

;; This file is not part of GNU Emacs.

;; GNU Emacs is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:

;;; Code:

(eval-when-compile (require 'cl))
(require 'revive)
(require 'easymenu)
(require 'outline)
(require 'iswitchb)

(defmacro japanlaw-labels (bindings &rest body)
  (if (fboundp 'cl-labels)
      `(cl-labels ,bindings ,@body)
    `(labels ,bindings ,@body)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; japanlaw-vars
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defconst japanlaw-version "version 0.8.8"
  "Version of japanlaw.el")

(defconst japanlaw-egov "http://law.e-gov.go.jp/cgi-bin/idxsearch.cgi"
  "法令データ提供システムのcgiのURL。")

(defconst japanlaw-ryaku-url
  "http://law.e-gov.go.jp/cgi-bin/idxsearch.cgi?H_RYAKU_SUBMIT=ON")

;;
;; Customize group
;;
(defgroup japanlaw nil
  "japanlaw mode."
  :prefix "japanlaw-"
  :group 'applications)

(defgroup japanlaw-faces nil
  "Faces for highlighting text."
  :prefix "japanlaw-"
  :group 'faces)

;;
;; User variables
;;
(defcustom japanlaw-line-space nil
  "*法令ファイルの行間。"
  :type 'integer
  :group 'japanlaw)

(defcustom japanlaw-index-initial-mode 'Index
  "`japanlaw-index-mode'の初期モード。次のうちひとつ選択できる。
Opened Recent Search Bookmark Index Directory Abbrev"
  :group 'japanlaw
  :type '(choice
	  (symbol :tag "Default" :value Index)
	  (symbol :tag "Opened" :value Opened)
	  (symbol :tag "Recent" :value Recent)
	  (symbol :tag "Search" :value Search)
	  (symbol :tag "Bookmark" :value Bookmark)
	  (symbol :tag "Index" :value Index)
	  (symbol :tag "Directory" :value Directory)
	  (symbol :tag "Abbrev" :value Abbrev)))

(defcustom japanlaw-recent-max 100
  "最近開いたファイルの履歴のリスト`japanlaw-recent-alist'の最大数。"
  :type 'integer
  :group 'japanlaw)

(defcustom japanlaw-use-index-header-line t
  "ヘッダラインを表示する。"
  :type 'boolean
  :group 'japanlaw)

(defcustom japanlaw-coding-system-for-write 'utf-8-unix
  "法令ファイルの文字コード。"
  :type 'symbol
  :group 'japanlaw)

(defcustom japanlaw-window-height 15
  "参照条文を表示するウィンドウの高さ。"
  :type 'integer
  :group 'japanlaw)

(defcustom japanlaw-reposition-line 2
  ""
  :type 'integer
  :group 'japanlaw)

(defcustom japanlaw-anchor-clickable nil
  "法令内のアンカーをクリッカブルにする。"
  :type 'boolean
  :group 'japanlaw)

(defcustom japanlaw-use-iswitchb nil
  "`japanlaw-index-goto-folder'で`iswitchb'を使う。migemoとiswitchbの設定が必要。"
  :type 'boolean
  :group 'japanlaw)

(defcustom japanlaw-iswitchb-initial-list 'download
  "`japanlaw-iswitchb'での検索対象の法令リストの初期値。"
  :group 'japanlaw
  :type '(choice
	  (symbol :tag "download" :value download)
	  (symbol :tag "bookmark" :value bookmark)
	  (symbol :tag "all" :value all)))

(defcustom japanlaw-max-mini-window-height max-mini-window-height
  "`japanlaw-iswitchb'のミニウインドウの最大高さ。"
  :type 'number
  :group 'japanlaw)

(defcustom japanlaw-online-mode t
  "オンラインモードで起動する。"
  :type 'boolean
  :group 'japanlaw)

(defcustom japanlaw-excluded-law-names
  '("社会保険労務士法"
    "土地家屋調査士法"
    "行政書士法"
    "司法書士法"
    "税理士法"
    "弁護士法"
    "調査士法")
  "法令名と法人名が重複する法令名のリスト。法の文言の中に現われる
 「〜法人」を着色しない。"
  :type 'list
  :group 'japanlaw)

(defcustom japanlaw-unentry-names
  '(("憲法" . "日本国憲法"))
  "法の文言の中で使われるが、略称法令名にも登録法令名にも含まれな
い法令名のアリスト。"
  :type 'alist
  :group 'japanlaw)

(defcustom japanlaw-local-names-plist
  '(("不動産登記令" :法 "不動産登記法" :規則 "不動産登記規則"))
  "ある法令ファイルの中での「法」・「規則」・「令」などを指し示す法令名。
先頭の要素が法令ファイルの法令名。上の例では、「不動産登記令」の中で、
 「法」は「不動産登記法」を指し、「規則」は「不動産登記規則」を指す。
法文の中で、`（以下「法」という。）'のように記述されているので、
ここで設定せずとも対応可能だが、設定されていれば優先して適用される。
タグは`japanlaw-local-name-list'に登録されている名称を利用する。"
  :type 'list
  :group 'japanlaw)

;; Path names
(defcustom japanlaw-path (expand-file-name "~/.japanlaw.d")
  "法令データ提供システムから取得したインデックスファイル、法令デー
タ等の保存先パス。"
  :type 'directory
  :group 'japanlaw)

(defcustom japanlaw-htmldata-directory "htmldata"
  "法令データ適用システムからダウンロードしたhtmldataの保存先ディレクトリ
の親ディレクトリ名。"
  :type 'string
  :group 'japanlaw)

(defcustom japanlaw-htmldata-path (concat japanlaw-path "/" japanlaw-htmldata-directory)
  "法令データ適用システムからダウンロードしたhtmldataの保存先ディレクトリ
の親ディレクトリのパス名。"
  :type 'directory
  :group 'japanlaw)

(defcustom japanlaw-egov-url "http://law.e-gov.go.jp/"
  "法令データ提供システムのURL。"
  :type 'directory
  :group 'japanlaw)

(defcustom japanlaw-data-path (concat japanlaw-path "/data")
  "w3mでdumpした法令ファイルの保存先ディレクトリの親ディレクトリのパス名。"
  :type 'directory
  :group 'japanlaw)

(defcustom japanlaw-temp-path (concat japanlaw-path "/tmp")
  "w3mでdumpする一時ファイルの保存先ディレクトリのパス名。"
  :type 'directory
  :group 'japanlaw)

(defcustom japanlaw-extention ".law"
  "法令データファイルの拡張子。`auto-mode-alist'に追加される。"
  :type 'string
  :group 'japanlaw)

(defcustom japanlaw-index-file (concat japanlaw-path "/.index")
  "事項別インデックスファイルのファイル名。"
  :type 'file
  :group 'japanlaw)

(defcustom japanlaw-abbrev-file (concat japanlaw-path "/.abbrev")
  "略称法令名のインデックスファイルのファイル名。"
  :type 'file
  :group 'japanlaw)

(defcustom japanlaw-bookmark-file (concat japanlaw-path "/.bookmark")
  "ブックマークの保存先ファイル名。"
  :type 'file
  :group 'japanlaw)

(defcustom japanlaw-recent-file (concat japanlaw-path "/.recent")
  "最近開いたファイルのリストの保存先ファイル名"
  :type 'file
  :group 'japanlaw)

;; Buffer name
(defcustom japanlaw-use-buffer-law-name t
  "tならバッファ名を法令名とする。nilなら変更しない。"
  :type 'boolean
  :group 'japanlaw)

(defcustom japanlaw-name-suffix ".."
  "バッファ名を縮小する場合のSUFFIX。"
  :type 'string
  :group 'japanlaw)

(defcustom japanlaw-name-length 20
  "バッファ名(法令名)の最大長。"
  :type 'integer
  :group 'japanlaw)

;; w3m
(defcustom japanlaw-w3m-dump-cols 5000
  "w3mでdumpするときのカラム数。"
  :type 'integer
  :group 'japanlaw)

(defcustom japanlaw-table-pixel 550
  "w3mでdumpするときのテーブルのピクセル数。"
  :type 'integer
  :group 'japanlaw)

;; paren
(defcustom japanlaw-compose-paren-char "＃"
  "`compose-region'で括弧を不可視にする場合、代替の1文字。
ここで指定する文字が対応括弧の代わりる表示される。"
  :type 'string
  :group 'japanlaw)

;;
;; font-lock-keyword-face
;;
;; 以下、defcustomされている`japanlaw-*-face'の値(シンボル名)を他に変更しないこと。
(defvar japanlaw-index-flag-face 'japanlaw-index-flag-face
  "Face name to use for open or close flag of law index mode.")

(defvar japanlaw-index-header-key-face 'japanlaw-index-header-key-face
  "Face name to use for shortcut key of header line.")

(defvar japanlaw-index-header-foreground-face 'japanlaw-index-header-foreground-face
  "Face name to use for foreground of header line.")

(defvar japanlaw-index-header-selected-face 'japanlaw-index-header-selected-face
  "Face name to use for selected foreground of header line.")

(defvar japanlaw-article-number-face 'japanlaw-article-number-face
  "Face name to use for number of article.")

(defvar japanlaw-article-paragraph-face 'japanlaw-article-paragraph-face
  "Face name to use for number of article.")

(defvar japanlaw-article-item-face 'japanlaw-article-item-face
  "Face name to use for number of article.")

(defvar japanlaw-anchor-name-face 'japanlaw-anchor-name-face
  "Face name to use for japanlaw name.")

(defvar japanlaw-anchor-article-face 'japanlaw-anchor-article-face
  "Face name to use for anchor article.")

(defvar japanlaw-anchor-paragraph-face 'japanlaw-anchor-paragraph-face
  "Face name to use for number of terms.")

(defvar japanlaw-article-subnumber-face 'japanlaw-article-subnumber-face
  "Face name to use for articl sub number.")

(defvar japanlaw-article-subitem1-face 'japanlaw-article-subitem1-face
  "Face name to use for article sub item.")

(defvar japanlaw-article-subitem2-face 'japanlaw-article-subitem2-face
  "Face name to use for article sub item-2.")

(defvar japanlaw-article-subitem3-face 'japanlaw-article-subitem3-face
  "Face name to use for article sub item-3.")

(defvar japanlaw-article-subitem4-face 'japanlaw-article-subitem4-face
  "Face name to use for article sub item-4.")

(defvar japanlaw-volume-face 'japanlaw-volume-face
  "Face name to use for volume.")

(defvar japanlaw-chapter-face 'japanlaw-chapter-face
  "Face name to use for chapter.")

(defvar japanlaw-section-face 'japanlaw-section-face
  "Face name to use for section.")

(defvar japanlaw-subsection-face 'japanlaw-subsection-face
  "Face name to use for subsection.")

(defvar japanlaw-subsection2-face 'japanlaw-subsection2-face
  "Face name to use for subsection-2.")

(defvar japanlaw-comment-face 'japanlaw-comment-face
  "Face name to use for comment.")

(defvar japanlaw-supplementary-face 'japanlaw-supplementary-face
  "Face name to use for supplementary.")

(defvar japanlaw-paren1-face 'japanlaw-paren1-face
  "Face name to use for Parentheses of the 1'th hierarchy.")

(defvar japanlaw-paren2-face 'japanlaw-paren2-face
  "Face name to use for Parentheses of the 2'th hierarchy.")

(defvar japanlaw-paren3-face 'japanlaw-paren3-face
  "Face name to use for Parentheses of the 3'th hierarchy.")

(defvar japanlaw-paren4-face 'japanlaw-paren4-face
  "Face name tp use for Parentheses of the 4'th hierarchy.")

(defvar japanlaw-paren5-face 'japanlaw-paren5-face
  "Face name tp use for Parentheses of the 5'th hierarchy.")

(defvar japanlaw-paren6-face 'japanlaw-paren6-face
  "Face name to use for Parentheses of the 6'th hierarchy.")

(defvar japanlaw-paren-error-face 'japanlaw-paren-error-face
  "Face name to use for Parentheses of the max hierarchy.")

;;
;; faces
;;
(defface japanlaw-index-flag-face
    '((((class color) (background light))
       (:foreground "CadetBlue"))
      (((class color) (background dark))
       (:foreground "Aquamarine"))
      (t (:foreground "SkyBlue")))
  "Font Lock mode face used to highlight japanlaw index folder flag."
  :group 'japanlaw-faces)

(defface japanlaw-index-header-key-face
    '((((class color) (background light))
       (:foreground "Black" :background nil :underline nil :weight bold))
      (((class color) (background dark))
       (:foreground "White" :background nil :underline nil :weight bold))
      (t (:foreground nil :underline t)))
  "Font Lock mode face used to highlight japanlaw index header line."
  :group 'japanlaw-faces)

(defface japanlaw-index-header-selected-face
    '((((class color) (background light))
       (:foreground "Black" :background nil :underline nil :weight bold
	:box (:line-width -1 :color nil :style pressed-button)))
      (((class color) (background dark))
       (:foreground "White" :background nil :underline nil :weight bold
	:box (:line-width -1 :color nil :style pressed-button)))
      (t (:foreground nil :underline t :weight bold)))
  "Font Lock mode face used to highlight japanlaw index header line."
  :group 'japanlaw-faces)

(defface japanlaw-index-header-foreground-face
    '((((class color) (background light))
       (:foreground "Gray60" :background nil :weight bold))
      (((class color) (background dark))
       (:foreground "CornflowerBlue" :background nil :weight bold))
      (t (:foreground nil :weight bold)))
  "Font Lock mode face used to highlight japanlaw index header line."
  :group 'japanlaw-faces)

(defface japanlaw-volume-face
    '((((class color) (background light))
       (:foreground "Blue"))
      (((class color) (background dark))
       (:foreground "Medium aquamarine"))
      (t (:foreground "Medium aquamarine")))
  "Font Lock mode face used to highlight volume lines."
  :group 'japanlaw-faces)

(defface japanlaw-chapter-face
    '((((class color) (background light))
       (:foreground "DarkGoldenrod"))
      (((class color) (background dark))
       (:foreground "Green3"))
      (t (:foreground "Green3")))
  "Font Lock mode face used to highlight chapter lines."
  :group 'japanlaw-faces)

(defface japanlaw-section-face
    '((((class color) (background light))
       (:foreground "Purple"))
      (((class color) (background dark))
       (:foreground "Cyan"))
      (t (:foreground "Cyan")))
  "Font Lock mode face used to highlight section lines."
  :group 'japanlaw-faces)

(defface japanlaw-subsection-face
    '((((class color) (background light))
       (:foreground "Orchid"))
      (((class color) (background dark))
       (:foreground "LightSteelBlue"))
      (t (:foreground "LightSteelBlue")))
  "Font Lock mode face used to highlight subsection lines."
  :group 'japanlaw-faces)

(defface japanlaw-subsection2-face
    '((((class color) (background light))
       (:foreground "red"))
      (((class color) (background dark))
       (:foreground "Dark sea green"))
      (t (:foreground "Dark sea green")))
  "Font Lock mode face used to highlight subsection-2."
  :group 'japanlaw-faces)

(defface japanlaw-comment-face
    '((((class color) (background light))
       (:foreground "CadetBlue"))
      (((class color) (background dark))
       (:foreground "LightSteelBlue"))
      (t (:foreground "LightSteelBlue")))
  "Font Lock mode face used to highlight comment."
  :group 'japanlaw-faces)

(defface japanlaw-anchor-article-face
    '((((class color) (background light))
       (:foreground nil :underline t))
      (((class color) (background dark))
       (:foreground nil :underline t))
      (t (:foreground nil :underline t)))
  "Font Lock mode face used to highlight reference."
  :group 'japanlaw-faces)

(defface japanlaw-anchor-name-face
    '((((class color) (background light))
       (:foreground nil :underline t))
      (((class color) (background dark))
       (:foreground nil :underline t))
      (t (:foreground nil :underline t)))
  "Font Lock mode face used to highlight japanlaw name."
  :group 'japanlaw-faces)

(defface japanlaw-supplementary-face
    '((((class color) (background light))
       (:foreground "CadetBlue"))
      (((class color) (background dark))
       (:foreground "Brown3"))
      (t (:foreground "Brown3")))
  "Font Lock mode face used to highlight comment."
  :group 'japanlaw-faces)

(defface japanlaw-paren1-face
    '((((class color) (background light))
       (:foreground "Palevioletred3"))
      (((class color) (background dark))
       (:foreground "Palevioletred3"))
      (t (:foreground "Palevioletred3")))
  "Parentheses of the 1'th hierarchy."
  :group 'japanlaw-faces)

(defface japanlaw-paren2-face
    '((((class color) (background light))
       (:foreground "Brown"))
      (((class color) (background dark))
       (:foreground "Brown"))
      (t (:foreground "Brown")))
  "Parentheses of the 2'th hierarchy."
  :group 'japanlaw-faces)

(defface japanlaw-paren3-face
    '((((class color) (background light))
       (:foreground "Yellow4"))
      (((class color) (background dark))
       (:foreground "Yellow4"))
      (t (:foreground "Yellow4")))
  "Parentheses of the 3'th hierarchy."
  :group 'japanlaw-faces)

(defface japanlaw-paren4-face
    '((((class color) (background light))
       (:foreground "Tan3"))
      (((class color) (background dark))
       (:foreground "Tan3"))
      (t (:foreground "Tan3")))
  "Parentheses of the 4'th hierarchy."
  :group 'japanlaw-faces)

(defface japanlaw-paren5-face
    '((((class color) (background light))
       (:foreground "RosyBrown3"))
      (((class color) (background dark))
       (:foreground "RosyBrown3"))
      (t (:foreground "RosyBrown3")))
  "Parentheses of the 5'th hierarchy."
  :group 'japanlaw-faces)

(defface japanlaw-paren6-face
    '((((class color) (background light))
       (:foreground "Blue"))
      (((class color) (background dark))
       (:foreground "Blue"))
      (t (:foreground "Blue")))
  "Parentheses of the 6'th hierarchy."
  :group 'japanlaw-faces)

(defface japanlaw-article-number-face
    '((((class color) (background light))
       (:foreground "Blue"))
      (((class color) (background dark))
       (:foreground "LightSkyBlue"))
      (t (:foreground "LightSkyBlue")))
  "Font Lock mode face used to highlight article number."
  :group 'japanlaw-faces)

(defface japanlaw-article-paragraph-face
    '((((class color) (background light))
       (:foreground "DarkGreen"))
      (((class color) (background dark))
       (:foreground "Cyan"))
      (t (:foreground "Cyan")))
  "Font Lock mode face used to highlight paragraph number."
  :group 'japanlaw-faces)

(defface japanlaw-article-item-face
    '((((class color) (background light))
       (:foreground "Blue"))
      (((class color) (background dark))
       (:foreground "Red"))
      (t (:foreground "Red")))
  "Font Lock mode face used to highlight item number."
  :group 'japanlaw-faces)

(defface japanlaw-anchor-paragraph-face
    '((((class color) (background light))
       (:foreground "Blue"))
      (((class color) (background dark))
       (:foreground "LightSkyBlue"))
      (t (:foreground "LightSkyBlue")))
  "Font Lock mode face used to highlight number of termss."
  :group 'japanlaw-faces)

(defface japanlaw-article-subnumber-face
    '((((class color) (background light))
       (:foreground "Blue"))
      (((class color) (background dark))
       (:foreground "IndianRed1"))
      (t (:foreground "IndianRed1")))
  "Font Lock mode face used to highlight article sub number."
  :group 'japanlaw-faces)

(defface japanlaw-article-subitem1-face
    '((((class color) (background light))
       (:foreground "Blue"))
      (((class color) (background dark))
       (:foreground "Green"))
      (t (:foreground "Green")))
  "Font Lock mode face used to highlight article sub item."
  :group 'japanlaw-faces)

(defface japanlaw-article-subitem2-face
    '((((class color) (background light))
       (:foreground "Orange"))
      (((class color) (background dark))
       (:foreground "Orange"))
      (t (:foreground "Orange")))
  "Font Lock mode face used to highlight article sub item-2."
  :group 'japanlaw-faces)

(defface japanlaw-article-subitem3-face
    '((((class color) (background light))
       (:foreground "Red"))
      (((class color) (background dark))
       (:foreground "HotPink1"))
      (t (:foreground "HotPink1":weight bold)))
  "Font Lock mode face used to highlight article sub item-3."
  :group 'japanlaw-faces)

(defface japanlaw-article-subitem4-face
    '((((class color) (background light))
       (:foreground "Maroon"))
      (((class color) (background dark))
       (:foreground "Pink4"))
      (t (:foreground "Pink4")))
  "Font Lock mode face used to highlight article sub item-4."
  :group 'japanlaw-faces)

;;
;; Internal variables
;;

;; Mode line image
(defvar japanlaw-online-icon
  (or (plist-get (cdr (find-image '((:type xpm :file "ezimage/doc-plus.xpm"))))
		 :file)
      "[+]")
  "Mode line online image path.")

(defvar japanlaw-offline-icon
  (or (plist-get (cdr (find-image '((:type xpm :file "ezimage/doc-minus.xpm"))))
		 :file)
      "[-]")
  "Mode line offline image path.")

(defvar japanlaw-icon
  (if japanlaw-online-mode japanlaw-online-icon japanlaw-offline-icon)
  "Start up mode line image path.")

(defvar japanlaw-mode-line-buffer-identification
  (default-value 'mode-line-buffer-identification))
(make-variable-buffer-local 'japanlaw-mode-line-buffer-identification)

(defvar japanlaw-mode-line
  (cons `(:eval (propertize
		 ,@(if (and (file-exists-p japanlaw-online-icon)
			    (file-exists-p japanlaw-offline-icon))
		       (list
			"    "
			(quote 'display) '(create-image
					   japanlaw-icon 'xpm nil
					   :ascent 'center))
		       (list 'japanlaw-icon))
		 'local-map (make-mode-line-mouse-map
			     'mouse-1 'japanlaw-online-or-offline)
		 'mouse-face 'mode-line-highlight
		 'help-echo (if japanlaw-online-mode
				"mouse-1: turn to offline mode."
			      "mouse-1: turn to online mode.")))
	(cons " "
	      (list (car japanlaw-mode-line-buffer-identification))))
  "JapanLaw mode line format.")

;; BookMark

;; Search
(defvar japanlaw-search-history nil)

;; Winconf
(defvar japanlaw-winconf-list '())

(defvar japanlaw-winconf-index 0)

(defvar japanlaw-display-toggle-winconf nil
  "For japanlaw-display-toggle.")

;; Parentheses
(defvar japanlaw-parens "（.+）")

(defvar japanlaw-paren-exclude-regexp
  "（\\([０-９]+\\|[一二三四五六七八九十]+\\|[ｉ]+\\)）")

(defvar japanlaw-paren-overlays)

;; 法、令、規則、新法、旧法等への対応
(defvar japanlaw-local-name-list
  '("法" "新法" "旧法" "規則" "新規則" "旧規則" "令" "新令" "旧令" "新細則" "旧細則" "附則" "法附則" "規則附則")
  "")

;; outline
(defvar japanlaw-heading-regexp
  (let ((number "[一二三四五六七八九十]"))
    (concat "^　*"
	    "\\(第" number "+編"
	    "\\|第" number "+章\\([のノ]" number "\\)*"
	    "\\|第" number "+節\\([のノ]" number "\\)*"
	    "\\|第" number "+款\\([のノ]" number "\\)*"
	    "\\|第" number "+目\\([のノ]" number "\\)*"
	    "\\|附　?則\\)"))
  "\
非アウトラインヘッダを含む見出しの正規表現。
目次部分の非アウトラインヘッダの見出しが行頭から始まる場合には、アウト
ラインヘッダ`outline-regexp'でもあるので、見出-本文間の移動が機能しない。
そのため、少なくとも1個の全角空白が必要。これは手作業で挿入する必要が
ある。")

(defvar japanlaw-supplementary-level 6
  "附則のアウトラインレベル")

(defconst japanlaw-jikoubetsu-index-alist
  '((1 . "憲法")	(2 . "国会")
    (3 . "行政組織")	(4 . "国家公務員")
    (5 . "行政手続")	(6 . "統計")
    (7 . "地方自治")	(8 . "地方財政")
    (9 . "司法")	(10 . "民事")
    (11 . "刑事")	(12 . "警察")
    (13 . "消防")	(14 . "国土開発")
    (15 . "土地")	(16 . "都市計画")
    (17 . "道路")	(18 . "河川")
    (19 . "災害対策")	(20 . "建築・住宅")
    (21 . "財務通則")	(22 . "国有財産")
    (23 . "国税")	(24 . "専売・事業")
    (25 . "国債")	(26 . "教育")
    (27 . "文化")	(28 . "産業通則")
    (29 . "農業")	(30 . "林業")
    (31 . "水産業")	(32 . "鉱業")
    (33 . "工業")	(34 . "商業")
    (35 . "金融・保険")	(36 . "外国為替・貿易")
    (37 . "陸運")	(38 . "海運")
    (39 . "航空")	(40 . "貨物運送")
    (41 . "観光")	(42 . "郵務")
    (43 . "電気通信")	(44 . "労働")
    (45 . "環境保全")	(46 . "厚生")
    (47 . "社会福祉")	(48 . "社会保険")
    (49 . "防衛")	(50 . "外事"))
  "事項別索引")

(defvar japanlaw-setup-p t
  "Non-nil means do setup, else not setup.")

;; japanlaw-mode
(defvar japanlaw-mishikou-list)		;ローカル変数

(defvar japanlaw-mode-name "JapanLaw")

(defvar japanlaw-mode-map
  (let ((map (make-sparse-keymap)))
    (suppress-keymap map)
    ;; japanlaw-anchor-clickable
    (define-key map [mouse-2] 'japanlaw-push-mouse-2)
    (define-key map [follow-link] 'mouse-face)
    ;; quit
    (define-key map "q" 'japanlaw-view-quit)
    (define-key map "Q" 'japanlaw-exit)
    ;; search
    (dotimes (i 10)
      (define-key map (format "%d" i) 'digit-argument))
    (define-key map "-" 'japanlaw-digit-argument-suffix)
    (define-key map " " 'japanlaw-search-or-push-anchor)
    ;; bookmark
    (define-key map "A" 'japanlaw-bookmark-this-file)
    ;; scroll
    (define-key map "n" 'japanlaw-forward-article)
    (define-key map "p" 'japanlaw-backward-article)
    (define-key map "[" 'japanlaw-backward-paragraph)
    (define-key map "]" 'japanlaw-forward-paragraph)
    (define-key map "j" 'japanlaw-scroll-up-screen)
    (define-key map "k" 'japanlaw-scroll-down-screen)
    ;; anchor
    (define-key map "\C-i" 'japanlaw-forward-anchor)
    (define-key map "\C-\M-i" 'japanlaw-backward-anchor)
    (define-key map "hc" 'japanlaw-print-current-url)
    ;; window
    (define-key map "v" 'japanlaw-display-toggle)
    (define-key map "o" 'japanlaw-other-window)
    ;; winconf
    (define-key map "wp" 'japanlaw-backward-winconf)
    (define-key map "wn" 'japanlaw-forward-winconf)
    (define-key map "wi" 'japanlaw-winconf-insert)
    (define-key map "wa" 'japanlaw-winconf-add)
    (define-key map "wo" 'japanlaw-winconf-override)
    (define-key map "wd" 'japanlaw-winconf-delete)
    (define-key map "wD" 'japanlaw-winconf-delete-all)
    (define-key map "wh" 'japanlaw-winconf-backward-delete)
    (define-key map "wf" 'japanlaw-restore-first-winconf)
    (define-key map "wl" 'japanlaw-restore-last-winconf)
    (define-key map "wc" 'japanlaw-restore-current-winconf)
    (define-key map "," 'japanlaw-backward-winconf)
    (define-key map "." 'japanlaw-forward-winconf)
    (define-key map "<" 'japanlaw-restore-first-winconf)
    (define-key map ">" 'japanlaw-restore-last-winconf)
    (define-key map "wm" 'japanlaw-winconf-message)
    ;; paren
    (define-key map "e" 'japanlaw-fontify-or-defontify-paren)
    (define-key map "dd" 'japanlaw-decompose-paren)
    (define-key map "de" 'japanlaw-compose-paren)
    ;; outline
    (define-key map "gt" 'japanlaw-goto-toc)
    (define-key map "t" 'japanlaw-goto-toc)
    (define-key map "gu" 'japanlaw-up-heading)
    (define-key map "u" 'japanlaw-up-heading)
    (define-key map "gf" 'japanlaw-next-visible-heading)
    (define-key map "f" 'japanlaw-next-visible-heading)
    (define-key map "gb" 'japanlaw-previous-visible-heading)
    (define-key map "b" 'japanlaw-previous-visible-heading)
    (define-key map "gn" 'japanlaw-forward-same-level)
    (define-key map "gp" 'japanlaw-backward-same-level)
    (define-key map "gg" 'japanlaw-heading-jump)
    (define-key map "gc" 'japanlaw-move-to-tables)
    (define-key map "c" 'japanlaw-move-to-tables)
    ;; iswitchb
;;    (define-key map "\C-c\C-b" 'japanlaw-iswitchb)
    ;; help
    (define-key map "?" 'japanlaw-help)
    map))

;; japanlaw-index-mode
(defvar japanlaw-index-mode-name "JapanLaw"
  "`japanlaw-index-mode'のモード名。")

(defvar japanlaw-index-buffer "*JapanLaw*"
  "`japanlaw-index-mode'のバッファ名。")

(defvar japanlaw-index-header-items
  '("Opened"
    "Recent"
    "Search"
    "Bookmark"
    "Index"
    "Directory"
    "Abbrev")
  "`japanlaw-index-mode'のヘッダラインのモードを表わす項目。")

;; 個別のモードの状態を保存するグローバル変数。
(defvar japanlaw-recent-alist nil)
(defvar japanlaw-bookmark-alist nil)
(defvar japanlaw-opened-alist nil)
(defvar japanlaw-search-history nil)

(defvar japanlaw-alist nil)
(defvar japanlaw-abbrev nil)
(defvar japanlaw-abbrev-alist nil)

;; 個別のモードの状態を保存するローカル変数。
(defvar japanlaw-index-local-mode)
(defvar japanlaw-index-conf)
(defvar japanlaw-names-alist)
(defvar japanlaw-search-alist)
(defvar japanlaw-index-alist)
(defvar japanlaw-directory-alist)
;; Searchモードでハイライトのためのoverlayを保持するローカル変数。
(defvar japanlaw-index-search-overlaies)

;; iswitchb
(defvar japanlaw-names-list nil "iswitchbのための補完リスト")

(defvar japanlaw-iswitchb-present-list nil
  "`japanlaw-iswitchb'の現在の検索対象の法令リスト。")

(defcustom japanlaw-w3m-command "w3m"
  "Path to w3m program"
  :type 'string
  :group 'japanlaw)

;; japanlaw-index
(defun japanlaw-set-face-invisible (n)
  "不可視のプロパティを設定するフォームを返す。"
  `(,n (progn (put-text-property
	       (match-beginning ,n) (match-end ,n)
	       'invisible t)
	      nil)))

(defun japanlaw-set-mouse-face-1 (n)
  `(,n (progn (add-text-properties
	       (match-beginning ,n) (match-end ,n)
	       (list
		'mouse-face 'highlight
		'local-map 'japanlaw-index-mode-map))
	      nil)))

(defun japanlaw-set-mouse-face-2 (n)
  `(,n (progn (add-text-properties
	       (match-beginning ,n) (match-end ,n)
	       (list
		'mouse-face 'highlight
		'local-map 'japanlaw-mode-map))
	      nil)))

(defvar japanlaw-index-font-lock-keywords
  (let ((fcolor (cdr (assq 'foreground-color
			   (frame-parameters (selected-frame))))))
    (list `(
	    ;;
	    ;; Directory, Index
	    ;;
	    ;; folder
	    "^\\((\"\\)\\([+-]\\)\\(\"\\) \\(\"\\)\\([^\"]+\\)\\(\")\\)$"
	    ,(japanlaw-set-face-invisible 1)
	    (2 japanlaw-index-flag-face t)
	    ,(japanlaw-set-mouse-face-1 2)
	    ,(japanlaw-set-face-invisible 3)
	    ,(japanlaw-set-face-invisible 4)
	    (5 '(:foreground ,fcolor) t)
	    ,(japanlaw-set-mouse-face-1 5)
	    ,(japanlaw-set-face-invisible 6))

	  ;;
	  ;; Abbrev
	  ;;
	  ;; folder
	  `("^\\((\"\\) \\{2\\}\\([+-]\\)\\(\"\\) \\(\"\\)\\([^\"]+\\)\\(\")\\)"
	    ,(japanlaw-set-face-invisible 1)
	    (2 japanlaw-index-flag-face t)
	    ,(japanlaw-set-mouse-face-1 2)
	    ,(japanlaw-set-face-invisible 3)
	    ,(japanlaw-set-face-invisible 4)
	    (5 '(:foreground ,fcolor) t)
	    ,(japanlaw-set-mouse-face-1 5)
	    ,(japanlaw-set-face-invisible 6))
	  ;; sub folder
	  `("^\\((\"\\) \\{4\\}\\([+-]\\)\\(\"\\) \\(\"\\)\\([^\"]+\\)\\(\")\\)"
	    ,(japanlaw-set-face-invisible 1)
	    (2 japanlaw-index-flag-face t)
	    ,(japanlaw-set-mouse-face-1 2)
	    ,(japanlaw-set-face-invisible 3)
	    ,(japanlaw-set-face-invisible 4)
	    (5 '(:foreground ,fcolor) t)
	    ,(japanlaw-set-mouse-face-1 5)
	    ,(japanlaw-set-face-invisible 6))
	  `("^\\((\"\\) \\{6\\}\\(-\\)\\(\"\\) \\(\"\\)\\([^\"]+\\)\\(\")\\)"
	    ,(japanlaw-set-face-invisible 1)
	    (2 japanlaw-index-flag-face t)
	    ,(japanlaw-set-mouse-face-1 2)
	    ,(japanlaw-set-face-invisible 3)
	    ,(japanlaw-set-face-invisible 4)
	    (5 '(:foreground ,fcolor) t)
	    ,(japanlaw-set-mouse-face-1 5)
	    ,(japanlaw-set-face-invisible 6))

	  ;;
	  ;; Opened, Recent, Bookmark
	  ;;
	  `("^\\((\"\\)\\([ D]\\)\\(-\\)\\(\"\\) \\(\"\\)\\([^\"]+\\)\\(\".+)\\)$"
	    ,(japanlaw-set-face-invisible 1)
	    (2 '(:foreground "red") t)
	    ,(japanlaw-set-mouse-face-1 2)
	    (3 japanlaw-index-flag-face t)
	    ,(japanlaw-set-face-invisible 4)
	    ,(japanlaw-set-face-invisible 5)
	    (6 '(:foreground ,fcolor) t)
	    ,(japanlaw-set-mouse-face-1 6)
	    ,(japanlaw-set-face-invisible 7))

	  ;;
	  ;; 法令名
	  ;;
	  `("^\\((\"\\) \\{2,\\}\\(-\\)\\(\"\\) \\(\"\\)\\([^\"]+\\)\\(\".+)\\)$"
	    ,(japanlaw-set-face-invisible 1)
	    (2 japanlaw-index-flag-face t)
	    ;;,(japanlaw-set-mouse-face-1 2)
	    ,(japanlaw-set-face-invisible 3)
	    ,(japanlaw-set-face-invisible 4)
	    (5 '(:foreground ,fcolor) t)
	    ,(japanlaw-set-mouse-face-1 5)
	    ,(japanlaw-set-face-invisible 6))
	  ))
  "`japanlaw-index-mode'のための`font-lock-keywords'")

(defvar japanlaw-index-mode-map
  (let ((map (make-sparse-keymap)))
    (mapc (lambda (mode)
	    (define-key map (vector (downcase (aref mode 0)))
	      `(lambda () (interactive) (japanlaw-index-goto-mode (intern ,mode)))))
	  japanlaw-index-header-items)
    (define-key map [mouse-2] 'japanlaw-index-mouse-open-or-close)
    (define-key map [follow-link] 'mouse-face)
    (define-key map " " 'japanlaw-index-open-or-close)
    (define-key map "u" 'japanlaw-index-upper-level)
    (define-key map "\M-[" 'japanlaw-index-open-all)
    (define-key map "\M-]" 'japanlaw-index-close-all)
    (define-key map "p" 'japanlaw-index-previous-line)
    (define-key map "n" 'japanlaw-index-next-line)
    (define-key map "j" 'japanlaw-index-scroll-up-line)
    (define-key map "k" 'japanlaw-index-scroll-down-line)
    (define-key map "\M-p" 'japanlaw-index-previous-folder)
    (define-key map "\M-n" 'japanlaw-index-next-folder)
    (define-key map "\M-<" 'japanlaw-index-beginning-of-buffer)
    (define-key map "\M->" 'japanlaw-index-end-of-buffer)
    (define-key map "\C-j" 'japanlaw-index-goto-folder)
    (define-key map "A" 'japanlaw-index-bookmark-add)
    (define-key map "m" 'japanlaw-index-put-deletion-flag)
    (define-key map "x" 'japanlaw-index-do-delete-marks)
    (define-key map "P" 'japanlaw-index-bookmark-move-up)
    (define-key map "N" 'japanlaw-index-bookmark-move-down)
    (define-key map "S" 'japanlaw-index-search)
    (define-key map "g" 'japanlaw-index-update)
    (define-key map "q" 'bury-buffer)
    (define-key map "Q" 'japanlaw-exit)
;;    (define-key map "\C-c\C-b" 'japanlaw-iswitchb)
    (define-key map "?" 'japanlaw-index-help)
    map)
  "`japanlaw-index-mode'のキーマップを返す。")

;; Regexp
(defvar japanlaw-volume-face-regexp
  "\\(^[ 　]*第.+編　[^（）\n]*\\)")

(defvar japanlaw-chapter-face-regexp "\
\\(^[ 　]*第.+章\\([のノ][一二三四五六七八九十]\\)*　[^（）\n]+\\)")

(defvar japanlaw-section-face-regexp "\
\\(^[ 　]*第.+節\\([のノ][一二三四五六七八九十]\\)*　[^（）\n]+\\)")

(defvar japanlaw-subsection-face-regexp "\
\\(^[ 　]*第.+款\\([のノ][一二三四五六七八九十]\\)*　[^（）\n]+\\)")

(defvar japanlaw-subsection2-face-regexp "\
^\\([ 　]*第.+目\\([のノ][一二三四五六七八九十]\\)*　[^（）\n]+\\)")

(defvar japanlaw-article-subitem3-face-regexp "^\\(（[０-９]+）\\|([0-9]+)\\)　")

(defvar japanlaw-comment-face-regexp "^[ 　]*\\(（\\cj+）\\|(\\cj+) \\)$")

(defvar japanlaw-article-subitem4-face-regexp "^（ｉ+）　")

(defvar japanlaw-supplementary-face-regexp
  "^\\([　 ]*附　?則.*$\\)")

(defvar japanlaw-article-subitem2-face-regexp "^\\cK　")

(defvar japanlaw-article-number-face-regexp "\
\\(^第[一二三四五六七八九十百千]+条\\([ノの][一二三四五六七八九十百]+\\)*\\)[ 　]*")

(defvar japanlaw-article-paragraph-face-regexp "\
\\(^\\([○◯]\\)?\\([０-９]+\\|[0-9]+\\)\\)[ 　]*")

(defvar japanlaw-article-item-face-regexp "\
\\(^[一二三四五六七八九十]+\\([のノ][一二三四五六七八九十]+\\)*\\)[ 　]*")

(defvar japanlaw-anchor-name-face-regexp2 "\
\\([^同]\\(\\([新旧]?\\(附則\\|法附則\\|規則附則\\|細則\\|法\\|規則\\|令\\)\\)\
\\(\\(第[一二三四五六七八九十百千]+条\\)\\([のノ][一二三四五六七八九十]+\\)*\
\\(第[一二三四五六七八九十]+項\\)*\
\\(第[一二三四五六七八九十]+号\\([のノ][一二三四五六七八九十]+\\)*\\)*\\)\\)\\)")

(defvar japanlaw-anchor-article-face-regexp3 "\
.\\(\\(第[一二三四五六七八九十百千]+条\\)\\([のノ][一二三四五六七八九十]+\\)*\
\\(第[一二三四五六七八九十]+項\\)*\
\\(第[一二三四五六七八九十]+号\\([のノ][一二三四五六七八九十]+\\)*\\)*\\)")

(defvar japanlaw-article-regexp
  "^第[一二三四五六七八九十百千]+条\\([のノ][一二三四五六七八九十]+\\)\\{0,3\\}"
  "条数の正規表現。")

(defvar japanlaw-paragraph-regexp
  (concat "^[○◯]?\\(" japanlaw-article-regexp "\\|[０-９]\\|[0-9]\\)\\{1,2\\}")
  "項数の正規表現。")

;; font-lock-keywords
(defvar japanlaw-font-lock-keywords)
(defvar japanlaw-font-lock-keywords-0
  (list `(,(concat "\\(" (regexp-opt japanlaw-excluded-law-names) "\\)[^人]")
	   (1 japanlaw-anchor-name-face nil))))

(defvar japanlaw-font-lock-keywords-1
  (list `(,japanlaw-chapter-face-regexp 1 japanlaw-chapter-face)
	`(,japanlaw-section-face-regexp 1 japanlaw-section-face)
	`(,japanlaw-subsection-face-regexp 1 japanlaw-subsection-face)
	`(,japanlaw-subsection2-face-regexp 1 japanlaw-subsection2-face)
	`(,japanlaw-supplementary-face-regexp 1 japanlaw-supplementary-face)
	`(,japanlaw-article-number-face-regexp 1 japanlaw-article-number-face)
	`(,japanlaw-anchor-name-face-regexp2 3 japanlaw-anchor-name-face)
	`(,japanlaw-anchor-name-face-regexp2 4 japanlaw-anchor-name-face)
	'("同法" 0 japanlaw-anchor-name-face)
	`(,japanlaw-anchor-article-face-regexp3 1 japanlaw-anchor-article-face)
	`(,japanlaw-anchor-article-face-regexp3 ,(japanlaw-set-mouse-face-2 1))
	`("同法" ,(japanlaw-set-mouse-face-2 0))
	`(,japanlaw-article-paragraph-face-regexp 1 japanlaw-article-paragraph-face)
	`(,japanlaw-article-item-face-regexp 1 japanlaw-article-item-face)
	`(,japanlaw-article-subitem2-face-regexp 0 japanlaw-article-subitem2-face)
	`(,japanlaw-article-subitem3-face-regexp  0 japanlaw-article-subitem3-face)
	`(,japanlaw-article-subitem4-face-regexp 0 japanlaw-article-subitem4-face)
	`(,japanlaw-volume-face-regexp 1 japanlaw-volume-face)
	`(,japanlaw-comment-face-regexp 1 japanlaw-comment-face)
	`(,japanlaw-anchor-name-face-regexp2 ,(japanlaw-set-mouse-face-2 2)))
  "Font lock keywords to highlight the `japanlaw-mode' buffer.")

(unless japanlaw-anchor-clickable
  (mapc (lambda (x)
	  (delete x japanlaw-font-lock-keywords-1))
	(list `(,japanlaw-anchor-name-face-regexp2 ,(japanlaw-set-mouse-face-2 2))
	      `(,japanlaw-anchor-article-face-regexp3 ,(japanlaw-set-mouse-face-2 1))
	      `("同法" ,(japanlaw-set-mouse-face-2 0)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; japanlaw-data
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun japanlaw-make-backup-file (file)
  (let ((version-control t))
    (when (file-exists-p file)
      (rename-file file (car (find-backup-file-name file))))))

(defun japanlaw-solve-backward-compatibility ()
  (cond
   ((file-exists-p japanlaw-path))
   ((and (boundp 'laws-path)
         (file-directory-p laws-path))
    ;; .emacs で旧バージョンの変数が再定義してある場合
    (rename-file laws-path japanlaw-path))
   ((file-directory-p "~/.laws.d")
    ;; デフォルト値で作成されている場合
    (rename-file "~/.laws.d" japanlaw-path))))

(defun japanlaw-make-index-files (&optional regenerate)
  (unless japanlaw-online-mode
    (japanlaw-online-mode-message #'error))
  (japanlaw-labels
      ((make-index
        (file new-alist-func old-alist-func)
        ;; インデックスファイルを生成する関数。FILEに、NEW-ALIST-FUNCの
        ;; 返すALISTを出力する。ALISTがOLD-ALIST-FUNCの返す値と同じなら
        ;; 出力しない。出力する場合、番号付きバックアップファイルを生成
        ;; する。戻り値は出力した場合はTを返し、出力しなければNILを返す。
        (let ((alist (funcall new-alist-func)))
          (if (equal alist (funcall old-alist-func))
              nil
            (japanlaw-make-backup-file file)
            (with-temp-file file
              (insert (format "%S" alist))
              (message "Wrote %s" file))
            t))))
    (let (index-updatedp abbrev-updatedp)

      ;; 互換性を維持するため過去のバージョンで作られたインデックスがあ
      ;; れば再利用する
      (japanlaw-solve-backward-compatibility)

      ;; indexファイルが存在しない場合
      ;; 再取得して更新された場合
      (when (or regenerate (not (file-exists-p japanlaw-index-file)))
	(if (not (y-or-n-p "Make index files? "))
	    (if regenerate
		(error "Cancel.")
	      (error "First of all, you should make the index file."))
	  (japanlaw-make-directory japanlaw-path)
	  (setq index-updatedp
		(make-index japanlaw-index-file #'japanlaw-get-index #'japanlaw-alist))
	  (message "Process has completed.")))
      ;; abbrevファイルが存在しない場合
      ;; 再取得して更新された場合
      (when (or regenerate (not (file-exists-p japanlaw-abbrev-file)))
	(japanlaw-make-directory japanlaw-path)
	(setq abbrev-updatedp
	      (make-index
	       japanlaw-abbrev-file #'japanlaw-make-abbrev-index #'japanlaw-abbrev))
	(message "Process has completed.")
	(sit-for 1))
      (cons index-updatedp abbrev-updatedp))))

(defun japanlaw-url-retrieve (url)
  "URLをGETする。"
  (save-current-buffer
    (with-current-buffer
	(condition-case err
	    (url-retrieve-synchronously url)
	  (error
	   (error "Cannot retrieve URL: %s" url)))
      (let ((coding (detect-coding-region (point-min) (point-max) t)))
	(decode-coding-region (point-min) (point-max) coding)
	(set-buffer-multibyte t)
	(goto-char (point-min))
	(current-buffer)))))

(defun japanlaw-get-dirname (id)
  "GETしたIDの保存先ディレクトリを返す。"
  (concat japanlaw-htmldata-path "/" (upcase (substring id 0 3))))

(defun japanlaw-get-index ()
  "事項別分類索引をGETして、法令名とIDのalistのリストを生成して返す。"
  (japanlaw-labels
      ((split (m)
              (save-match-data
                ;; htmldata
                ;; 1. 法令名文字列の末尾が半角空白の場合がある。
                ;; 2. （）が複数の場合があるが、0個の場合はない。
                (let ((s (replace-regexp-in-string "[\r\n\t]+" "" m)))
                  (when (string-match "^\\(.+?\\)\\(　抄\\)?\\(（.+?）*\\) *$" s)
                    (cons (match-string 1 s) (concat (match-string 2 s)
                                                     (match-string 3 s))))))))
    (save-current-buffer
      (japanlaw:map #'(lambda (request index)
		    (let ((case-fold-search t)
			  (result nil))
		      (with-current-buffer
			  (japanlaw-url-retrieve (concat japanlaw-egov "?" request))
			(message "Reading [text/html]... %2d of 50 (%d%%)"
				 (car index) (* (/ (car index) 50.0) 100))
			(while (re-search-forward
				"H_FILE_NAME=\\([^&]+\\)&[^>]+>\\([^<]+\\)</" nil t)
			  (push (cons (split (match-string 2)) (match-string 1))
				result))
			(kill-buffer (current-buffer))
			(cons (cdr index) (nreverse result)))))
		(japanlaw-request-uri-list) japanlaw-jikoubetsu-index-alist))))

(defun japanlaw-make-abbrev-index ()
  "略称法令名をGETして、連想リストを返す。"
  (with-current-buffer (japanlaw-url-retrieve japanlaw-ryaku-url)
    (let ((rx-a "<A NAME=\"[0-9]+\"><B>\\(.+?\\)</B>")
	  (rx-b "<B>\\(.+?\\)</B>")
	  (rx-c "<A HREF=\".+?H_FILE_NAME=\\([^&]+\\)&.+?\">\\(.+?\\)</A>"))
      (let ((result-a nil))
	(while (re-search-forward rx-a nil t)
	  (push
	   (let ((lim (save-match-data
			(save-excursion
			  (or (and (re-search-forward rx-a nil t)
				   (line-beginning-position))
			      (point-max))))))
	     (cons (match-string 1)
		   (save-match-data
		     (let ((result-b nil))
		       (while (re-search-forward rx-b lim t)
			 (let ((lim (save-match-data
				      (save-excursion
					(or (and (re-search-forward rx-b lim t)
						 (line-beginning-position))
					    lim)))))
			   (push
			    (cons (match-string 1)
				  (save-match-data
				    (let ((result-c nil))
				      (while (re-search-forward rx-c lim t)
					(push (cons (match-string 2)
						    (match-string 1))
					      result-c))
				      (nreverse result-c))))
			    result-b)))
		       (nreverse result-b)))))
	   result-a))
	(nreverse result-a)))))

(defun japanlaw-request-uri-list ()
  "URLリスト"
  (loop for (cid . name) in japanlaw-jikoubetsu-index-alist
        collect
        (format (mapconcat #'identity
                           '("H_CTG_%d=%%81%%40"
                             "H_CTG_GUN=1"
                             "H_NAME=0"
                             "H_NAME_YOMI=%%82%%A0"
                             "H_NO_GENGO=H"
                             "H_NO_YEAR=0"
                             "H_NO_TYPE=2"
                             "H_NO_NO=0"
                             "H_RYAKU=1"
                             "H_YOMI_GUN=1") "&")
                cid)))

(defun japanlaw-make-jikoubetsu-index ()
  (let ((strs nil)
	(case-fold-search t))
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward "NAME=\"H_CTG_\\([0-9]+\\)[^>]+>\\(.+?\\)<" nil t)
	(push (cons
	       (match-string-no-properties 1)
	       (replace-regexp-in-string
		"[ 　]+" "" (match-string-no-properties 2)))
	      strs)))
    (sort strs (lambda (x y)
		 (< (string-to-number (car x)) (string-to-number (car y)))))))

(defun japanlaw-make-stags-alist ()
  "行頭から前方に検索して、ポイント行内のS式のリストを返す。"
  (save-excursion
    (save-match-data
      (let ((result nil)
	    (lim (line-end-position)))
	(forward-line 0)
	(while (re-search-forward "(:a [^()]+)" lim t)
	  (push (cons (match-beginning 0) (match-end 0)) result))
	result))))

(defun japanlaw-in-stag-p (pos)
  "ポイントPOSがタグの中にあればtを、なければnilを返す。"
  (let ((ls (japanlaw-make-stags-alist)))
    (block nil
      (while ls
	(let ((points (car ls)))
	  (if (and (> pos (car points))
		   (< pos (cdr points)))
	      (return t)
	    (pop ls)))))))

(defun japanlaw-duplicate-names (ls)
  "重複する法令名のリストを返す。"
  (do ((xs (cdr ls) (cdr xs))
       (name (caar ls) (caar xs))
       (result nil))
      ((null xs) (delete-dups result))
    (do ((ys xs (cdr ys)))
	((null ys))
      (when (string-match name (caar ys))
	(push name result)))))

(defun japanlaw-replace-table-value (&optional table-pixel)
  "GETしたhtmlのタグを置換する。"
  (let ((case-fold-search t)
	(pixel (or table-pixel japanlaw-table-pixel)))
    (japanlaw-labels ((match (rx s) (save-match-data (string-match rx s))))
      (while (re-search-forward "<TABLE [^>]+>\\|<DIV ALIGN=\"right\">" nil t)
	(replace-match
	 (let ((s (match-string 0)))
	   (cond ((match "<DIV ALIGN=\"right\">" s)
		  ;; 冒頭の右寄せのテーブルを左寄せに。
		  "<DIV ALIGN=\"left\">")
		 ((match "TABLE WIDTH" s)
		  ;; 冒頭のテーブルの幅を指定。
		  (format "<TABLE WIDTH=%S BORDER=%S>" pixel 0))
		 (t ;; 出力される罫線表の幅を指定。
		  (format "<TABLE WIDTH=%S BORDER>" pixel)))))))))

(defun japanlaw-load-index (index)
  "インデックスファイルをreadしてリストを返す。"
  (with-temp-buffer
    (insert-file-contents index)
    (do ((xs (read (current-buffer)) (cdr xs))
	 (acc nil))
	((null xs) acc)
      (do ((ys (cdar xs) (cdr ys)))
	  ((null ys))
	(push (cons (car (caar ys)) (cdar ys)) acc)))))

(defun japanlaw-extract-name ()
  "html から法令名を取得して、文字列長の小さい順でソートされたリストを返す。"
  (let ((result nil)
	(case-fold-search t)
	(rx "<A HREF=.+?REF_NAME=\\([^&]+\\)&ANCHOR_F=&ANCHOR_T="))
    (while (re-search-forward rx nil t) (push (match-string 1) result))
    (sort (delete-dups result) (lambda (x y) (< (length x) (length y))))))

(defun japanlaw-detect-coding-region (start end priority-list)
  ;; `w3m-detect-coding-region'(w3m-fsf.el)の関数名のみ変更。
  "Detect coding system of the text in the region between START and END.
Return the first possible coding system.

PRIORITY-LIST is a list of coding systems ordered by priority."
  (let (category categories)
    (dolist (codesys priority-list)
      (setq category (coding-system-category codesys))
      (unless (or (null category) (assq category categories))
	(push (cons category codesys) categories)))
    (with-coding-priority (nreverse categories)
      (car (detect-coding-region start end)))))


(defun japanlaw-url-decode-string (str &optional coding)
  ;; `w3m-url-decode-string'(w3m.el)のxemacs対応を除いた他、関数名を変更。
  (let ((start 0)
	(buf))
    (while (string-match "+\\|%\\(0D%0A\\|\\([0-9a-fA-F][0-9a-fA-F]\\)\\)"
			 str start)
      (push (substring str start (match-beginning 0)) buf)
      (push (cond
	     ((match-beginning 2)
	      (vector (string-to-number (match-string 2 str) 16)))
	     ((match-beginning 1) "\n")
	     (t " "))
	    buf)
      (setq start (match-end 0)))
    (setq str (apply 'concat (nreverse (cons (substring str start) buf))))
    (setq str (string-make-unibyte str))
    (when (listp coding)
      (setq coding
	    (with-temp-buffer
	      (set-buffer-multibyte nil)
	      (insert str)
	      (japanlaw-detect-coding-region (point-min) (point-max) coding))))
    (decode-coding-string
     str (or coding 'iso-8859-1 'iso-2022-7bit 'iso-2022-7bit))))

(defun japanlaw-make-substitution-alist (ls index)
  "置換用のalist \(\(\"法令名\" . \"path\"\) ...\) を返す。"
  (do ((ls ls (cdr ls))
       (acc nil (acons (car ls) (cdr (assoc (car ls) index)) acc)))
      ((null ls) acc)))

(defun japanlaw-expand-htmldata-url (id)
  "ID(のファイル名部分`M29HO089'などの形式)から、法令名のURLを返す。"
  (if (> 3 (length id))
      ""
    (concat japanlaw-egov-url japanlaw-htmldata-directory "/"
	    (upcase (substring id 0 3)) "/" (upcase id) ".html")))

(defun japanlaw-expand-htmldata-file (id)
  "ID(のファイル名部分)から、GETしたHTMLの保存先パスファイルを返す。"
  (if (> 3 (length id))
      ""
    (concat japanlaw-htmldata-path "/"
	    (upcase (substring id 0 3)) "/" (upcase id) ".html")))

(defun japanlaw-expand-data-file (id)
  "ID(のファイル名部分)から、ダンプしたデータの保存先パスファイル名を返す。"
  (if (> 3 (length id))
      ""
    (concat japanlaw-data-path "/"
	    (downcase (substring id 0 3)) "/" (downcase id) japanlaw-extention)))

(defun japanlaw-expand-init-file (id)
  ;; ID は "h01ho042.law" のような文字列
  (if (> 3 (length id))
      ""
    (concat japanlaw-data-path "/"
	    (downcase (substring id 0 3)) "/." (downcase id))))

(defun japanlaw-make-directory (dir)
  (unless (and (file-exists-p dir)
	       (file-directory-p dir))
    (when (file-regular-p dir)
      (error "File `%s' exists!" dir))
    (make-directory dir 'parent)))

(defun japanlaw-htmldata-retrieve (id force &optional url)
  "IDのHTMLデータが存在しない場合と、FORCEが非nilの場合に取得する。最後
に取得した時から変更があった場合、番号付きバックアップファイルを生成する。
保存先のhtmlのパスファイル名を返す。"
  (let ((html-path (japanlaw-expand-htmldata-file id))
	(file (japanlaw-expand-data-file id)))
    (unless url
      (setq url (japanlaw-expand-htmldata-url id)))
    (when (or force (not (file-exists-p html-path)))
      (let ((buffer
	     (set-buffer (japanlaw-url-retrieve url))))
	(with-current-buffer buffer
	  (goto-char (point-min))
	  ;; (save-excursion (replace-string "\r" ""))    ;Emacs23?
	  (when (search-forward "404 Not Found" nil t)
	    (re-search-forward "^$" nil t)
	    (error (concat url
			   (replace-regexp-in-string
			    "<.+?>\\|\r\n" ""
			    (buffer-substring (point) (point-max))))))
	  ;; ファイルが存在しない場合と、取得したデータと保存されているデータ
	  ;; を比較し、データが更新された場合、バックアップと出力を行う。
	  ;; 更新されていなければメッセージを出す。
	  (let (s1 e1 s2 e2)
	    (re-search-forward "^$" nil t)
	    (forward-line 1)
	    (setq s1 (point))
	    (setq e1 (point-max))
	    (if (= (with-temp-buffer
		     (if (not (file-exists-p html-path))
			 -1
		       (insert-file-contents html-path)
		       (setq s2 (point-min) e2 (point-max))
		       (compare-buffer-substrings buffer s1 e1 nil s2 e2)))
		   0)
		(progn
		  (message "File `%s.html' not changed from last retrieving." id)
		  (sit-for 2))
	      (when (file-exists-p file) (delete-file file)) ;テキストの削除
	      (japanlaw-make-directory (japanlaw-get-dirname id)) ;ディレクトリ
	      (japanlaw-make-backup-file html-path) ;バックアップ
              ;; e-gov の html はすべて shift_jis のようで、
              ;; 当分変わると思えないのでハードコーディング。
              (let ((coding-system-for-write 'japanese-shift-jis-dos))
                (write-region
                 (point) (point-max) html-path))))
	  (kill-buffer buffer))))
    html-path))

(defun japanlaw-make-images-list ()
  "htmldataから画像データのパスリストを取得して返す。"
  (save-excursion
    (goto-char (point-min))
    (let ((result nil)
	  (case-fold-search t))
      (while (re-search-forward "<IMG SRC=\"\\(.+?\\)\" [^>]+>" nil t)
	(push (match-string 1) result))
      (nreverse result))))

(defun japanlaw-expand-image-file-name (path)
  (concat japanlaw-path path))

(defun japanlaw-expand-image-file-url (path)
  (concat japanlaw-egov-url (substring path 1)))

(defun japanlaw-images-retrieve (ls)
  (save-current-buffer
    (mapcar #'(lambda (path)
		(let* ((url (japanlaw-expand-image-file-url path))
		       (file (japanlaw-expand-image-file-name path))
		       (dir (file-name-directory file))
		       (buffer (japanlaw-url-retrieve url)))
		  (japanlaw-make-directory dir)
		  (with-current-buffer (set-buffer buffer)
		    (goto-char (point-min))
                    (let ((coding-system-for-write 'binary))
                      (write-region
                       (progn (re-search-forward "^$" nil t)
                              (forward-line 1)
                              (point))
                       (point-max)
                       file)))
		  (kill-buffer buffer)))
	    ls)))

(defun japanlaw-replace-image-tags (images)
  (let ((case-fold-search t))
    (goto-char (point-min))
    (while images
      (when (re-search-forward
	     (format "IMG SRC=\"%s\" ALT=\\(\"\"\\)" (car images)) nil t)
	(replace-match (format "\"<../..%s>\"" (car images)) nil nil nil 1))
      (pop images))))

(defun japanlaw-html-get-h-path ()
  "htmldataからH-PATHを抽出する。"
  (let ((case-fold-search t)
	(h-path nil))
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward "<A HREF=\".+?H_PATH=\\(.+?\\)\" [^>]+>" nil t)
	(let ((path (match-string-no-properties 1)))
	  (when (re-search-forward "\\([^<]+\\)</A>" nil t)
	    (let ((s (japanlaw-url-decode-string (match-string 1))))
	      (push (cons s path) h-path)))))
      (nreverse h-path))))

(defun japanlaw-w3m-dump (htmldata &rest args)
  (apply 'call-process
         japanlaw-w3m-command nil (current-buffer) nil
         "-dump"
         "-cols" (number-to-string japanlaw-w3m-dump-cols)
         (append args (list htmldata))))

(defun japanlaw-replace-zspc ()
  (goto-char (point-min))
  (while (search-forward "  " nil t)
    (replace-match "　")))

(defun japanlaw-make-font-lock-regexp-in-buffer (h-path)
  ;; japanlaw-name-search-in-buffer
  (let ((xs (japanlaw-names-list))
	(result nil))
    (save-excursion
      (while xs
	(goto-char (point-min))
	(when (search-forward (car xs) nil t)
	  (push (match-string 0) result))
	(pop xs)))
    (mapc (lambda (name)
	    (setq result (delete name result)))
	  japanlaw-excluded-law-names)
    (when h-path
      (mapc (lambda (cell) (push (car cell) result))
	    h-path))
    (if (null result)
	nil
      (regexp-opt result))))

(defun japanlaw-write-init-file (out h-path iimagep force)
  (if (or force (not (file-exists-p out)))
      (let ((regexps (japanlaw-make-font-lock-regexp-in-buffer h-path)))
	(with-temp-file out
	  ;; 正規表現文字列、冒頭の未施行法令等とその参照先URLのcons、imageが
	  ;; 含まれているかどうか。
	  (insert ";;; `japanlaw-mode' japanlaw-font-lock-keywords-2 file.\n")
	  (insert (format "%S" (list regexps h-path iimagep)))
	  (message "Wrote %s" out)))))

(defun japanlaw-read-init-file ()
  ;; 生成されたファイル情報を読み込む。
  (let ((file (japanlaw-expand-init-file
	       (file-name-sans-extension
		(file-name-nondirectory (buffer-file-name))))))
    (if (file-exists-p file)
	(with-temp-buffer
	  (insert-file-contents file)
	  (read (current-buffer)))
      (message "Not exists japanlaw-font-lock-keywords-2 file `%s'" file)
      nil)))

(defun japanlaw-make-data (id &optional force url)
  "htmlデータをw3mでダンプする。FORCEが非nilならIDをGET、nilなら既
にGETしたHTMLを対象とする。また、font-lockのためのタグの埋め込み等
の加工を行なう。
生成されたファイルの名前を返す。"
  (unless japanlaw-online-mode
    (japanlaw-online-mode-message #'error))
  (message "Getting file and converting...")
  (let ((temp (concat japanlaw-temp-path "/temp.html"))
	;; htmldata を取得。
	(html (japanlaw-htmldata-retrieve id nil url))
	(file (japanlaw-expand-data-file id))
	(regfile (japanlaw-expand-init-file id))
	(coding-system-for-write japanlaw-coding-system-for-write)
	alist images h-path)
    (with-temp-file temp
      (japanlaw-make-directory (file-name-directory temp))
      ;; バッファにhtmlを取得する。
      (message "Getting htmldata...")
      (let ((coding-system-for-read 'raw-text)
            format-alist)
        (insert-file-contents html))
      (message (concat (current-message) " done."))
      ;; イメージデータの取得。
      (setq images (japanlaw-make-images-list))
      (when (and force images)
	(message "Getting images...")
	(japanlaw-images-retrieve images)
	(message "Getting images... done."))
      ;; `H_PATH'の取得。
      (setq h-path (japanlaw-html-get-h-path))
      ;; htmlタグの置換。テンポラリファイルに書き出す。
      ;; テンポラリファイルは削除せずに残す。
      (goto-char (point-min))
      (message "Replacing tag's value in htmldata...")
      (japanlaw-replace-table-value)
      ;; イメージを置換する。
      (when images (japanlaw-replace-image-tags images))
      )
    (message (concat (current-message) " done."))
    ;; テンポラリファイルを対象にw3mでダンプする。
    (with-temp-file file
      (japanlaw-make-directory (file-name-directory file))
      (message "Extracting data from htmldata...")
      (japanlaw-w3m-dump temp)
      (message (concat (current-message) " done."))
      ;; 半角空白2個を全角空白に置換する。
      (message "Replacing spaces...")
      (save-excursion (japanlaw-replace-zspc))
      (message (concat (current-message) " done."))
      ;; バッファ内の法令名を取得し、正規表現を生成する。
      (message "Scanning law names...")
      ;; 情報を書き込む。
      (japanlaw-write-init-file regfile h-path (if images t nil) force)
      (message (concat (current-message) " done."))
      (message "Scanning law names...done")
      (message "Getting file and converting...done")
      ;; 生成されたファイルの名前を返す。
      file)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; japanlaw-index
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;
;; Header line
;;
(defun japanlaw-index-mode-header-line-keymap (mode)
  "ヘッダラインのキーマップを返す。"
  (let ((map (make-sparse-keymap)))
    (define-key map [header-line mouse-1]
      `(lambda (e) (interactive "e")
	       (set-buffer (window-buffer (posn-window (event-end e))))
	       (japanlaw-index-goto-mode (intern ,mode))))
    map))

(defun japanlaw-index-header-line-format (mode)
  "`japanlaw-index-mode'の。`header-line-format'"
  (japanlaw-labels
      ((spc (n)
            (propertize " " 'display `(space :width (,n)))))
    (concat " "
	    (mapconcat
	     (lambda (s)
	       (if (string= s mode)
		   (concat
		    (propertize (concat (spc 5) s (spc 5))
				'face
				japanlaw-index-header-selected-face
				'mouse-face 'highlight
				'help-echo (format "`%s'" s))
		    (spc 1))
		 (concat
		  (propertize
		   (concat
		    (propertize (concat (spc 5) (substring s 0 1))
				'face
				japanlaw-index-header-key-face)
		    (propertize (concat (substring s 1) (spc 5))
				'face
				japanlaw-index-header-foreground-face))
		   'mouse-face 'highlight
		   'help-echo (format "mouse-1: Goto `%s' mode" s)
		   'local-map (japanlaw-index-mode-header-line-keymap s))
		  (spc 1))))
	     japanlaw-index-header-items ""))))

(defun japanlaw-index-update ()
  "現在のモードの表示を更新する。
更新するのは、Opened,Recent,Bookmarkの場合。それ以外のモードでは更新しない。"
  (interactive)
  (when (memq japanlaw-index-local-mode '(Opened Recent Bookmark))
    (japanlaw-index-goto-mode japanlaw-index-local-mode 'update)
    (message "Updating %s...done" japanlaw-index-local-mode)))

(defun japanlaw-index-goto-mode (mode &optional update)
  "`japanlaw-index-mode'の各、個別のモード`japanlaw-index-local-mode'に遷移する。
MODEが現在のMODEと同じ場合、nilを返す(see. `japanlaw-index-search')。"
  (japanlaw-index-set-mode-conf)
  (let ((name (lambda (mode)
		(format "%s:%s" japanlaw-index-mode-name mode))))
    (unless (and (not update) (string= mode-name (funcall name mode)))
      (setq header-line-format
	    (if japanlaw-use-index-header-line
		(japanlaw-index-header-line-format mode)
	      nil))
      (setq mode-name (funcall name mode)
	    japanlaw-index-local-mode mode)
      (force-mode-line-update)
      (japanlaw-index-insert-contents mode)
      (japanlaw-index-restore-mode-conf))))

;; Buffer configuration
(defun japanlaw-index-set-mode-conf ()
  "現在のバッファの情報を保存する。"
  (setq japanlaw-index-conf
	(delete (assoc japanlaw-index-local-mode japanlaw-index-conf)
		japanlaw-index-conf))
  (push `(,japanlaw-index-local-mode
	  ,(line-number-at-pos)
	  ,(window-start))
	japanlaw-index-conf))

(defun japanlaw-index-restore-mode-conf ()
  "以前のバッファの状態を復元する。"
  (let ((cel (assoc japanlaw-index-local-mode japanlaw-index-conf)))
    (when cel
      (destructuring-bind (mode line start)
	  (assoc japanlaw-index-local-mode japanlaw-index-conf)
	(set-window-start (selected-window) start)
	(japanlaw-goto-line line)
	(japanlaw-index-move-to-column)))))

;;
;; Common
;;

(defmacro japanlaw-with-buffer-read-only (&rest forms)
  "バッファの未編集とリードオンリー状態を保持してFORMSを評価する。"
  '(unless (eq major-mode 'japanlaw-index-mode)
    (error "ERROR: major-mode is not japanlaw-index-mode."))
  `(progn
     (setq buffer-read-only nil)
     (unwind-protect
	  (save-excursion ,@forms)
       (progn
	 (setq buffer-read-only t)
	 (set-buffer-modified-p nil)))))

(defsubst japanlaw-read ()
  "バッファのinvisibleなS式をreadする。"
  (save-excursion
    (forward-line 0)
    (read (current-buffer))))

(defsubst japanlaw-get-values (&optional pointer)
  "バッファのinvisibleなS式のデータをリストで返す。
関数POINTERが与えられれば、POINTERが指す値を返す。
\(japanlaw-read\)のエラーを把捉したらnilを返す。"
  (condition-case err
      (destructuring-bind (flag name . id) (japanlaw-read)
	(if (functionp pointer)
	    (funcall pointer (list flag name id))
	  (list flag name id)))
    (error nil)))

(defsubst japanlaw-any-function (funcs)
  "FUNCSの中で初めに非nilを返した関数を返す。
FUNCSは引数を取らない関数のリスト。"
  (block nil
    (mapc (lambda (f) (and (funcall f) (return f)))
	  funcs)))

(defun japanlaw-goto-line (line)
  (goto-char (point-min))
  (forward-line line))

(defun japanlaw:filter (pred ls)
  "PREDを適用した結果tを返した要素を集める。"
  (do ((xs ls (cdr xs))
       (acc nil (if (funcall pred (car xs)) (cons (car xs) acc) acc)))
      ((null xs) (nreverse acc))))

(defun japanlaw:append-map (f ls &rest more)
  (apply 'append (apply 'japanlaw:map f ls more)))

(defun japanlaw:fringe (tree)
  (if (listp tree)
      (japanlaw:append-map 'japanlaw:fringe tree)
    (list tree)))

(defun japanlaw:map (f ls &rest more)
  (let* ((x (cons ls more))
	 (n (apply 'min (mapcar 'length x))))
    (do ((n n (- n 1))
	 (x x (mapcar 'cdr x))
	 (ans nil (cons (apply f (mapcar 'car x)) ans)))
	((= n 0) (nreverse ans)))))

(unless (fboundp 'cl-set-nthcdr)
  (defun cl-set-nthcdr (n list x)
    (if (<= n 0) x (setcdr (nthcdr (1- n) list) x) list)))

;;
;; Load data
;;

;; Common

;; インデックスファイルの内容を保持するローカル変数。
(defun japanlaw-alist ()
  "インデックスファイルをロードする関数。"
  (or japanlaw-alist
      (and (file-exists-p japanlaw-index-file)
	   (setq japanlaw-alist
		 (with-temp-buffer
		   (insert-file-contents japanlaw-index-file)
		   (read (current-buffer)))))))

;; 略称法令名のインデックスファイルの内容を保持するローカル変数。
(defun japanlaw-abbrev ()
  "略称法令名のインデックスファイルをロードする関数。"
  (or japanlaw-abbrev
      (and (file-exists-p japanlaw-abbrev-file)
	   (setq japanlaw-abbrev
		 (with-temp-buffer
		   (insert-file-contents japanlaw-abbrev-file)
		   (read (current-buffer)))))))

;; Search
(defun japanlaw-names-alist ()
  (or japanlaw-names-alist
      (setq japanlaw-names-alist
	    (cons (do ((xs (japanlaw-alist) (cdr xs))
		       (result nil))
		      ((null xs) result)
		    (do ((ys (cdar xs) (cdr ys)))
			((null ys))
		      (push (car ys) result)))
		  (do ((xs (japanlaw-abbrev-alist) (cdr xs))
		       (result nil))
		      ((null xs) result)
		    (do ((ys (cdr (cdar xs)) (cdr ys)))
			((null ys))
		      (push (cons (caar ys) (cdr (cdar ys))) result)))))))

(defun japanlaw-search-alist ()
  japanlaw-search-alist)

;; Index
;; `japanlaw-alist'から生成した、`japanlaw-index'のIndexモードで利用する連想リスト。
(defun japanlaw-index-alist ()
  "`japanlaw-index-alist'を生成する関数。"
  (or japanlaw-index-alist
      (setq japanlaw-index-alist
	    (do ((xs (japanlaw-alist) (cdr xs))
		 (result nil))
		((null xs) (nreverse result))
	      (push (cons (caar xs)
			  (cons nil
				(do ((ys (cdar xs) (cdr ys))
				     (acc nil))
				    ((null ys) (nreverse acc))
				  (push (cons (concat (car (caar ys)) (cdr (caar ys)))
					      (cdar ys))
					acc))))
		    result)))))

;; Directory
;; `japanlaw-alist'から生成した、`japanlaw-index'のDirectoryモードで利用する連想リスト。
(defun japanlaw-directory-alist ()
  "`japanlaw-directory-alist'を生成する関数。"
  (or japanlaw-directory-alist
      (setq japanlaw-directory-alist
	    (let ((dirs (do ((xs (japanlaw-alist) (cdr xs))
			     (result nil))
			    ((null xs)
			     (sort result
				   (lambda (x y) (string< (car x) (car y)))))
			  (let ((category (caar xs)))
			    (do ((ys (cdar xs) (cdr ys)))
				((null ys))
			      (let ((gengo (substring (cdar ys) 0 3)))
				(push (cons gengo
					    (cons (concat category ":"
							  (car (caar ys))
							  (cdr (caar ys)))
						  (cdar ys)))
				      result)))))))
	      (let* ((s0 (make-string 2 0))
		     ;; dirsをソートする比較関数
		     (compfun (lambda (x y)
				(let ((s1 (aref (car x) 0))
				      (s2 (aref (car y) 0)))
				  (if (= s1 s2)
				      (let ((n1 (string-to-number
						 (progn
						   (aset s0 0 (aref (car x) 1))
						   (aset s0 1 (aref (car x) 2))
						   s0)))
					    (n2 (string-to-number
						 (progn
						   (aset s0 0 (aref (car y) 1))
						   (aset s0 1 (aref (car y) 2))
						   s0))))
					(> n1 n2))
				    (cond ((or (= s1 ?H)
					       (= s2 ?H)) nil)
					  ((or (= s1 ?M)
					       (= s2 ?M)) t)
					  ((or (= s1 ?S)
					       (= s2 ?S)) nil)
					  (t t)))))))
		;; 同じ年数の要素を集める。
		(let ((result nil)
		      (ls (sort dirs compfun)))
		  (while ls
		    (let ((tmp (caar ls)))
		      (push (cons tmp
				  (cons nil ; closed flag
					(let ((acc nil))
					  (while (string= (caar ls) tmp)
					    (push (cdar ls) acc)
					    (pop ls))
					  acc)))
			    result)))
		  (nreverse result)))))))

;; Abbrev
;; `japanlaw-abbrev'から生成した、`japanlaw-index'のAbbrevモードで利用する連想リスト。
(defun japanlaw-abbrev-alist ()
  "`japanlaw-abbrev-alist'を生成する関数。"
  (or japanlaw-abbrev-alist
      (setq
       japanlaw-abbrev-alist
       (do ((xs (japanlaw-abbrev) (cdr xs))
	    (result nil))
	   ((null xs) (nreverse result))
	 (push (cons (caar xs)
		     (cons nil		; closed flag
			   (do ((ys (cdar xs) (cdr ys))
				(acc nil))
			       ((null ys) (nreverse acc))
			     (push (cons (caar ys)
					 (cons nil ; closed flag
					       (do ((zs (cdar ys) (cdr zs))
						    (acc nil))
						   ((null zs) (nreverse acc))
						 (push (cons (caar zs)(cdar zs))
						       acc))))
				   acc))))
	       result)))))

;; Bookmark
(defun japanlaw-bookmark-alist ()
  "ブックマークの連想リストを返す関数。"
  (or japanlaw-bookmark-alist
      (and (file-exists-p japanlaw-bookmark-file)
	   (setq japanlaw-bookmark-alist
		 (with-temp-buffer
		   (insert-file-contents japanlaw-bookmark-file)
		   (read (current-buffer)))))))

(defun japanlaw-bookmark-save ()
  "ブックマークファイル:`japanlaw-bookmark-file'に
`japanlaw-bookmark-alist'を出力する。変更がなかった場合は出力しない。"
  (ignore-errors
    (when (and japanlaw-bookmark-file
	       (file-exists-p (file-name-directory japanlaw-bookmark-file)))
      (with-temp-buffer
	(save-excursion
	  (if (file-exists-p japanlaw-bookmark-file)
	      (insert-file-contents japanlaw-bookmark-file)
	    (princ nil (current-buffer))))
	(unless (equal (read (current-buffer)) (japanlaw-bookmark-alist))
	  (with-temp-file japanlaw-bookmark-file
	    (insert (format "%S" japanlaw-bookmark-alist))
	    (message "Wrote %s" japanlaw-bookmark-file))
	  t)))))

(defun japanlaw-convert-files ()
  "Bookmark's format change in v0.8.5 from v0.8.4."
  ;; Bookmark
  (when (and japanlaw-bookmark-file
	     (file-exists-p (file-name-directory japanlaw-bookmark-file))
	     (file-exists-p japanlaw-bookmark-file))
    (with-temp-buffer
      (save-excursion (insert-file-contents japanlaw-bookmark-file))
      (let ((alist (read (current-buffer))))
	(when (consp (car alist))
	  (with-temp-file japanlaw-bookmark-file
	    (insert (format "%S" (mapcar (lambda (x) (upcase (cdr x))) alist)))
	    (message "Wrote %s" japanlaw-bookmark-file))
	  (setq japanlaw-bookmark-alist nil)
	  (japanlaw-bookmark-alist)))))
  ;; Recent
  (when (and japanlaw-recent-file
	     (file-exists-p (file-name-directory japanlaw-recent-file))
	     (file-exists-p japanlaw-recent-file))
    (with-temp-buffer
      (save-excursion (insert-file-contents japanlaw-recent-file))
      (let ((alist (read (current-buffer))))
	(with-temp-file japanlaw-recent-file
	  (insert (format "%S" (mapcar (lambda (x) (upcase x)) alist))))
	(message "Wrote %s" japanlaw-recent-file)
	(setq japanlaw-recent-alist nil)
	(japanlaw-recent-alist)))))

;; Opened

(defun japanlaw-opened-alist ()
  "現在開いている法令データの連想リストを返す。"
  ;; 法令データかどうかは、パスファイル名が法令データのパスファイル名と等しい
  ;; かどうかで判定。ディレクトリは大文字、urlは小文字。
  (japanlaw-make-alist-from-name
   (lambda ()
     (japanlaw-labels ((nameof (file) (japanlaw-file-sans-name file)))
       (mapcar #'nameof
	       (japanlaw:filter
		(lambda (file)
		  (string= (japanlaw-expand-data-file (nameof file))
			   file))
		(delete nil (mapcar #'buffer-file-name (buffer-list)))))))))

;; Recent
(defun japanlaw-recent-alist ()
  "最近開いたファイルの連想リストを返す。"
  (or japanlaw-recent-alist
      (and (file-exists-p japanlaw-recent-file)
	   (setq japanlaw-recent-alist
		 (with-temp-buffer
		   (insert-file-contents japanlaw-recent-file)
		   (read (current-buffer)))))))

(defun japanlaw-recent-add ()
  (ignore-errors
    (let ((name (upcase (japanlaw-file-sans-name (buffer-file-name)))))
      (when (string= (buffer-file-name)
		     (japanlaw-expand-data-file name))
	(setq japanlaw-recent-alist (cons name (delete name (japanlaw-recent-alist))))
	(when (> (length japanlaw-recent-alist) japanlaw-recent-max)
	  (setq japanlaw-recent-alist
		(butlast japanlaw-recent-alist
			 (- (length japanlaw-recent-alist) japanlaw-recent-max))))))))

(defun japanlaw-recent-save ()
  "最近開いた法令ファイル: `japanlaw-recent-file'に
`japanlaw-recent-alist'を出力する。変更がなかった場合は出力しない。"
  (ignore-errors
    (when (and japanlaw-recent-file
	       (file-exists-p (file-name-directory japanlaw-recent-file)))
      (with-temp-buffer
	(save-excursion
	  (if (file-exists-p japanlaw-recent-file)
	      (insert-file-contents japanlaw-recent-file)
	    (princ nil (current-buffer))))
	(unless (equal (read (current-buffer)) (japanlaw-recent-alist))
	  (with-temp-file japanlaw-recent-file
	    (insert (format "%S" japanlaw-recent-alist))
	    (message "Wrote %s" japanlaw-recent-file))
	  t)))))

;;
;; Insert contents
;;
(defun japanlaw-index-insert-contents (mode)
  "各モードごとにツリーの挿入処理を分岐する。"
  ;;(japanlaw-save-)
  (japanlaw-with-buffer-read-only (erase-buffer))
  (case mode
    (Opened	(japanlaw-index-insert-opened))
    (Recent	(japanlaw-index-insert-recent))
    (Search	(japanlaw-index-insert-search))
    (Bookmark	(japanlaw-index-insert-bookmark))
    (Index	(japanlaw-index-insert-index))
    (Directory	(japanlaw-index-insert-directory))
    (Abbrev	(japanlaw-index-insert-abbrev))))

;; Common
(defun japanlaw-make-alist-from-name (lfunc)
  "NAME(\"M29HO089\"のような形式)から法令名とNAMEの連想リストを生成する関数。
LFUNCは、NAMEからなるリストを返す関数。"
  (mapcar (lambda (name)
	    (or (block nil
		  (do ((xs (japanlaw-alist) (cdr xs)))
		      ((null xs))
		    (let ((cell (rassoc (upcase name) (cdar xs))))
		      (when cell
			(return (cons (concat (caar cell) (cdar cell))
				      (cdr cell)))))))
		(cons "未登録法令" name)))
	  (funcall lfunc)))

(defun japanlaw-index-insert-alist-function (func)
  "Index,Directoryで、ツリーの挿入処理をする関数。"
  (let ((alist (funcall func)))
    (case japanlaw-index-local-mode
      ((Index Directory)
       (japanlaw-with-buffer-read-only
	;; Test:
	;; (error Lisp nesting exceeds `max-lisp-eval-depth')
	;; (japanlaw-index-search-insert-func alist)
	(while alist
	  (let ((cel (car alist))
		(opened (car (cdar alist))))
	    (insert (format "%S\n" `(,(if opened "-" "+") ,(car cel))))
	    (when opened
	      (do ((xs (cddr cel) (cdr xs)))
		  ((null xs))
		(insert (format "%S\n" `("  -" ,(caar xs) ,(cdar xs)))))))
	  (pop alist)))
       )
      ((Abbrev)
       (japanlaw-with-buffer-read-only
	;; Test:
	;; (error Lisp nesting exceeds `max-lisp-eval-depth')
	;; (japanlaw-index-search-insert-func alist)
	(do ((xs alist (cdr xs)))
	    ((null xs))
	  (let ((opened (car (cdar xs))))
	    (insert (format "%S\n" `(,(if opened "-" "+") ,(caar xs))))
	    (when opened
	      (do ((ys (cdr (cdar xs)) (cdr ys)))
		  ((null ys))
		(let ((opened (car (cdar ys)))) ;error
		  (insert (format "%S\n" `(,(if opened "  -" "  +") ,(caar ys))))
		  (when opened
		    (do ((zs (cdr (cdar ys)) (cdr zs)))
			((null zs))
		      (insert (format "%S\n" `("    -" ,(caar zs) ,(cdar zs))))))))))))
       )
      ((Bookmark Opened Recent)
       (japanlaw-with-buffer-read-only
	(while alist
	  (insert (format "%S\n" `(" -" ,(caar alist) ,(cdar alist))))
	  (pop alist))))
      ((Search)
       (japanlaw-with-buffer-read-only
	(japanlaw-index-search-insert-func alist))
       (japanlaw-index-highlight-search-buffer))
      )))

;; recursion
(defun japanlaw-index-search-insert-func (alist)
  (unless (null alist)
    (let* ((cell (car alist))
	   (opened (cadr cell)))
      ;; 検索式
      (insert (format "%S\n" `(,(if opened "-" "+") ,(car cell))))
      ;; 完全一致,略称法令名検索,法令名検索結果を再帰的に挿入
      (japanlaw-labels
	  ((rec (ls)
                (unless (null ls)
                  (let* ((cell (car ls))
                         (opened (cadr cell)))
                    (insert
                     (format "%S\n" `(,(if opened "  -" "  +") ,(car cell))))
                    (when opened
                      (let ((cell (cddr cell)))
                        (do ((xs cell (cdr xs)))
                            ((null xs))
                          (if (atom (cdar xs))
                              (insert
                               (format "%S\n" `("    -" ,(caar xs) ,(cdar xs))))
                            (let ((opened (car (cdar xs))))
                              (insert (format "%S\n" `(,(if opened "    -" "    +")
                                                       ,(caar xs))))
                              (when opened
                                (do ((ys (cdr (cdar xs)) (cdr ys)))
                                    ((null ys))
                                  (insert
                                   (format "%S\n" `("      -" ,(caar ys)
                                                    ,(cdar ys))))))))))))
                  (rec (cdr ls)))))
	(when opened (rec (cddr cell)))))
    (japanlaw-index-search-insert-func (cdr alist))))

;; Opened
(defun japanlaw-index-insert-opened ()
  (japanlaw-index-insert-alist-function #'japanlaw-opened-alist))

;; Recent
(defun japanlaw-index-insert-recent ()
  (japanlaw-index-insert-alist-function
   (lambda () (japanlaw-make-alist-from-name #'japanlaw-recent-alist))))

;; Search
(defun japanlaw-index-insert-search ()
  (japanlaw-index-insert-alist-function #'japanlaw-search-alist))

;; Bookmark
(defun japanlaw-index-insert-bookmark ()
  (japanlaw-index-insert-alist-function
   (lambda () (japanlaw-make-alist-from-name #'japanlaw-bookmark-alist))))

;; Index
(defun japanlaw-index-insert-index ()
  "Indexで、バッファにツリーを挿入する。"
  (japanlaw-index-insert-alist-function #'japanlaw-index-alist))

;; Directory
(defun japanlaw-index-insert-directory ()
  "Directoryで、バッファにツリーを挿入する。"
  (japanlaw-index-insert-alist-function #'japanlaw-directory-alist))

;; Abbrev
(defun japanlaw-index-insert-abbrev ()
  "Abbrevで、バッファにツリーを挿入する。"
  (japanlaw-index-insert-alist-function #'japanlaw-abbrev-alist))

;;
;; Open or close
;;

;; Common
(defsubst japanlaw-index-folder-level ()
  (let ((level (member (japanlaw-get-values #'car)
		       '("+" "-" "  +" "  -" "    +" "    -" "      -"))))
    (if level
	(/ (1- (length (car level))) 2)
      -1)))

(defsubst japanlaw-index-folder-level-0 ()
  "folderの階層が最上位なら非nilを返す。"
  (zerop (japanlaw-index-folder-level)))

(defsubst japanlaw-index-folder-level-1 ()
  "folderの階層が1番目なら非nilを返す。"
  (= (japanlaw-index-folder-level) 1))

(defsubst japanlaw-index-folder-level-2 ()
  "フォルダの階層が2番目なら非nilを返す。"
  (= (japanlaw-index-folder-level) 2))

(defsubst japanlaw-index-folder-level-3 ()
  "フォルダの階層が3番目なら非nilを返す。"
  (= (japanlaw-index-folder-level) 3))

(defsubst japanlaw-index-not-folder-p ()
  "アイテムがフォルダでないとき真を返す。"
  (and (not (japanlaw-index-folder-level-0))
       (not (japanlaw-index-folder-level-1))
       (not (japanlaw-index-folder-level-2))))

(defsubst japanlaw-index-folder-open-p ()
  "folderが開いていれば非nilを、閉じていればnilを返す。"
  (save-excursion
    (forward-line 0)
    (and (re-search-forward "\" *-\"" (line-end-position) t) t)))

(defun japanlaw-index-open-or-close ()
  "フォルダなら開閉し、法令ならその法令を開くコマンド。"
  (interactive)
  (apply #'funcall
	 (let ((mode japanlaw-index-local-mode))
	   (case mode
	     (Opened		`(japanlaw-index-opened-oc))
	     (Recent		`(japanlaw-index-recent-oc))
	     (Search		`(japanlaw-index-search-oc))
	     (Bookmark		`(japanlaw-index-bookmark-oc))
	     (Index		`(japanlaw-index-index-oc))
	     (Directory		`(japanlaw-index-directory-oc))
	     (Abbrev		`(japanlaw-index-abbrev-oc)))))
  ;; 開いた場合、次が実行されるのは問題か。
  (japanlaw-index-move-to-column))

(defun japanlaw-index-browse-at-point ()
  ;; メニューコマンド
  (interactive)
  (let ((id (car (nth 2 (japanlaw-get-values)))))
    (if id
	(browse-url (japanlaw-expand-htmldata-url id))
      (message "No url at point."))))

(defun japanlaw-index-mouse-open-or-close (event)
  "マウスでフォルダの開閉、法令を開くコマンド。"
  (interactive "e")
  (set-buffer (window-buffer (posn-window (event-end event))))
  (goto-char (posn-point (event-end event)))
  (japanlaw-index-open-or-close)
  (when (japanlaw-index-folder-level-0) (recenter 0)))

(defun japanlaw-retrieve-index ()
  "インデックスファイルを取得し直す。最後に取得してから更新があっ
た場合、番号付きバックアップを生成する。"
  (interactive)
  (unless (eq major-mode 'japanlaw-index-mode)
    (error "Try in japanlaw-index-mode."))
  (let ((updated (japanlaw-make-index-files 'regenerate))
	msg)
    ;; Abbreves
    (cond ((cdr updated)
	   (setq japanlaw-abbrev-alist nil)
	   (push "Abbrevs was updated." msg))
	  (t (push "Abbrevs was not updated." msg)))
    ;; Index
    (cond ((car updated)
	   (setq japanlaw-alist nil)
	   (push "Index was updated." msg))
	  (t (push "Index was not updated." msg)))
    (when (and (or (car updated) (cdr updated))
	       (get-buffer japanlaw-index-buffer))
      (kill-buffer japanlaw-index-buffer)
      (japanlaw-index))
    (message (mapconcat 'identity msg "  "))))

(defun japanlaw-retrieve-html ()
  "ポイント位置のHTMLデータを再取得。最後に取得してから更新があっ
た場合、番号付きバックアップを生成する。"
  (interactive)
  (let ((id (cond ((eq major-mode 'japanlaw-index-mode)
		   (car (nth 2 (japanlaw-get-values))))
		  ((eq major-mode 'japanlaw-mode)
		   (upcase (japanlaw-file-sans-name (buffer-file-name))))
		  (t (error "Try in japanlaw-index-mode or japanlaw-mode.")))))
    (when (and (japanlaw-get-name id)
	       (or japanlaw-online-mode
		   (japanlaw-online-mode-message #'error))
	       (y-or-n-p "Retrieve htmldata from egov? "))
      (let ((html (japanlaw-expand-htmldata-file id))
	    (file (japanlaw-expand-data-file id)))
	(japanlaw-htmldata-retrieve id 'force)
	(let ((buffer (get-file-buffer file)))
	  (when (and buffer
		     ;; 更新された場合 => nil
		     (not (verify-visited-file-modtime buffer)))
	    (kill-buffer buffer)))
	(japanlaw-open-file id)))))

(defun japanlaw-index-open-all ()
  "`Index'で、すべてのフォルダを開くコマンド。"
  (interactive)
  (apply #'funcall
	 (let ((mode japanlaw-index-local-mode))
	   (case mode
	     ;;(Opened `(japanlaw-index-opened-oc ,mode))
	     ;;(Recent `(japanlaw-index-recent-oc ,mode))
	     ;;(Search `(japanlaw-index-search-oc ,mode))
	     ;;(Bookmark `(japanlaw-index-bookmark-oc ,mode))
	     (Index `(japanlaw-index-index-oc-all t))
	     (Directory `(japanlaw-index-directory-oc-all t))
	     (Abbrev `(japanlaw-index-abbrev-oc-all t))
	     (t (error "Not supported."))))))

(defun japanlaw-index-close-all ()
  "`Index'で、すべてのフォルダを閉じるコマンド。"
  (interactive)
  (apply #'funcall
	 (let ((mode japanlaw-index-local-mode))
	   (case mode
	     ;;(Opened `(japanlaw-index-opened-oc nil))
	     ;;(Recent `(japanlaw-index-recent-oc nil))
	     ;;(Search `(japanlaw-index-search-oc nil))
	     ;;(Bookmark `(japanlaw-index-bookmark-oc nil))
	     (Index `(japanlaw-index-index-oc-all nil))
	     (Directory `(japanlaw-index-directory-oc-all nil))
	     (Abbrev `(japanlaw-index-abbrev-oc-all nil))
	     (t (error "Not supported."))))))

(defun japanlaw-index-folder-toggle-state ()
  "フォルダの開閉フラグをトグルする。"
  (forward-line 0)
  (when (re-search-forward "[+-]" (line-end-position) t)
    (replace-match
     (string (+ (- ?- (string-to-char (match-string 0))) ?+)))))

(defun japanlaw-index-upper-level ()
  "ひとつ上の階層に移動するコマンド。"
  (interactive)
  (let ((level (japanlaw-index-folder-level)))
    (when (> level 0)
      (while (> (1+ (japanlaw-index-folder-level)) level)
	(forward-line -1))
      (japanlaw-index-move-to-column))))

;; Index and Directory
(defun japanlaw-index-set-alist (name opened func)
  "連想リストのキーがNAMEのフォルダの開閉フラグを(not opened)にセットする。
FUNCは連想リストを返す関数。"
  (let ((cell (cdr (assoc name (funcall func)))))
    (setcar cell (not opened))
    (cdr cell)))

(defun japanlaw-index-folder (name opened func)
  "`Index'と`Directory'で、フォルダの開閉を処理する関数。"
  (let ((cell (japanlaw-index-set-alist name opened func)))
    (if opened
	(japanlaw-with-buffer-read-only
	 (let ((start (progn (forward-line 1) (point)))
	       (end (progn (while (and (not (eobp))
				       (not (japanlaw-index-folder-level-0)))
			     (forward-line 1))
			   (point))))
	   (unless (= start end)
	     (delete-region start end)
	     (forward-line -1)
	     (japanlaw-index-folder-toggle-state))))
      ;; closed
      (japanlaw-with-buffer-read-only
       (japanlaw-index-folder-toggle-state)
       (forward-line 1)
       (do ((xs cell (cdr xs)))
	   ((null xs))
	 (insert (format "%S\n" `("  -" ,(caar xs) ,(cdar xs)))))
       (japanlaw-index-upper-level)))))

(defun japanlaw-open-file (id)
  (let* ((file (japanlaw-expand-data-file id))
	 (buffer (get-file-buffer file)))
    (switch-to-buffer
     (or buffer
	 (prog1 (set-buffer
		 (find-file-noselect
		  (if (file-exists-p file)
		      file
		    (japanlaw-make-data id 'force))))
	   (japanlaw-mode))))
    (japanlaw-recent-add)))

(defun japanlaw-index-index-oc-function (func)
  "`Index',`Directory'で、フォルダなら開閉をし法令名なら開く。"
  (let* ((values (japanlaw-get-values))
	 (name (cadr values))
	 (id (car (nth 2 values))))
    (if (japanlaw-index-folder-level-0)
	;; folder open or close
	(japanlaw-index-folder name (japanlaw-index-folder-open-p) func)
      ;; file open
      (unless id (error "Not a law data."))
      (save-excursion
	(forward-line 0)
	(japanlaw-open-file id)))))

(defun japanlaw-index-index-oc-all-function (open afunc ifunc)
  "`Index',`Directory'で、すべてのフォルダの開閉をする。
AFUNCは連想リストを返す関数。IFUNCはツリーの挿入処理をする関数。"
  (save-excursion
    (do ((alist (funcall afunc) (cdr alist)))
	((null alist))
      (setcar (cdar alist) open))
    (japanlaw-with-buffer-read-only (erase-buffer))
    (funcall ifunc)))

;; Opened

;; Recent

(defun japanlaw-index-search-oc ()
  "`Search'で、フォルダなら開閉をし、法令名なら開く。"
  (let ((name (japanlaw-get-values #'cadr))
	(keys nil))
    (unless name (error "Not a law data."))
    (if (japanlaw-get-values (lambda (x) (nth 2 x)))
	(japanlaw-open-file (car (japanlaw-get-values (lambda (x) (nth 2 x)))))
      (let ((cell (save-excursion
		    (dotimes (x (japanlaw-index-folder-level))
		      (japanlaw-index-upper-level)
		      (push (japanlaw-get-values #'cadr) keys))
		    (assoc (japanlaw-get-values #'cadr) (japanlaw-search-alist)))))
	(japanlaw-index-set-search-alist
	 cell keys name (japanlaw-index-folder-open-p))))))

(defun japanlaw-index-set-search-alist (cell keys name opened)
  "`japanlaw-search-alist'のCELLの中でキーがNAMEのフォルダの開閉フラグ
を(not opened)に変更してバッファを更新する。"
  (case (length keys)
    (0 (setcar (cdr cell) (not opened)))
    (1 (setcar (cdr (assoc name cell)) (not opened)))
    (2 (setcar (cdr (assoc name (cdr (assoc (cadr keys) cell))))
	       (not opened))))
  (unless (japanlaw-index-goto-mode 'Search)
    (let ((line (line-number-at-pos)))
      (japanlaw-with-buffer-read-only
       (erase-buffer)
       (japanlaw-index-search-insert-func (japanlaw-search-alist)))
      (japanlaw-index-highlight-search-buffer)
      (japanlaw-goto-line line))))

;; Opened
(defun japanlaw-index-opened-oc ()
  "`Opened'で、法令ファイルに切り替える。"
  (japanlaw-index-index-oc-function #'japanlaw-opened-alist))

;; Recent
(defun japanlaw-index-recent-oc ()
  "`Recent'で、法令ファイルに切り替える。"
  (japanlaw-index-index-oc-function
   (lambda () (japanlaw-make-alist-from-name #'japanlaw-recent-alist))))

;; Bookmark
(defun japanlaw-index-bookmark-oc ()
  "`Bookmark'で、法令ファイルを開く。"
  (japanlaw-index-index-oc-function
   (lambda () (japanlaw-make-alist-from-name #'japanlaw-bookmark-alist))))

;; Index
(defun japanlaw-index-index-oc ()
  "`Index'で、フォルダの開閉をする。"
  (japanlaw-index-index-oc-function #'japanlaw-index-alist))

(defun japanlaw-index-index-oc-all (open)
  "`Index'で、すべてのフォルダの開閉をする。"
  (japanlaw-index-index-oc-all-function
   open #'japanlaw-index-alist #'japanlaw-index-insert-index))

;; Directory
(defun japanlaw-index-directory-oc ()
  "`Directory'で、フォルダの開閉をする。"
  (japanlaw-index-index-oc-function #'japanlaw-directory-alist))

(defun japanlaw-index-directory-oc-all (open)
  "`Directory'で、すべてのフォルダの開閉をする。"
  (japanlaw-index-index-oc-all-function
   open #'japanlaw-directory-alist #'japanlaw-index-insert-directory))

;; Abbrev
(defun japanlaw-index-set-abbrev-alist (name opened)
  "`japanlaw-abbrev-alist'のフォルダの開閉フラグをセットする関数。"
  (cond ((japanlaw-index-folder-level-1)
	 ;; sub folder
	 (save-excursion
	   (japanlaw-index-upper-level)
	   (let ((cell
		  (cdr (assoc (japanlaw-get-values #'cadr) (japanlaw-abbrev-alist)))))
	     (let ((cell (cdr (assoc name cell))))
	       (setcar cell (not opened))
	       (cdr cell)))))
	((japanlaw-index-folder-level-0)
	 ;; folder
	 (let ((cell (cdr (assoc name (japanlaw-abbrev-alist)))))
	   (setcar cell (not opened))
	   (cdr cell)))))

(defun japanlaw-index-abbrev-folder (name opened sub)
  "`Abbrev'で、フォルダの開閉を処理する関数。"
  (let ((cell (japanlaw-index-set-abbrev-alist name opened)))
    (unless (> (japanlaw-index-folder-level) 1)
      (if opened
	  (japanlaw-with-buffer-read-only
	   (let ((start (progn (forward-line 1) (point)))
		 (end (progn (while (and (not (eobp))
					 (not (if sub
						  (/= (japanlaw-index-folder-level) 2)
						(japanlaw-index-folder-level-0))))
			       (forward-line 1))
			     (point))))
	     (unless (= start end)
	       (delete-region start end)
	       (forward-line -1)
	       (japanlaw-index-folder-toggle-state))))
	;; closed
	(japanlaw-with-buffer-read-only
	 (japanlaw-index-folder-toggle-state)
	 (forward-line 1)
	 (if sub
	     ;; sub folder
	     (do ((zs cell (cdr zs)))
		 ((null zs))
	       (insert (format "%S\n" `("    -" ,(caar zs) ,(cdar zs)))))
	   ;; folder
	   (do ((ys cell (cdr ys)))
	       ((null ys))
	     (let ((opened (car (cdar ys))))
	       (insert (format "%S\n" `(,(if opened "  -" "  +") ,(caar ys))))
	       (when opened
		 (do ((zs (cdr (cdar ys)) (cdr zs)))
		     ((null zs))
		   (insert (format "%S\n" `("    -" ,(caar zs) ,(cdar zs)))))))))
	 (japanlaw-index-upper-level))))))

(defun japanlaw-index-abbrev-oc ()
  "`Abbrev'で、フォルダなら開閉し法令なら開く。"
  (let* ((values (japanlaw-get-values))
	 (name (cadr values))
	 (id (nth 2 values)))
    (if (< (japanlaw-index-folder-level) 2)
	;; menu open or close
	(japanlaw-index-abbrev-folder
	 name (japanlaw-index-folder-open-p) (japanlaw-index-folder-level-1))
      ;; file open
      (japanlaw-open-file (car id)))))

(defun japanlaw-index-abbrev-oc-all (open)
  "`Abbrev'で、すべてのフォルダの開閉をする。"
  (japanlaw-index-index-oc-all-function
   open #'japanlaw-abbrev-alist #'japanlaw-index-insert-abbrev))

;;
;; Search
;;
(defalias 'japanlaw-search 'japanlaw-index-search
  "法令名(略称法令名を含む)を検索するコマンド。引数付きで実行した
場合は、以前の検索結果を初期化しない。")

(defun japanlaw-index-search (rx &optional noclear)
  "法令名(略称法令名を含む)を検索するコマンド。引数付きで実行した
場合は、以前の検索結果を初期化しない。"
  (interactive (japanlaw-index-search-interactive))
  (japanlaw-labels
      ((display-result (rx names abbreves complete noclear)
                       (unless noclear (setq japanlaw-search-alist nil))
                       ;; t: opened flag
                       (push
                        (list (format "検索式 `%s'" rx) t
                              `(,(format "法令名完全一致 該当件数 %d" (length complete)) t ,@complete)
                              `(,(format "略称法令名検索 該当件数 %d" (length abbreves)) t ,@abbreves)
                              `(,(format "法令名検索 該当件数 %d" (length names)) t ,@names))
                        japanlaw-search-alist)
                       ;; バッファ更新
                       ;; japanlaw-index-goto-mode: Return nil if same local-mode.
                       (unless (japanlaw-index-goto-mode 'Search)
                         (japanlaw-with-buffer-read-only (erase-buffer))
                         (japanlaw-index-insert-alist-function #'japanlaw-search-alist))))
    (let ((complete nil))
      (message "Searching...")
      (display-result
       ;; 検索式
       rx
       ;; 法令名検索
       (do ((xs (car (japanlaw-names-alist)) (cdr xs))
	    (names-search nil))
	   ((null xs) names-search)
	 (let ((name (car (caar xs)))
	       (name2 (cdr (caar xs))))
	   ;; 民法（民法第一編第二編第三編）（明治二十九年四月二十七日法律第八十九号）
	   ;; のうち、括弧を除いた部分の検索。
	   (when (string-match rx name)
	     (let ((match (cons (concat name (cdr (caar xs))) (cdar xs))))
	       (if (string= name rx)
		   ;; 完全一致(民法など複数マッチする場合がある)
		   (push match complete)
		 ;; 一部一致
		 ;; 完全一致、また既に一部一致に含まれる場合は、consしない。
		 (unless (or (member match names-search)
			     (member match complete))
		   (push match names-search)))))
	   ;; 後半の括弧部分の検索(括弧内も検索対象に入れる)。
	   ;; 完全一致、また既に一部一致に含まれる場合は、consしない。
	   (when (string-match rx name2)
	     (let ((match (cons (concat name (cdr (caar xs))) (cdar xs))))
	       (unless (or (member match names-search)
			   (member match complete))
		 (push match names-search))))))
       ;; 略称法令名検索
       (do ((xs (cdr (japanlaw-names-alist)) (cdr xs))
	    (abbrev-search nil))
	   ((null xs) abbrev-search)
	 (when (string-match rx (caar xs))
	   ;; nil: closed flag
	   (push (cons (caar xs) (cons nil (cdar xs))) abbrev-search)))
       ;; 完全一致
       complete
       ;; 以前の検索結果の初期化。
       noclear)
      (message (concat (current-message) "done")))))

(defun japanlaw-index-search-interactive ()
  (unless (file-exists-p japanlaw-index-file)
    (error "Try `M-x japanlaw'"))
  (when japanlaw-setup-p (japanlaw-setup))
  (let ((rx (read-string "Search: " nil 'japanlaw-search-history)))
    (when (equal rx "")
      (error ""))
    (unless (eq major-mode 'japanlaw-index-mode)
      (if (get-buffer japanlaw-index-buffer)
	  (switch-to-buffer japanlaw-index-buffer)
	(japanlaw-index)))
    (when (assoc (format "検索式 `%s'" rx) japanlaw-search-alist)
      (error "`%s' is retrieved." rx))
    (list rx current-prefix-arg)))

;; Searchモードで検索結果をハイライトする
(defun japanlaw-index-highlight-search-buffer ()
  (japanlaw-labels
      ((put-overlay ()
                    (let ((rx (and (re-search-forward
                                    "`\\(.+?\\)'" (line-end-position) t)
                                   (match-string 1))))
                      ;; 検索式
                      (overlay-put
                       (car (push (make-overlay (match-beginning 1)
                                                (match-end 1))
                                  japanlaw-index-search-overlaies))
                       'face '(:foreground "red"))
                      ;; 検索結果
                      (forward-line 1)
                      (while (and (/= (japanlaw-index-folder-level) 0)
                                  (not (eobp)))
                        (while (= (japanlaw-index-folder-level) 1)
                          (forward-line 1))
                        (when (>= (japanlaw-index-folder-level) 2)
                          (let* ((end (re-search-forward "[-+]\" \"\\(.+?\\)\""
                                                         (line-end-position) t))
                                 (beg (and end (match-beginning 1))))
                            (when (and beg
                                       (string-match
                                        rx (buffer-substring-no-properties beg end)))
                              (overlay-put
                               (car (push (make-overlay (+ beg (match-beginning 0))
                                                        (+ beg (match-end 0)))
                                          japanlaw-index-search-overlaies))
                               'face 'match)))
                          (forward-line 1)))
                      (and (= (japanlaw-index-folder-level) 0)
                           (put-overlay)))))
    (mapc 'delete-overlay japanlaw-index-search-overlaies)
    (setq japanlaw-index-search-overlaies nil)
    (save-excursion
      (goto-char (point-min))
      (unless (eobp) (put-overlay)))))

;;
;; Bookmark
;;
(defun japanlaw-index-bookmark-add ()
  "ブックマークに法令名を追加するコマンド。
ファイル:`japanlaw-bookmark-file'に書き出す。"
  (interactive)
  (unless (eq japanlaw-index-local-mode 'Bookmark)
    (condition-case err
	(destructuring-bind (flag name id) (japanlaw-get-values)
	  (unless id (error "Not a law data."))
	  (let ((id (car id)))
	    (if (member id (japanlaw-bookmark-alist))
		(message "Already exists in Bookmark.")
	      (push id japanlaw-bookmark-alist)
	      (message "Add to Bookmark `%s'" name))))
      (error nil))))

(defun japanlaw-index-put-deletion-flag ()
  "Bookmark,Opened,Recentで削除マークを付ける。"
  (interactive)
  (when (member japanlaw-index-local-mode '(Opened Recent Bookmark))
    (japanlaw-with-buffer-read-only
     (forward-line 0)
     (when (re-search-forward "\\([ D]\\)-" (line-end-position) t)
       (replace-match
	(string (+ (- ?D (string-to-char (match-string 1))) ?\ ))
	nil nil nil 1)))
    (forward-line 1)
    (when (eobp) (goto-char (point-min)))
    (japanlaw-index-move-to-column)))

(defun japanlaw-index-get-cells (&optional marks)
  "バッファからブックマークの各項目を取得して返す。
MARKSが非nilなら削除マークが付いた項目のみ。"
  (save-excursion
    (let ((result nil))
      (goto-char (point-min))
      (while (search-forward (if marks "\"D-" " -") nil t)
	(destructuring-bind (flag name id) (japanlaw-get-values)
	  (push (car id) result)))
      (nreverse result))))

(defun japanlaw-index-do-delete-marks ()
  "Bookmark,Opened,Recentで、削除マーク`D'が付いた項目を削除する。
Bookmarkの場合、ファイル:`japanlaw-bookmark-file'に書き出す。
Openedの場合、ファイルを閉じる。"
  (interactive)
  (japanlaw-labels
      ((delalist (alist &optional form)
                 ;; ALIST is a symbol. Return a function.
                 `(lambda ()
                    (mapc (lambda (cel)
                            (setq ,alist (delete cel (funcall (function ,alist)))))
                          (or ,form (japanlaw-index-get-cells 'marks))))))
    (case japanlaw-index-local-mode
      (Bookmark
       (funcall
	(delalist 'japanlaw-bookmark-alist
		  '(mapcar (lambda (x) (upcase x))
                           (japanlaw-index-get-cells 'marks))))
       (japanlaw-with-buffer-read-only (erase-buffer))
       (japanlaw-index-insert-bookmark))
      (Opened
       (mapc (lambda (cel)
	       (kill-buffer
		(get-file-buffer (japanlaw-expand-data-file cel))))
	     ;; mapc(delalist) returns it's arg identical.
	     (funcall (delalist 'japanlaw-opened-alist)))
       (japanlaw-with-buffer-read-only (erase-buffer))
       (japanlaw-index-insert-opened))
      (Recent
       (funcall
	(delalist 'japanlaw-recent-alist
		  '(mapcar (lambda (x) (upcase x))
                           (japanlaw-index-get-cells 'marks))))
       (japanlaw-with-buffer-read-only (erase-buffer))
       (japanlaw-index-insert-recent)))))

(defun japanlaw-index-bookmark-move-up ()
  "項目を1行上に移動する。"
  (interactive)
  (japanlaw-index-bookmark-move-down t))

(defun japanlaw-index-bookmark-move-down (&optional up)
  "項目を1行下に移動する。"
  (interactive)
  (when (eq japanlaw-index-local-mode 'Bookmark)
    (japanlaw-with-buffer-read-only
     (let* ((start (progn (forward-line 0) (point)))
	    (end   (progn (forward-line 1) (point)))
	    (line  (buffer-substring start end)))
       (delete-region start end)
       (forward-line (if up -1 1))
       (insert line)))
    (forward-line (if up -2 1))
    (when (eobp) (forward-line -1))
    (japanlaw-index-move-to-column)
    (setq japanlaw-bookmark-alist (japanlaw-index-get-cells))))

;;
;; Scroll commands
;;
(defun japanlaw-index-move-to-column ()
  "フォルダの開閉を表わすマーク位置に移動する関数。"
  (forward-line 0)
  (re-search-forward "[+-]" nil t)
  (ignore-errors (backward-char 1)))

(defun japanlaw-index-previous-line (n)
  "前の行に移動するコマンド。"
  (interactive "p")
  (let ((p (point)))
    (if (> 0 (forward-line (- n)))
	(goto-char p)
      (japanlaw-index-move-to-column))))

(defun japanlaw-index-next-line (n)
  "次の行に移動するコマンド。"
  (interactive "p")
  (forward-line n)
  (when (eobp) (forward-line -1))
  (japanlaw-index-move-to-column))

(defun japanlaw-index-scroll-up-line (n)
  "N行前方にスクロールするコマンド。"
  (interactive "p")
  (ignore-errors
    (scroll-up n)
    (japanlaw-index-move-to-column)))

(defun japanlaw-index-scroll-down-line (n)
  "N行後方にスクロールするコマンド。"
  (interactive "p")
  (ignore-errors
    (scroll-down n)
    (japanlaw-index-move-to-column)))

(defun japanlaw-index-previous-folder ()
  "ポイントと同じレベルの前のフォルダに移動する。"
  (interactive)
  (japanlaw-index-next-folder t))

(defun japanlaw-index-next-folder (&optional previous)
  "ポイントと同じレベルの次のフォルダに移動する。"
  (interactive)
  (let ((func (japanlaw-any-function
	       '(japanlaw-index-folder-level-0
		 japanlaw-index-folder-level-1
		 japanlaw-index-folder-level-2
		 japanlaw-index-folder-level-3)))
	(move-to (point)))
    (when (functionp func)
      (save-excursion
	(forward-line (if previous -1 1))
	(while (not (or (funcall func)
			(eobp)
			(bobp)))
	  (forward-line (if previous -1 1)))
	(when (funcall func)
	  (japanlaw-index-move-to-column)
	  (setq move-to (point))))
      (goto-char move-to))))

(defun japanlaw-completion-list (afunc)
  "補完リストを返す関数。AFUNCは連想リストを返す関数。"
  (do ((xs (funcall afunc) (cdr xs))
       (result nil (cons (caar xs) result)))
      ((null xs) result)))

(defun japanlaw-index-goto-folder (folder)
  "補完リストから、最上位の階層に選択的に移動するコマンド。
`japanlaw-use-iswitchb'がtなら`iswitchb'を利用する。"
  (interactive
   (list (funcall
	  (if japanlaw-use-iswitchb
	      #'japanlaw-icompleting-read
	    #'completing-read)
	  (if (memq japanlaw-index-local-mode '(Index Directory Abbrev))
	      "Goto folder: " "Goto name: ")
	  (japanlaw-completion-list
	   (cond ((eq japanlaw-index-local-mode 'Index)     #'japanlaw-index-alist)
		 ((eq japanlaw-index-local-mode 'Directory) #'japanlaw-directory-alist)
		 ((eq japanlaw-index-local-mode 'Abbrev)    #'japanlaw-abbrev-alist)
		 ((eq japanlaw-index-local-mode 'Bookmark)
		  (lambda () (japanlaw-make-alist-from-name #'japanlaw-bookmark-alist)))
		 ((eq japanlaw-index-local-mode 'Recent)
		  (lambda () (japanlaw-make-alist-from-name #'japanlaw-recent-alist)))
		 ((eq japanlaw-index-local-mode 'Opened)    #'japanlaw-opened-alist)
		 (t (error "Not supported.")))))))
  (unless (string= folder "")
    (goto-char
     (save-excursion
       (goto-char (point-min))
       (re-search-forward (format "[+-]\" \"%s\"" folder))))
    (japanlaw-index-move-to-column)))

(defun japanlaw-index-beginning-of-buffer ()
  (interactive)
  (goto-char (point-min))
  (japanlaw-index-move-to-column))

(defun japanlaw-index-end-of-buffer ()
  (interactive)
  (goto-char (point-max))
  (forward-line -1)
  (japanlaw-index-move-to-column))

;;
;; japanlaw index menu
;;
(easy-menu-define japanlaw-index-mode-menu
    japanlaw-index-mode-map
  "japanlaw-index-menu"
  '("JapanLaw"
    ["Open or Close Item"	japanlaw-index-open-or-close t]
    ["Browse This URL"		japanlaw-index-browse-at-point t]
    ["Search Law Name"		japanlaw-index-search t]
    ["JapanLaw Iswitchb"		japanlaw-iswitchb t]
    "-"
    ["Update Buffer"		japanlaw-index-update t]
    "-"
    ["Bookmark Add"		japanlaw-index-bookmark-add t]
    ["Move Up Bookmark Item"	japanlaw-index-bookmark-move-up t]
    ["Move Down Bookmark Item"	japanlaw-index-bookmark-move-down t]
    "-"
    ["Put Deletion Mark"	japanlaw-index-put-deletion-flag t]
    ["Delete Marked Items"	japanlaw-index-do-delete-marks t]
    "-"
    ["Upper Level"		japanlaw-index-upper-level t]
    ["Previous Same Level"	japanlaw-index-previous-folder t]
    ["Next Same Level"		japanlaw-index-next-folder t]
    ["Select Folder"		japanlaw-index-goto-folder t]
    "-"
    ["Open All Folder"		japanlaw-index-open-all t]
    ["Close All Folder"		japanlaw-index-close-all t]
    "-"
    ["Previous Item"		japanlaw-index-previous-line t]
    ["Next Item"		japanlaw-index-next-line t]
    ["Scroll Up Line"		japanlaw-index-scroll-up-line t]
    ["Scroll Down Line"		japanlaw-index-scroll-down-line t]
;;     ["Beginning of Buffer"	japanlaw-index-beginning-of-buffer t]
;;     ["End of Buffer"		japanlaw-index-end-of-buffer t]
    "-"
    ["Help"			japanlaw-index-help t]
    ("Other"
     ["Make Index Files"	japanlaw-retrieve-index t]
     "-"
     ["Retrieve HTML Data"	 japanlaw-retrieve-html t]
     ;;["法令ファイルの再作成"	 japanlaw-menu-data-create t]
     )
    "-"
    ["Close Index"		bury-buffer t]
    ["JapanLaw Exit"		japanlaw-exit t]))

;;
;; Index mode
;;
;;;###autoload
(defalias 'japanlaw 'japanlaw-index)

;;;###autoload
(defun japanlaw-index ()
  "法令データにアクセスするためのインターフェイス。"
  (interactive)
  (unless (file-exists-p japanlaw-index-file)
    (unless japanlaw-online-mode
      (error "Try `M-x japanlaw-online-or-offline', and turn to online mode."))
    (japanlaw-make-index-files))
  (switch-to-buffer
   (or (get-buffer japanlaw-index-buffer)
       (prog1
	   (set-buffer (get-buffer-create japanlaw-index-buffer))
	 (japanlaw-index-mode)))))

(defun japanlaw-index-mode ()
  "`japanlaw-index'のためのメジャーモード。"
  (kill-all-local-variables)
  (use-local-map japanlaw-index-mode-map)
  (setq mode-name japanlaw-index-mode-name)
  (setq major-mode 'japanlaw-index-mode)
  (set (make-local-variable 'japanlaw-index-local-mode)
       japanlaw-index-initial-mode)
  (set (make-local-variable 'japanlaw-index-conf) nil)
  (set (make-local-variable 'japanlaw-search-alist) nil)
  (set (make-local-variable 'japanlaw-names-alist) nil)
  ;;(set (make-local-variable 'japanlaw-search-history) nil)
  ;;(set (make-local-variable 'japanlaw-alist) nil)
  ;;(set (make-local-variable 'japanlaw-abbrev) nil)
  ;;(set (make-local-variable 'japanlaw-abbrev-alist) nil)
  (set (make-local-variable 'japanlaw-index-alist) nil)
  (set (make-local-variable 'japanlaw-directory-alist) nil)
  (set (make-local-variable 'japanlaw-index-search-overlaies) nil)
  (japanlaw-index-goto-mode japanlaw-index-initial-mode)
  (setq buffer-read-only t)
  (set (make-local-variable 'font-lock-defaults)
       '(japanlaw-index-font-lock-keywords))
  (turn-on-font-lock)
  (setq truncate-lines t)
  (easy-menu-add japanlaw-index-mode-menu)
  (and japanlaw-mode-line
       (setq mode-line-buffer-identification japanlaw-mode-line))
  (run-hooks 'japanlaw-index-mode-hook)
  )

;; display icon on mode-line
(defun japanlaw-online-or-offline ()
  "Turn on or off `japanlaw-online-mode'."
  (interactive)
  (setq japanlaw-online-mode (not japanlaw-online-mode))
  (setq japanlaw-icon
	(if japanlaw-online-mode
	    japanlaw-online-icon
	  japanlaw-offline-icon))
  (force-mode-line-update)
  (japanlaw-online-mode-message #'message))

(defun japanlaw-online-mode-message (message-fun)
  (funcall message-fun (if japanlaw-online-mode "On line mode." "Off line mode.")))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; japanlaw
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;
;; search
;;
(defun japanlaw-push-mouse-2 (e)
  (interactive "e")
  (mouse-set-point e)
  (call-interactively 'japanlaw-search-or-push-anchor))

(defun japanlaw-search-or-push-anchor (n)
  (interactive "p")
  (if current-prefix-arg
      ;; search
      (let ((kanji (japanlaw-to-kanji-number n)))
	(when kanji
	  (goto-char
	   (save-excursion
	     (japanlaw-move-to-article `(,(format "^第%s条" kanji)))))
	  (japanlaw-winconf-add 'force)))
    ;; anchor push
    (japanlaw-push-anchor)))

(defun japanlaw-push-anchor (&optional new-window)
  (interactive "P")
  (cond ( ;; リージョンが活性の場合(罫線表内部で実行)
	 (and mark-active transient-mark-mode)
	 (japanlaw-display-anchor
	  (japanlaw-rectangle-anchor (region-beginning) (region-end))
	  new-window))
	( ;; 全角括弧
	 (eq (char-after) ?\（)
	 (japanlaw-compose-paren-toggle))
	( ;; 通常のアンカーの場合
	 (memq (get-text-property (point) 'face)
	       '(japanlaw-anchor-name-face
		 japanlaw-anchor-article-face))
	 (japanlaw-display-anchor (japanlaw-anchor-at-point) new-window))
	( ;; アウトラインヘッダ
	 (japanlaw-outline-header-p)
	 (japanlaw-heading-jump))
	(t (princ "No anchor at point."))))

(defun japanlaw-rectangle-anchor (start end)
  "罫線表の中の複数行に跨ったリージョンから法令名・条文番号等を文
字列で返す。"
  (save-excursion
    (goto-char start)
    (japanlaw-labels
        ((trim (anchor)
               (let* ((kanji "[一二三四五六七八九十]")
                      (regexp (concat
                               "\\(第[一二三四五六七八九十百千]+条"
                               "\\(?:[のノ]"	kanji "+\\)*\\)"
                               "\\(第"		kanji "+項\\)*"
                               "\\(第"		kanji "+号"
                               "\\(?:[のノ]"	kanji "+\\)*\\)?")))
                 (if (string-match regexp anchor)
                     (substring anchor 0 (match-end 0))
                   anchor))))
      (let ((count-back 0)
	    (lines (count-lines start end))
	    (move-to
	     (save-excursion
	       (search-forward "│" (line-end-position) t)
	       (1- (current-column))))
	    back-to)
	(while (/= (preceding-char) ?│)
	  (backward-char)
	  (when (= (point) (line-beginning-position))
	    (error "Not a chart."))
	  (incf count-back))
	(setq back-to (current-column))
	;; 条数の後の文字列をトリミング
	(trim
	 (let (result)
	   (replace-regexp-in-string
	    "（.+?）" ""
	    (substring
	     (apply 'concat
		    (dotimes (x lines (nreverse result))
		      (push (buffer-substring-no-properties
			     (point)
			     (save-excursion
			       (move-to-column move-to)
			       (if (> (1- (point)) end)
				   end
				 (1- (point)))))
			    result)
		      (forward-line 1)
		      (move-to-column back-to)))
	     count-back))))))))

(defun japanlaw-display-anchor (anchor new-window)
  (multiple-value-bind (name article paragraph item)
      (japanlaw-parse-anchor anchor)
    (setq name
	  ;; If non nil, 法令名に変換。
	  (and name             ;(japanlaw-anchor-convert-to-ref name)
	       (japanlaw-anchor-convert-entry-name name))
	  ;; If non nil, 正規表現文字列に変換。
	  article
	  (japanlaw-anchor-article article)
	  ;; If non nil, 正規表現文字列に変換。
	  paragraph
	  (japanlaw-anchor-paragraph paragraph)
	  ;; If non nil, 正規表現文字列に変換。
	  item
	  (japanlaw-anchor-item item))
    (when (and (not new-window) (not (one-window-p)))
      (let ((lst (save-selected-window
		   (japanlaw-other-window)
		   (list major-mode (japanlaw-current-buffer-law-name)))))
	(if (eq (car lst) 'japanlaw-mode)
	    (progn (and (null name)
			(setq name (cadr lst)))
		   (save-selected-window
		     (japanlaw-other-window)
		     (delete-window)
		     (setq new-window t)))
	  (setq new-window t))))
    (unless name
      ;; If nil, 参照しているのは現在のファイル。
      (setq name (japanlaw-current-buffer-law-name)))
    (japanlaw-display
     (let* ((id (japanlaw-get-id name))
            file)
       (cond
        ((assoc name japanlaw-mishikou-list)
         ;; 未施行法令への anchor (取得 URL が異なる)
         ;; FIXME:
         ;; 未施行法令を htmldata にファイルを保存するのはあんまりよくないけど。。
         (let ((mishikou (assoc name japanlaw-mishikou-list)))
           (setq id (concat (japanlaw-file-sans-name (cdr mishikou)) "-mishikou"))
           (setq file (japanlaw-expand-data-file id))
           (japanlaw-make-data id nil
                               (concat
                                japanlaw-egov-url
                                japanlaw-htmldata-directory
                                (cdr mishikou)))))
        ((and name (eq id nil))
         (error "Parse error: %S" (list name id)))
        ((eq id nil)                    ; 未登録法令
         (or (and (equal (japanlaw-current-buffer-law-name)
                         name)
                  (buffer-file-name))
             (error "Not visited file.")))
        ((file-exists-p (setq file (japanlaw-expand-data-file id)))
         file)
        (t (japanlaw-make-data id))))
     (list article paragraph item)
     1)
    (sit-for 0.1)			;Test:
    (if (eq (japanlaw-compare-winconf)
	    'different)
	(japanlaw-winconf-add 'force)
      (princ '==))))

(defun japanlaw-display (filename &optional search recenter select)
  "Return window."
  (let* ((buffer (japanlaw-get-buffer filename))
	 (window (japanlaw-split-window-vertically buffer)))
    (when search
      (save-selected-window
	(set-window-buffer (select-window window) buffer)
	(japanlaw-move-to-article search recenter)))
    (when select (select-window window))
    window))

(defun japanlaw-split-window-vertically (buffer &optional size)
  "Return the created window."
  (let ((window (split-window-vertically
		 (- (or size japanlaw-window-height)))))
    (set-window-buffer window buffer)
    window))

(defun japanlaw-set-window-height (height)
  (shrink-window (- (window-height) height 1)))

(defun japanlaw-get-buffer (filename)
  "FILENAME is the path/filename."
  (or (get-file-buffer filename)
      (prog1
	  (set-buffer (find-file-noselect filename))
	(japanlaw-mode))))

(defun japanlaw-digit-argument-suffix (prefix)
  (interactive "p")
  (when (not current-prefix-arg)
    (error "/"))
  (let ((args (split-string
	       (concat (japanlaw-digit-argument)) "-" t)))
    (mapc (lambda (x)
	    (when (zerop (string-to-number x))
	      (error "//")))
	  args)
    (goto-char
     (save-excursion
       (japanlaw-move-to-article
	(japanlaw-make-article-regexp prefix args))))
    (japanlaw-winconf-add 'force)))

(defun japanlaw-digit-argument (&optional events)
  (let ((ev (read-event)))
    (cond
      ((not (memq ev '(?0 ?1 ?2 ?3 ?4 ?5 ?6 ?7 ?8 ?9 ?- 32 10 13 return)))
       (error "/"))
      ((memq ev '(32 10 13 return))
       (reverse events))
      (t
       (japanlaw-digit-argument (cons ev events))))))

(defun japanlaw-make-article-regexp (prefix args)
  (list
   (format "^第%s条%s"
	   (japanlaw-to-kanji-number prefix)
	   (mapconcat (lambda (x)
			(format "[のノ]%s"
				(japanlaw-to-kanji-number (string-to-number x))))
		      args ""))))

(defun japanlaw-to-kanji-number (n)
  (japanlaw-labels
      ((split (n)
              (if (zerop (/ n 10))
                  (list (% n 10))
                (cons (% n 10) (split (/ n 10)))))
       (kanji (n)
              (nth n '("零" "一" "二" "三" "四" "五" "六" "七" "八" "九"))))
    (apply #'concat
	   (nreverse
	    (japanlaw:map (lambda (i s)
			(and (> i 0) (string= s "一") (setq s ""))
			(if (string= s "零") ""
			  (concat s (nth i '("" "十" "百" "千")))))
		      '(0 1 2 3) (mapcar #'kanji (split n)))))))

(defun japanlaw-to-arabic-number (kanji &optional em-size)
  (if (string-match "[一二三四五六七八九十百千]+" kanji)
      (setq kanji (match-string 0 kanji))
    (error "Argument is not Chinese numeral"))
  (let* ((number "[一二三四五六七八九十]")
	 (regexp (concat
		  "\\(" number "?千\\)?"
		  "\\(" number "?百\\)?"
		  "\\(" number "?十\\)?"
		  "\\(" number "\\)?"))
	 (lst (progn
		;; 各桁の値のリストを生成
		(string-match regexp kanji)
		(mapcar (lambda (x) (match-string x kanji))
			'(1 2 3 4))))
	 result)
    (setq lst
	  ;; 各要素を数に変換
	  (dotimes (x 4 lst)
	    (let ((element (nth x lst)) p)
	      (and (or (equal element "千")
		       (equal element "百")
		       (equal element "十"))
		   (setq element (concat "一" element)))
	      (and element
		   (setq element (substring element 0 1)))
	      (setcar
	       (nthcdr x lst)
	       (cond
		 ((equal element '()) 0)
		 (t
		  (setq p (string-match element "一二三四五六七八九"))
		  (string-to-number
		   (substring "123456789" p (1+ p)))))))))
    ;; 合算
    (setq result
	  (apply (function +)
		 (mapcar (lambda (x)
			   (* (expt 10 (- 3 x)) (nth x lst)))
			 '(0 1 2 3))))
    ;; 全角文字に変換
    (or (and em-size
	     (japanese-zenkaku (number-to-string result)))
	result)))

;;
;; common
;;
(defun japanlaw-recenter (&optional n)
  (interactive "p")
  (let ((line (cond ((numberp n) n)
		    ((null n) nil)
		    (t japanlaw-reposition-line))))
    (when line
      ;;(sit-for 0)
      (recenter line))
    line))

(defun japanlaw-scan-buffer (regexp direction count &optional recenter limit)
  (let ((found t))
    (japanlaw-labels
        ((scan (s)
               (setq found
                     (case direction
                       (forward (and (bolp)
                                     (not (eobp))
                                     (forward-char))
                                (re-search-forward s limit t))
                       (backward (unless (bolp) (forward-line 1))
                                 (re-search-backward s limit t))))
               (when found (decf count))))
      (while (and found (> count 0))
	(scan regexp))
      (forward-line 0)
      (when found (japanlaw-recenter recenter))
      found)))

;; (defun japanlaw-current-article ()
;;   ;; ^$ ではなく、japanlaw-article-regexp で判断するよう変更する。
;;   (let (beg end)
;;     (save-excursion
;;       (or (and (looking-at "^$")
;; 	       (setq end (point)
;; 		     beg (or (re-search-backward japanlaw-article-regexp nil t)
;; 			     (point-min))))
;; 	  (setq end (or (re-search-forward "^$" nil t)
;; 			(point-max))
;; 		beg (or (re-search-backward japanlaw-article-regexp nil t)
;; 			(point-min)))))
;;     (list beg end)))

;; (defun japanlaw-current-article ()
;;   (let ((end-point
;; 	 (lambda ()
;; 	   (cond ((re-search-forward japanlaw-article-regexp nil t)
;; 		  (while (not (looking-at "^$"))
;; 		    (forward-line -1))
;; 		  (when (>= beg (point))
;; 		    (error "Irregular article region."))
;; 		  (point))
;; 		 ((re-search-forward "^$" nil t)
;; 		  (point))
;; 		 (t (point-max)))))
;; 	beg end)
;;     (save-excursion
;;       (forward-line 0)
;;       (cond ((looking-at japanlaw-article-regexp)
;; 	     (setq beg (point))
;; 	     (forward-line 1)
;; 	     (setq end (funcall end-point)))
;; 	    ((re-search-backward japanlaw-article-regexp nil t)
;; 	     (setq beg (point))
;; 	     (forward-line 1)
;; 	     (setq end (funcall end-point)))
;; 	    (t (goto-char (point-min))
;; 	       (setq beg (point))
;; 	       (setq end (funcall end-point)))))
;;     (list beg end)))

(defun japanlaw-current-article ()
  ;; Test:
  (japanlaw-labels
      ((end-point (p)
                  (cond ((re-search-forward
                          (concat
                           "\\(" japanlaw-article-regexp "\\|" outline-regexp "\\)")
                          nil t)
                         (forward-line 0)
                         (or (looking-at outline-regexp)
                             (while (not (looking-at "^$"))
                               (forward-line -1)))
                         (when (>= p (point))
                           (error "Irregular article boundaries."))
                         (point))
                        ((re-search-forward "^$" nil t)
                         (point))
                        (t (point-max)))))
    (let (beg end)
      (save-excursion
	(forward-line 0)
	(cond ((looking-at japanlaw-article-regexp)
	       (setq beg (point))
	       (forward-line 1)
	       (setq end (end-point beg)))
	      ((re-search-backward japanlaw-article-regexp nil t)
	       (setq beg (point))
	       (forward-line 1)
	       (setq end (end-point beg)))
	      (t (goto-char (point-min))
		 (setq beg (point))
		 (setq end (end-point beg))))
	(cons beg end)))))

;;
;; Move to article and paragraph
;;
(defun japanlaw-move-to-article (args &optional recenter)
  (let ((article   (car  args))
	(paragraph (cadr args))
	(item      (nth 2  args)))
    (goto-char (point-min))
    (when article
      (if (re-search-forward article nil t)
	  (when (or paragraph item)
	    (let ((limit (cdr (japanlaw-current-article))))
	      (mapc (lambda (rx)
		      (and rx (or (re-search-forward rx limit t)
				  (error "Not found."))))
		    `(,paragraph ,item))))
	(error "Not found.")))
    ;; found
    (forward-line 0)
    (japanlaw-recenter (or recenter t))
    (point)))

(defun japanlaw-forward-article (n)
  (interactive "p")
  ;; ポイントがアウトラインヘッダ上にあるかどうかで分岐
  ;; 同一階層間の移動
  (if (japanlaw-outline-header-p)
      (japanlaw-forward-same-level n)
    ;; 次の条文へ移動
    (or (japanlaw-scan-buffer japanlaw-article-regexp 'forward n t)
	(goto-char (point-max)))))

(defun japanlaw-backward-article (n)
  (interactive "p")
  ;; ポイントがアウトラインヘッダ上にあるかどうかで分岐
  ;; 同一階層間の移動
  (if (japanlaw-outline-header-p)
      (japanlaw-backward-same-level n)
    ;; 前の条文へ移動
    (or (japanlaw-scan-buffer japanlaw-article-regexp 'backward n t)
	(goto-char (point-min)))))

(defun japanlaw-forward-paragraph (n)
  (interactive "p")
  (save-selected-window
    (when (not (one-window-p))
      (select-window
       (cadr (memq (selected-window) (window-list)))))
    (if (eq major-mode 'japanlaw-mode)
	(let ((limit (progn (when (looking-at "^$")
			      (error "/"))
			    (cdr (japanlaw-current-article)))))
	  (or (japanlaw-scan-buffer
	       japanlaw-paragraph-regexp 'forward n nil limit)
	      (error "Last paragraph.")))
      (scroll-up))))

(defun japanlaw-backward-paragraph (n)
  (interactive "p")
  (save-selected-window
    (when (not (one-window-p))
      (select-window
       (cadr (memq (selected-window) (window-list)))))
    (if (eq major-mode 'japanlaw-mode)
	(let ((limit (let ((beg (car (japanlaw-current-article))))
		       (and (< (point) beg)
			    (error "/"))
		       beg)))
	  (or (japanlaw-scan-buffer
	       japanlaw-paragraph-regexp 'backward n nil limit)
	      (error "First paragraph.")))
      (scroll-down))))

;;
;; Move to anchor
;;
(defun japanlaw-forward-anchor ()
  (interactive)
  (japanlaw-move-to-anchor 'forward))

(defun japanlaw-backward-anchor ()
  (interactive)
  (japanlaw-move-to-anchor 'backward))

;;
;; anchor
;;
(defun japanlaw-move-to-anchor (direction)
  (japanlaw-labels
      ((point-face (&optional point)
                   (get-text-property (or point (point)) 'face))
       (scanner ()
                (case direction
                  (forward (next-property-change (point)))
                  (backward (previous-property-change (point))))))
    (let ((back-to (point)))
      (while (memq (point-face)
		   '(japanlaw-anchor-article-face japanlaw-anchor-name-face))
	(condition-case err
	    (goto-char (scanner))
	  (wrong-type-argument
	   (error "There is no anchor any further."))))
      (while (or (not (memq (point-face)
			    '(japanlaw-anchor-article-face japanlaw-anchor-name-face)))
		 (and (eq (char-before) ?\）)
		      (eq (point-face (- (scan-lists (point) -1 0) 1))
			  japanlaw-anchor-name-face)))
	(condition-case err
	    (goto-char (scanner))
	  (wrong-type-argument
	   (goto-char back-to)
	   (error "There is no anchor any further."))))
      (when (eq (point-face (1- (point))) 'japanlaw-anchor-name-face)
	(goto-char (previous-property-change (point)))))))

(defun japanlaw-anchor-at-point ()
  (let ((anchor (japanlaw-current-anchor)))
    (when anchor
      (replace-regexp-in-string
       "（.+?）" ""
       (buffer-substring-no-properties (car anchor) (cdr anchor))))))

(defun japanlaw-parse-anchor (anchor)
  (let* ((kanji "[一二三四五六七八九十]")
	 (regexp (concat
		  "\\(第[一二三四五六七八九十百千]+条"
		  "\\(?:[のノ]"	kanji "+\\)*\\)"
		  "\\(第"	kanji "+項\\)*"
		  "\\(第"	kanji "+号"
		  "\\(?:[のノ]"	kanji "+\\)*\\)?\\'"))
	 ;; 条数
	 (article (and (string-match regexp anchor)
		       (match-string 1 anchor)))
	 ;; 項数
	 (paragraph (and (string-match regexp anchor)
			 (match-string 2 anchor)))
	 ;; 号数
	 (item (and (string-match regexp anchor)
		    (match-string 3 anchor)))
	 ;; 法令名
	 (name (or (and (not article)
			anchor)
		   (and (and (string-match article anchor)
			     (/= (match-beginning 0) 0))
			(substring anchor 0 (match-beginning 0))))))
    (list name article paragraph item)))

(defun japanlaw-get-name (id)
  "ID(\"m29ho089\"のような形式)から法令名を取得して返す。"
  (block nil
    (let ((xs (japanlaw-alist)))
      (while xs
	(let ((cell (rassoc id (cdar xs))))
	  (when cell
	    (return (caar cell))))
	(pop xs)))))

(defun japanlaw-current-buffer-law-name ()
  "カレントファイルの法令名を返す。"
  (japanlaw-get-name (upcase (japanlaw-file-sans-name (buffer-file-name)))))

(defun japanlaw-get-local-name (name id)
  (or (plist-get (cdr
		  (assoc (japanlaw-get-name (upcase id)) japanlaw-local-names-plist))
		 (intern (concat ":" name)))
      (save-excursion
	(goto-char (point-min))
	(when (search-forward (concat "以下「" name "」という。") nil t)
	  (japanlaw-backward-anchor)
	  (buffer-substring-no-properties
	   (point)
	   (goto-char (next-property-change (point))))))
      (error "Not entried.")))

(defun japanlaw-get-id (name)
  "法令名NAMEから参照先を返す。"
  (block nil
    ;; 登録法令名
    (let ((xs (japanlaw-alist)))
      (while xs
	(let ((ys (cdar xs)))
	  (while ys
	    (let ((cell (car ys)))
	      (when (string= (caar cell) name)
		(return (cdr cell))))
	    (pop ys)))
	(pop xs)))
    ;; 略称法令名
    (let ((xs (japanlaw-abbrev)))
      (while xs
	(let ((ys (cdar xs)))
	  (while ys
	    (let ((cell (cdr (assoc (format "「%s」" name) ys))))
	      (when cell
		(if (= (length cell) 1)
		    (return (cdar cell))
		  ;; 略称法令名で、ひとつの略称に対して複数の法令が対応してい
		  ;; る場合に補完リストから選択する。
		  (let* ((selected (completing-read "Select: " cell nil t))
			 (id (cdr (assoc selected cell))))
		    (if id
			(return id)
		      (error "Cancel."))))))
	    (pop ys)))
	(pop xs)))))

(defun japanlaw-anchor-convert-entry-name (name)
  ;; nameに対応する法令ファイル名を返す。
  (cond ((member name japanlaw-local-name-list)
	 ;; 「法」「令」「規則」「新法」「旧法」等、具体的な法令名に変換する。
	 (japanlaw-anchor-convert-entry-name
	  (japanlaw-get-local-name name (japanlaw-file-sans-name (buffer-file-name)))))
	;; 「附則」への対応(法令を開くのみ)。
	;; `japanlaw-anchor-at-point'で条数、項数等は取得しない。
	((string= name "同法附則")
	 (error "Not supported."))
	((string-match "^\\(.+?\\)附則$" name)
	 (match-string 1 name))
	;; 「同法」
	((string= name "同法")
	 (save-excursion
	   (goto-char (next-property-change (point)))
	   (dotimes (x 1) (japanlaw-move-to-anchor 'backward))
	   (while (or (not (eq (get-text-property (point) 'face)
			       japanlaw-anchor-name-face))
		      (looking-at "同法"))
	     (japanlaw-move-to-anchor 'backward))
	   (japanlaw-anchor-convert-entry-name
	    (car (japanlaw-parse-anchor (japanlaw-anchor-at-point))))))
	;; 「憲法」等、登録名称に変換。
	((assoc name japanlaw-unentry-names)
	 (japanlaw-anchor-convert-entry-name
	  (cdr (assoc name japanlaw-unentry-names))))
	;; 登録法令名、略称法令名
	(t name)))

(defun japanlaw-anchor-article (article)
  (when article
    (setq article
	  (replace-regexp-in-string "[のノ]" "[のノ]" article))
    (concat "^" article "[ 　]*")))

(defun japanlaw-anchor-paragraph (paragraph)
  (when paragraph
    (setq paragraph
	  (japanlaw-to-arabic-number paragraph 'em-size))
    (and (not (string= "１" paragraph))
	 (format "^\\(%s\\|[○◯]%s\\)" paragraph paragraph))))

(defun japanlaw-anchor-item (item)
  (and item
       (string-match "\
第\\([一二三四五六七八九十]+\\)号\\(\\([のノ][一二三四五六七八九十]+\\)*\\)" item)
       (concat "^" (match-string 1 item) (match-string 2 item))))



(defun japanlaw-file-sans-name (file)
  "ファイル名の主部(m29ho089)を返す。"
  (when file
    (file-name-nondirectory (file-name-sans-extension file))))

(defun japanlaw-buffer-file-laws-name (&optional full)
  "buffer-file-nameからdirectoryとextentionを除いた法令名を返す。
FULL が非-nilなら path/file を返す。"
  (let ((visitp (buffer-file-name)))
    (or (and (not visitp)
	     (error "Buffer not visiting any file."))
	(or (and full visitp)
	    (japanlaw-file-sans-name (buffer-file-name))))))

(defun japanlaw-rename-buffer ()
  "`japanlaw-use-buffer-law-name'が非nilなら、法令ファイルのバッファ名
を法令名とする。法令名の長さが`japanlaw-name-length'より大きければ、
`japanlaw-name-suffix'を付加してバッファ名を縮小する。"
  (let* ((id (japanlaw-file-sans-name (buffer-file-name)))
	 (name (japanlaw-get-name (upcase id))))
    (when (and name japanlaw-use-buffer-law-name)
      (when (> (length name) japanlaw-name-length)
	(setq name
	      (concat (substring name 0 japanlaw-name-length)
		      japanlaw-name-suffix)))
      (rename-buffer name 'uniq))))

(defun japanlaw-display-toggle ()
  (interactive)
  (if (and (one-window-p) japanlaw-display-toggle-winconf)
      ;; restore
      (let ((buffer (current-buffer))
	    (winstart (window-start))
	    (pos (point)))
	(japanlaw-restore-winconf japanlaw-display-toggle-winconf)
	(set-window-buffer (selected-window) buffer)
	(set-window-start (selected-window) winstart)
	(goto-char pos))
    ;; store
    (when (not (one-window-p))
      (setq japanlaw-display-toggle-winconf (japanlaw-current-winconf))
      (delete-other-windows))))

;;
;; Window change
;;
(defun japanlaw-other-window (&optional window)
  (interactive)
  (when (not (one-window-p))
    (select-window
     (or window
	 (cadr (memq (selected-window) (window-list)))))))

;;
;; Scroll
;;
(defun japanlaw-scroll-up-screen (n)
  (interactive "p")
  (scroll-up n))

(defun japanlaw-scroll-down-screen (n)
  (interactive "p")
  (scroll-down n))

;;
;; other
;;

(defun japanlaw-browse-current-url ()
  (interactive)
  (let ((url (japanlaw-expand-htmldata-url
	      (japanlaw-file-sans-name (buffer-file-name)))))
    (if (not (string= url ""))
	(browse-url url)
      (message "No url in this file."))))

(defun japanlaw-print-current-url ()
  "バッファの WEB 上の URL をミニバッファに表示して `kill-ring' に追加する。"
  (interactive)
  (let ((url (japanlaw-expand-htmldata-url
	      (japanlaw-file-sans-name (buffer-file-name)))))
    (cond
     ((not (string= url ""))
      (kill-new url)
      (message "%s" url))
     (t
      (message "No url in this file.")))))

(defun japanlaw-view-quit ()
  (interactive)
  (bury-buffer)
  (japanlaw-index))

;;
;; window configuration
;;
(defalias 'japanlaw-current-winconf 'current-window-configuration-printable)
(defalias 'japanlaw-restore-winconf 'restore-window-configuration)

;; (defalias 'japanlaw-current-winconf 'current-window-configuration)
;; (defalias 'japanlaw-restore-winconf 'set-window-configuration)

(defun japanlaw-winconf-override ()
  (interactive)
  (if (and japanlaw-winconf-list
	   (not (japanlaw-winconf-equalp))
	   (y-or-n-p (format "%s Override winconf? "
			     (progn (japanlaw-winconf-message)
				    (current-message)))))
      (progn
	(setcar (nthcdr japanlaw-winconf-index japanlaw-winconf-list)
		(japanlaw-current-winconf))
	(japanlaw-winconf-message '=))
    (japanlaw-winconf-message)))

(defun japanlaw-winconf-insert ()
  (interactive)
  (if (and japanlaw-winconf-list
	   (not (japanlaw-winconf-equalp))
	   (y-or-n-p "Insert winconf? "))
      (progn
	(push (japanlaw-current-winconf)
	      (nthcdr japanlaw-winconf-index japanlaw-winconf-list))
	(when (/= japanlaw-winconf-index 0)
	  (setq japanlaw-winconf-index (- japanlaw-winconf-index 1)))
	(japanlaw-winconf-message '+))
    (japanlaw-winconf-message)))

(defun japanlaw-winconf-add (&optional force)
  (interactive)
  (if (and (not (japanlaw-winconf-equalp))
	   (or force (y-or-n-p "Add winconf? ")))
      (progn
	(push (japanlaw-current-winconf)
	      (nthcdr (+ japanlaw-winconf-index
			 (or (and (= (length japanlaw-winconf-list) 0) 0)
			     1))
		      japanlaw-winconf-list))
	(setq japanlaw-winconf-index
	      (+ japanlaw-winconf-index
		 (or (and (= (length japanlaw-winconf-list) 1) 0)
		     1)))
	(japanlaw-winconf-message '+))
    (japanlaw-winconf-message)))

(defun japanlaw-winconf-delete ()
  (interactive)
  (if (and japanlaw-winconf-list
	   (y-or-n-p "Delete winconf? "))
      (progn
	(setf (nthcdr japanlaw-winconf-index japanlaw-winconf-list)
	      (nthcdr (+ japanlaw-winconf-index 1) japanlaw-winconf-list))
	(when (and (= (length japanlaw-winconf-list) japanlaw-winconf-index)
		   (/= japanlaw-winconf-index 0))
	  (setq japanlaw-winconf-index (- japanlaw-winconf-index 1)))
	(japanlaw-winconf-message '-))
    (japanlaw-winconf-message)))

(defun japanlaw-winconf-delete-all ()
  (interactive)
  (if (and japanlaw-winconf-list
	   (y-or-n-p "Delete all winconf? "))
      (progn (setq japanlaw-winconf-list nil
		   japanlaw-winconf-index 0)
	     (princ 'Done))
    (japanlaw-winconf-message)))

(defun japanlaw-winconf-backward-delete ()
  (interactive)
  (if (and japanlaw-winconf-list
	   (/= japanlaw-winconf-index 0)
	   (y-or-n-p "Delete backward winconf? "))
      (progn
	(setf (nthcdr (- japanlaw-winconf-index 1) japanlaw-winconf-list)
	      (nthcdr japanlaw-winconf-index japanlaw-winconf-list))
	(setq japanlaw-winconf-index (- japanlaw-winconf-index 1))
	(japanlaw-winconf-message '-))
    (japanlaw-winconf-message)))

(defun japanlaw-forward-winconf ()
  (interactive)
  (if japanlaw-winconf-list
      (if (= (- (length japanlaw-winconf-list) 1)
	     japanlaw-winconf-index)
	  (japanlaw-winconf-message)
	(japanlaw-restore-winconf
	 (nth (+ japanlaw-winconf-index 1) japanlaw-winconf-list))
	(setq japanlaw-winconf-index (+ japanlaw-winconf-index 1))
	(japanlaw-winconf-message))
    (japanlaw-winconf-message)))

(defun japanlaw-backward-winconf ()
  (interactive)
  (if japanlaw-winconf-list
      (if (= japanlaw-winconf-index 0)
	  (japanlaw-winconf-message)
	(japanlaw-restore-winconf
	 (nth (- japanlaw-winconf-index 1) japanlaw-winconf-list))
	(setq japanlaw-winconf-index (- japanlaw-winconf-index 1))
	(japanlaw-winconf-message))
    (japanlaw-winconf-message)))

(defun japanlaw-restore-current-winconf ()
  (interactive)
  (if japanlaw-winconf-list
      (progn (japanlaw-restore-winconf
	      (nth japanlaw-winconf-index japanlaw-winconf-list))
	     (japanlaw-winconf-message '=))
    (japanlaw-winconf-message)))

(defun japanlaw-restore-first-winconf ()
  (interactive)
  (if japanlaw-winconf-list
      (progn (japanlaw-restore-winconf (nth 0 japanlaw-winconf-list))
	     (setq japanlaw-winconf-index 0)
	     (japanlaw-winconf-message))
    (japanlaw-winconf-message)))

(defun japanlaw-restore-last-winconf ()
  (interactive)
  (if japanlaw-winconf-list
      (progn (japanlaw-restore-winconf
	      (nth (- (length japanlaw-winconf-list) 1)
		   japanlaw-winconf-list))
	     (setq japanlaw-winconf-index (- (length japanlaw-winconf-list) 1))
	     (japanlaw-winconf-message))
    (japanlaw-winconf-message)))

(defun japanlaw-restore-nth-winconf (n)
  (when (and japanlaw-winconf-list
	     (<= 0 n) (< n (length japanlaw-winconf-list)))
    (japanlaw-restore-winconf (nth n japanlaw-winconf-list))
    (setq japanlaw-winconf-index n)
    (japanlaw-winconf-message)))

(defun japanlaw-winconf-equalp ()
  (when (equal
	 (nth japanlaw-winconf-index japanlaw-winconf-list)
	 (japanlaw-current-winconf))
    (message "==")
    (sit-for 0.5)))

(defun japanlaw-current-anchor ()
  (if (and mark-active transient-mark-mode)
      ;; 罫線表内でリージョンが活性の場合への対応
      (progn
	(deactivate-mark)
	(cons (region-beginning) (region-end)))
    ;; 通常のアンカーの場合
    (japanlaw-labels
        ((point-face (p) (get-text-property p 'face))
         (next (p) (goto-char (next-property-change p))))
      (when (memq (point-face (point))
		  '(japanlaw-anchor-name-face japanlaw-anchor-article-face))
	(let ((back-to (point))
	      (face (point-face (point)))
	      start end)
	  (save-excursion
	    (setq end (next back-to))
	    (cond ((and (= (following-char) ?\（)
			(eq face 'japanlaw-anchor-name-face))
		   ;; ○○法（○○○）第○○条第○号
		   (forward-sexp)
		   (and (eq (point-face (point)) 'japanlaw-anchor-article-face)
			(setq end (next (point)))))
		  ((eq (point-face (point)) 'japanlaw-anchor-article-face)
		   ;; ○○法第○○条第○号
		   (setq end (next (point)))))
	    (japanlaw-move-to-anchor 'backward)
	    (setq start (point)))
	  (cons start end))))))

(defun japanlaw-compare-winconf ()
  (let ((stored (nth japanlaw-winconf-index japanlaw-winconf-list))
	(current (japanlaw-current-winconf)))
    (cond
      ((and (equal (nth japanlaw-winconf-index japanlaw-winconf-list)
		   (japanlaw-current-winconf))
	    'identical))
      ((and (/= (length (nth 3 stored))
		(length (nth 3 current)))
	    'different))
      (t
       (let ((diffs (japanlaw-winconf-diffs stored current)))
	 (or (and (> (length diffs) 1)
		  'different)
	     (let* ((buf (member (buffer-name) (car diffs)))
		    ;; points: (current-pos (point))
		    (points (let (ret)
			      (dolist (x (car diffs) ret)
				(and (integerp x)
				     (push x ret)))))
		    (pos (car (memq (point) points))))
	       (or (or (and (not buf)
			    'different)
		       (and (not pos)
			    'different))
                   (save-excursion
                     (let ((anchor (japanlaw-current-anchor)))
                       (or (and (>= (cadr points) (car anchor))
                                (<= (cadr points) (cdr anchor))
                                (>= (car  points) (car anchor))
                                (<= (car  points) (cdr anchor))
                                'identical)
                           'different)))))))))))

(defun japanlaw-winconf-diffs (stored current)
  (let ((sbuflst (nth 3 stored))
	(cbuflst (nth 3 current))
	sbuf cbuf sbuffer cbuffer swinst cwinst spos cpos diffs)
    (catch 'compare
      (while sbuflst
	(setq sbuf    (car sbuflst)
	      cbuf    (car cbuflst)
	      sbuffer (revive:get-buffer sbuf)
	      cbuffer (revive:get-buffer cbuf))
	(and (not (equal sbuffer cbuffer))
	     (throw 'compare 'different))
	(setq swinst (revive:get-window-start sbuf)
	      cwinst (revive:get-window-start cbuf)
	      spos   (revive:get-point sbuf)
	      cpos   (revive:get-point cbuf))
	(and (/= swinst cwinst)
	     (throw 'compare 'different))
	(and (/= spos cpos)
	     (push (list cbuffer cpos sbuffer spos) diffs))
	(setq sbuflst (cdr sbuflst)
	      cbuflst (cdr cbuflst))))
    diffs))

(defun japanlaw-winconf-message (&optional arg)
  (interactive)
  (message
   (if japanlaw-winconf-list
       (format "%s[%d/%d]"
	       (if arg (concat "(" (symbol-name arg) ")") "")
	       (+ japanlaw-winconf-index
		  (if japanlaw-winconf-list
		      1
		    0))
	       (length japanlaw-winconf-list))
     "Not stored.")))

;;
;; parenthesis
;;
(defun japanlaw-forward-paren (arg)
  (interactive "P")
  (cond
   (current-prefix-arg
    (japanlaw-backward-paren))
   ((eq (char-after) ?\（)
    (forward-list)
    (japanlaw-forward-paren nil))
   ((re-search-forward ".（" nil t)
    (backward-char))))

(defun japanlaw-backward-paren ()
  (and (re-search-backward ".（" nil t)
       (forward-char)))

(defun japanlaw-fontify-or-defontify-paren ()
  (interactive)
  (destructuring-bind (beg . end) (japanlaw-current-article)
    (or (let ((pos (and japanlaw-paren-overlays
			(overlay-start (car japanlaw-paren-overlays)))))
	  ;; overlayが設定済みか
	  ;; overlayの位置が現在の条文内か
	  (and pos
	       (< beg pos)
	       (< pos end)
	       ;; defontify
	       (japanlaw-defontify-paren)))
	(or (and japanlaw-paren-overlays
		 ;; 他の条項でoverlayが設定済み
		 ;; defontify other
		 (japanlaw-defontify-paren)
		 ;; fontify
		 (japanlaw-fontify-paren))
	    ;; 通常のケース
	    ;; fontify
	    (japanlaw-fontify-paren)))))

(defun japanlaw-fontify-paren (&optional beg end)
  (interactive)
  (or (and beg end)
      (destructuring-bind (bg . ed) (japanlaw-current-article)
	(setq beg bg end ed)))
  (let ((paren (japanlaw-matching-parens beg end)))
    (save-excursion
      (mapc (lambda (x)
	      (japanlaw-paren-overlay-put (goto-char (car x)) (cdr x)))
	    paren))))

(defun japanlaw-defontify-paren ()
  (interactive)
  (when japanlaw-paren-overlays
    (mapc #'delete-overlay japanlaw-paren-overlays)))

(defun japanlaw-paren-overlay-put (beg end)
  (or (looking-at japanlaw-paren-exclude-regexp)
;      (looking-at "（[^）]*?」")
      (let ((overlays '(japanlaw-paren1-face
			japanlaw-paren2-face
			japanlaw-paren3-face
			japanlaw-paren4-face
			japanlaw-paren5-face
			japanlaw-paren6-face)))
	(let ((ov (memq (get-char-property (point) 'face)
			overlays)))
	  (overlay-put (car (push (make-overlay beg end)
				  japanlaw-paren-overlays))
		       'face
		       (or (and ov
				(or (and (eq (car ov)
					     (last overlays))
					 (last overlays))
				    (cadr ov)))
			   (car overlays)))))))

(defun japanlaw-matching-parens (begin end &optional outside-only)
  ;; Invalid search bound (wrong side of point)
  (save-excursion
    (goto-char begin)
    (let (parens)
      (while (re-search-forward japanlaw-parens end t)
	(push (cons (match-beginning 0)
		    (scan-lists (match-beginning 0) 1 0)) parens)
	(goto-char (or (and outside-only
			    (scan-lists (match-beginning 0) 1 0))
		       (+ (match-beginning 0) 1))))
      (nreverse parens))))

(defun japanlaw-compose-paren-toggle ()
  (interactive)
  (let ((end (cadr (get-text-property (point) 'composition)))
	(beg (point)))
    (and (eq (char-after) ?\（)
	 (if end
	     (decompose-region beg (+ beg end))
	   (japanlaw-compose-paren (point) (scan-lists (point) 1 0))))))

(defun japanlaw-compose-paren (&optional beg end)
  (interactive)
  (or (and beg end)
      (destructuring-bind (bg . ed) (japanlaw-current-article)
	(setq beg bg end ed)))
  (let ((parens (japanlaw-matching-parens beg end 'outside-only)))
    (save-excursion
      (mapc (lambda (x)
	      (japanlaw-compose-region (goto-char (car x)) (cdr x)))
	    parens))))

(defun japanlaw-compose-region (beg end)
  (or (looking-at japanlaw-paren-exclude-regexp)
      (compose-region beg end japanlaw-compose-paren-char)))

(defun japanlaw-decompose-paren ()
  (interactive)
  (destructuring-bind (beg . end) (japanlaw-current-article)
    (and current-prefix-arg
	 (setq beg (point-min) end (point-max)))
    (decompose-region beg end)))

;;
;; information
;;

;; (defun japanlaw-display-file-info ()
;;   (interactive)
;;   (pop-to-buffer
;;    (with-current-buffer (get-buffer-create "*JapanLawInfo*")
;;      (japanlaw-with-buffer-read-only
;;       (insert
;;        (apply #'format
;; 	      (mapconcat (lambda (s) (format "%-20s%%s" s))
;; 			 '("法令名" "URL" "HTML" "ファイル名" "日付") "\n")
;; 	      (japanlaw-file-info (buffer-file-name)))))
;;      (current-buffer))))

;; (defun japanlaw-file-info (file)
;;   (let ((data (japanlaw-read-init-file file)))
;;     (let ((name (plist-get data :name))
;; 	  (url  (plist-get data :url))
;; 	  (html (plist-get data :html))
;; 	  (file (plist-get data :file))
;; 	  (date (plist-get data :date)))
;;       (list name url html file date))))

(defun japanlaw-describe-bindings (keymap)
  (let ((name (symbol-name keymap)))
    (help-setup-xref (list #'japanlaw-describe-bindings keymap)
                     nil)
    (with-output-to-temp-buffer "*Help*"
      (princ name) (terpri)
      (princ (make-string (length name) ?-)) (terpri) (terpri)
      (princ (substitute-command-keys (concat "\\{" name "}"))))))

(defun japanlaw-help ()
  (interactive)
  (japanlaw-describe-bindings 'japanlaw-mode-map))

(defun japanlaw-index-help ()
  (interactive)
  (japanlaw-describe-bindings 'japanlaw-index-mode-map))

;;
;; outline
;;
(defun japanlaw-outline-regexps ()
  (let ((number "[一二三四五六七八九十]"))
    (setq outline-regexp
	  (concat ;; 目次
	   ;; 目次のアウトラインヘッダが行頭にある場合(廃止法令等一覧)
	   ;; がある。
	   "^"
	   "\\(　\\{2\\}第" number "+編"
	   "\\|　\\{3\\}第" number "+章"
	   "\\|　\\{4\\}第" number "+節"
	   "\\|　\\{5\\}第" number "+款"
	   "\\|　\\{6\\}第" number "+目"
	   "\\|　\\{3\\}附　則"
	   ;; 本文
	   ;; 本文のアウトラインヘッダは、行頭から始まってい
	   ;; ないこと。
	   "\\|第"     number "+編　"
	   "\\|\\(第"  number "+章"
	   "\\([のノ]" number "\\)*\\)　"
	   "\\|\\(第"  number "+節"
	   "\\([のノ]" number "\\)*\\)　"
	   "\\|\\(第"  number "+款"
	   "\\([のノ]" number "\\)*\\)　"
	   "\\|\\(第"  number "+目"
	   "\\([のノ]" number "\\)*\\)　"
	   "\\|附則　?.*$\\)")))
  (setq outline-level 'japanlaw-outline-level))

(defun japanlaw-outline-level ()
  (save-excursion
    (let ((str (if (looking-at outline-regexp) (match-string 1) ""))
	  (number "[一二三四五六七八九十]"))
      (cond
       ((string-match (concat "第" number "+編") str) 1)
       ((string-match (concat "第" number "+章") str) 2)
       ((string-match (concat "第" number "+節") str) 3)
       ((string-match (concat "第" number "+款") str) 4)
       ((string-match (concat "第" number "+目") str) 5)
       ((string-match "附　?則" str) japanlaw-supplementary-level)
       (t 0)))))

(defun japanlaw-outline-forward-same-level (n)
  ;; from outline.el
  (outline-back-to-heading)
  (catch 'loop
    (while (> n 0)
      (let ((point-to-move-to (save-excursion
				(outline-get-next-sibling))))
	(if point-to-move-to
	    (progn
	      (goto-char point-to-move-to)
	      (setq n (1- n)))
	  (throw 'loop
		 (prog1 t
		   (message "No following same-level heading."))))))))

(defun japanlaw-outline-up-heading (n)
  ;; from outline.el
  (outline-back-to-heading)
  (if (eq (funcall outline-level) 1)
      (error "Already at top level of the outline."))
  (while (and (> (funcall outline-level) 1)
	      (> n 0)
	      (not (bobp)))
    (let ((present-level (funcall outline-level)))
      (while (and (not (< (funcall outline-level) present-level))
		  (not (bobp)))
	(outline-previous-visible-heading 1))
      (setq n (- n 1)))))

(defun japanlaw-outline-header-p ()
  (memq (get-text-property (point) 'face)
	'(japanlaw-volume-face
	  japanlaw-chapter-face
	  japanlaw-section-face
	  japanlaw-subsection-face
	  japanlaw-subsection2-face)))

(defun japanlaw-previous-visible-heading (n)
  (interactive "p")
  (forward-line 0)
  (if (and
       (japanlaw-heading-level)
       (not (looking-at outline-regexp)))
      (progn
	(forward-line -1)
	(and (looking-at "^$")
	     ;; return if blank line
	     (forward-line)
	     (error "No previous heading.")))
    (outline-previous-visible-heading n)
    (japanlaw-recenter t)))

(defun japanlaw-next-visible-heading (n)
  (interactive "p")
  (forward-line 0)
  (if (and
       (japanlaw-heading-level)
       (not (looking-at outline-regexp)))
      (progn
	(forward-line)
	(and (looking-at "^$")
	     ;; return if blank line
	     (forward-line -1)
	     (error "No following heading.")))
    (outline-next-visible-heading n)
    (japanlaw-recenter t)))

(defun japanlaw-forward-same-level (n)
  (interactive "p")
  ;; when japanlaw-heading-level
  (and (japanlaw-heading-level)
       (if (looking-at outline-regexp)
	   ;; outline heading
	   (progn (outline-forward-same-level n)
		  (japanlaw-recenter t))
	 ;; not outline heading
	 (if (save-excursion (forward-line)
			     (looking-at "^$"))
	     ;; blank line
	     (error "No following same-level heading.")
	   ;; not blank line
	   (let ((pt (point)))
	     ;; error if forward-line is japanlaw-supplementary-level
	     (if (and (/= (car (japanlaw-heading-level))
			  japanlaw-supplementary-level)
		      (save-excursion (forward-line)
				      (= (car (japanlaw-heading-level))
					 japanlaw-supplementary-level)))
		 (error "No following same-level heading.")
	       (condition-case err
		   (japanlaw-forward-same-level-2)
		 (error
		  ;; Return to the position, if no following same level.
		  (goto-char pt)
		  (error "No following same-level heading.")))
	       ;; Returns to the position, if point is an outline header.
	       (when (looking-at outline-regexp)
		 (goto-char pt)
		 (error "No following same-level heading."))))))))

(defun japanlaw-forward-same-level-2 ()
  (let ((level (car (japanlaw-heading-level)))
	(pt (point)))
    (japanlaw-next-visible-heading 1)
    (if (> level (car (japanlaw-heading-level)))
	(progn
	  (japanlaw-previous-visible-heading 1)
	  (error "No following same-level heading."))
      (while (< level (car (japanlaw-heading-level)))
	(japanlaw-next-visible-heading 1))
      (and
       (> level (car (japanlaw-heading-level)))
       (goto-char pt)
       (error "No following same-level heading.")))))

(defun japanlaw-backward-same-level (n)
  (interactive "p")
  (and
   (japanlaw-heading-level)
   (if (looking-at outline-regexp)
       (progn
	 (outline-backward-same-level n)
	 (japanlaw-recenter t))
     (if (save-excursion (forward-line -1)
			 (not (japanlaw-heading-level)))
	 (error "No previous same-level heading.")
       (japanlaw-backward-same-level-2)))))

(defun japanlaw-backward-same-level-2 ()
  (let ((level (car (japanlaw-heading-level))))
    (japanlaw-previous-visible-heading 1)
    (if (> level (car (japanlaw-heading-level)))
	(progn
	  (japanlaw-next-visible-heading 1)
	  (error "No previous same-level heading."))
      (while (< level (car (japanlaw-heading-level)))
	(japanlaw-previous-visible-heading 1)))))

(defun japanlaw-up-heading (n)
  (interactive "p")
  (if (japanlaw-heading-level)
      (if (or ;; top-level or second-level(but not exists top-level)
	      (eq (car (funcall 'japanlaw-heading-level)) 1)
		  (and (eq (car (funcall 'japanlaw-heading-level)) 2)
		       (not (re-search-backward
			     "^　+第[一二三四五六七八九十]+編" nil t))))
	  (error "Already at top level of the outline.")
	(if (= 0 (japanlaw-outline-level))
	    (japanlaw-up-heading-2)
	  (condition-case err
	      (outline-up-heading n)
	    (error nil))
	  (japanlaw-recenter t)))
    (outline-back-to-heading)
    (japanlaw-recenter t)))

(defun japanlaw-up-heading-2 ()
  (if (looking-at "^　+第[一二三四五六七八九]+編")
      (error "")
  (let ((level (car (japanlaw-heading-level))))
    (while (<= level (car (japanlaw-heading-level)))
      (japanlaw-previous-visible-heading 1)))))

(defun japanlaw-heading-level ()
  (save-excursion
    (let ((str (if (looking-at japanlaw-heading-regexp) (match-string 1) ""))
	  (number "[一二三四五六七八九十]"))
      (cond
       ((string-match (concat "第" number "+編") str)
	(cons 1 (match-string 0 str)))
       ((string-match
	 (concat "第" number "+章\\([のノ]" number "\\)*") str)
	(cons 2 (match-string 0 str)))
       ((string-match
	 (concat "第" number "+節\\([のノ]" number "\\)*") str)
	(cons 3 (match-string 0 str)))
       ((string-match
	 (concat "第" number "+款\\([のノ]" number "\\)*") str)
	(cons 4 (match-string 0 str)))
       ((string-match
	 (concat "第" number "+目\\([のノ]" number "\\)*") str)
	(cons 5 (match-string 0 str)))
       ((string-match "附　?則" str)
	(cons japanlaw-supplementary-level (match-string 0 str)))
       (t nil)))))

(defun japanlaw-heading-list ()
  (let* ((heading (japanlaw-heading-level))
	 (level (car heading))
	 (header-string-list (cons (cdr heading) '())))
    (cond
     ((null heading)
      (error "Not header line point."))
     ((= level 1) nil)			 ; 編
     ((= japanlaw-supplementary-level level) ; 附則
      (setq header-string-list (list "附　?則")))
     (t
      (catch 'loop
	(save-excursion
	  (while (< 0 level)
	    (if (re-search-backward japanlaw-heading-regexp nil t)
		(when (= (1- level) (car (japanlaw-heading-level)))
		  (setq level (1- level)
			header-string-list (cons (cdr (japanlaw-heading-level))
						 header-string-list)))
	      (throw 'loop nil)))))))
    header-string-list))

(defun japanlaw-heading-jump ()
  (interactive)
  (forward-line 0)
  (let ((lst (japanlaw-heading-list)))
    (when lst
      (and
       (looking-at outline-regexp)
       (goto-char (point-min)))
      (forward-char)
      (while lst
	(re-search-forward
	 (concat "^　*" (car lst)
		 (if (string= "附　?則" (car lst)) "" "　")) nil t)
	(pop lst))
      (forward-line 0)
      (and
       (looking-at outline-regexp)
       (japanlaw-recenter t)))))

(defun japanlaw-goto-toc ()
  "目次に移動するコマンド。"
  (interactive)
  (let ((pt (save-excursion
	      (goto-char (point-min))
	      (re-search-forward "^　+第一[編章]" nil t))))
    (if (not pt)
	(message "No table of contents found.")
      (goto-char pt)
      (forward-line 0)
      (recenter 1))))

(defun japanlaw-move-to-tables ()
  "罫線表に移動するコマンド。"
  (interactive)
  (let ((backto (point)))
    (forward-char)
    (if (re-search-forward "^┌" nil t)
	(forward-line 0)
      (goto-char backto)
      (error "No chart found."))))

;;
;; Bookmark
;;
(defun japanlaw-bookmark-this-file ()
  (interactive)
  (let ((id (japanlaw-get-id (japanlaw-current-buffer-law-name))))
    (if (member id (japanlaw-bookmark-alist))
	(message "Already exists in Bookmark.")
      (push id japanlaw-bookmark-alist)
      (message "Add to Bookmark `%s'" (japanlaw-current-buffer-law-name)))))

;;
;; iswitchb
;;
(defun japanlaw-icompleting-read (prompt choices)
  ;; See iswitchb.el commentary.
  (let ((minibuffer-setup-hook 'iswitchb-minibuffer-setup)
	(iswitchb-make-buflist-hook
         (lambda ()
           (setq iswitchb-temp-buflist choices)))
	(max-mini-window-height japanlaw-max-mini-window-height))
    (iswitchb-read-buffer prompt)))

(defun japanlaw-iswitchb (subject)
  "iswitchbで法令ファイルを開く。
ローマ字によるインクリメンタル検索(migemo)を利用するため、
migemoとiswitchbの設定が必要。"
  (interactive (japanlaw-iswitchb-interactive))
  (message "Reading names...")
  (let ((name (funcall
	       (if japanlaw-use-iswitchb
		   #'japanlaw-icompleting-read
		 #'completing-read)
	       (format "[%S] Switch to: " subject)
	       (case subject
		 (all		(japanlaw-names-list))
		 (bookmark	(japanlaw-iswitchb-bookmark-list))
		 (download	(japanlaw-iswitchb-download-list))
		 (t		(error "error: %S" subject))))))
    (japanlaw-open-file (or (japanlaw-get-id name) (error "No match.")))))

(defun japanlaw-iswitchb-interactive ()
  (unless (file-exists-p japanlaw-index-file)
    (error "Try `M-x japanlaw'"))
  (when japanlaw-setup-p (japanlaw-setup))
  (list (if current-prefix-arg
	    (setq japanlaw-iswitchb-present-list
		  (intern
		   (let* ((collection '("all" "bookmark" "download"))
			  (subject
			   (completing-read "Select a list: "
					    collection nil t)))
		     (or (car (member subject collection))
			 japanlaw-iswitchb-present-list
			 'all))))
	  (or japanlaw-iswitchb-present-list japanlaw-iswitchb-initial-list))))

(defun japanlaw-directory-files-recursive (parent match ext)
  (japanlaw:fringe
   (mapcar (lambda (dir)
	     (directory-files dir nil ext))
	   (japanlaw:filter 'file-directory-p (directory-files parent t match)))))

(defun japanlaw-names-list ()
  "登録法令名と略称法令名のリストを返す。"
  (or japanlaw-names-list
      (setq japanlaw-names-list
	    (let ((result nil))
	      ;; 登録法令名
	      (do ((xs (japanlaw-alist) (cdr xs)))
		  ((null xs))
		(do ((ys (cdar xs) (cdr ys)))
		    ((null ys))
		  (push (car (caar ys)) result)))
	      ;; 略称法令名
	      (do ((xs (japanlaw-abbrev) (cdr xs)))
		  ((null xs) (delete-dups (nreverse result)))
		(do ((ys (cdar xs) (cdr ys)))
		    ((null ys) result)
		  (push (substring (caar ys) 1 -1) result)))))))

(defun japanlaw-download-list (type)
  (when (file-exists-p japanlaw-htmldata-path)
    (let ((func
	   (case type
	     (id (lambda (f)
		   (upcase (file-name-sans-extension f))))
	     (name (lambda (f)
		     (japanlaw-get-name (upcase (file-name-sans-extension f))))))))
      (mapcar func
	      (japanlaw-directory-files-recursive
	       japanlaw-htmldata-path "\\`[MTSH][0-9]+\\'"
	       (concat "\\.html\\'"))))))

(defun japanlaw-iswitchb-download-list () (japanlaw-download-list 'name))

(defun japanlaw-iswitchb-bookmark-list ()
  (mapcar (lambda (x) (japanlaw-get-name x)) (japanlaw-bookmark-alist)))


;;
;; japanlaw-mode
;;
(easy-menu-define japanlaw-mode-menu
    japanlaw-mode-map
  "japanlaw-mode-menu"
  '("JapanLaw"
    ["Digit Argument 0..9 -" nil]
    ["Search And Push Anchor" japanlaw-search-or-push-anchor t]
    ["JapanLaw Iswitchb" japanlaw-iswitchb t]
    ["Forward Anchor" japanlaw-forward-anchor t]
    ["Backward Anchor" japanlaw-backward-anchor t]
    "-"
    ["Browse This URL" japanlaw-browse-current-url t]
    ["Print/Copy This URL" japanlaw-print-current-url t]
    "-"
    ["Toggle Fontify Parens" japanlaw-fontify-or-defontify-paren t]
    ["Compose Parens" japanlaw-compose-paren t]
    ["Decompose Parens" japanlaw-decompose-paren t]
    "-"
    ["Winconf Add" japanlaw-winconf-add t]
    ["Winconf Insert" japanlaw-winconf-insert t]
    ["Winconf Override" japanlaw-winconf-override t]
    ["Winconf Delete" japanlaw-winconf-delete t]
    ["Winconf Backward Delete" japanlaw-winconf-backward-delete t]
    ["Winconf Delete All" japanlaw-winconf-delete-all t]
    ["Winconf Message" japanlaw-winconf-message t]
    "-"
    ["Restore Current Winconf" japanlaw-restore-current-winconf t]
    ["Restore First Winconf" japanlaw-restore-first-winconf t]
    ["Restore Last Winconf" japanlaw-restore-last-winconf t]
    ["Forward Winconf" japanlaw-forward-winconf t]
    ["Backward Winconf" japanlaw-backward-winconf t]
    "-"
    ["Display Other buffer" japanlaw-display-toggle t]
    ["Other Window" japanlaw-other-window t]
    "-"
    ["Forward Parens" japanlaw-forward-paren t]
    ["Forward Article" japanlaw-forward-article t]
    ["Backward Article" japanlaw-backward-article t]
    ["Forward Paragraph" japanlaw-forward-paragraph t]
    ["Backward Paragraph" japanlaw-backward-paragraph t]
    "-"
    ["Help" japanlaw-help t]
    ["View Quit And Return Index" japanlaw-view-quit t]
    ))

(defun japanlaw-mode ()
  (interactive)
  (unless (buffer-file-name)
    (error "No visited file."))
  (unless (equal (japanlaw-expand-data-file
		  (file-name-sans-extension
		   (file-name-nondirectory (buffer-file-name))))
		 (buffer-file-name))
    (message "File `%s' is irregular law's path name." (buffer-file-name))
    (sleep-for 3))
  (kill-all-local-variables)
  (use-local-map japanlaw-mode-map)
  (setq mode-name japanlaw-mode-name)
  (setq major-mode 'japanlaw-mode)
  (setq buffer-read-only t)
  (set (make-local-variable 'japanlaw-paren-overlays) nil)
  (set (make-local-variable 'font-lock-defaults)
       '(japanlaw-font-lock-keywords))
  (let ((init (japanlaw-read-init-file)))
    ;; font-lock-keywords
    (setq japanlaw-font-lock-keywords
	  (append japanlaw-font-lock-keywords-0
		  japanlaw-font-lock-keywords-1
		  (let ((regs (car init)))
		    ;; `japanlaw-font-lock-keywords-2'
		    ;; 法令ファイルごとにバッファローカルな設定。
		    ;; `japanlaw-anchor-clickable'
		    (cond ((and regs japanlaw-anchor-clickable)
			   (list `(,regs (0 japanlaw-anchor-name-face t))
				 `(,regs ,(japanlaw-set-mouse-face-2 0))))
			  (regs (list `(,regs (0 japanlaw-anchor-name-face t))))
			  (t nil)))))
    ;; iimage
    (when (nth 2 init)
      (iimage-mode 1))
    ;; 未施行法令のリンク先設定
    (set (make-local-variable 'japanlaw-mishikou-list)
	 (cadr (japanlaw-read-init-file))))
  (turn-on-font-lock)
  (setq line-spacing japanlaw-line-space)
  ;; imenu
  (setq imenu-generic-expression
	'((nil "^第[一二三四五六七八九十百千のノ]+条.\\{1,20\\}" 0)))
  (imenu-add-to-menubar "Articles")
  (easy-menu-add japanlaw-mode-menu)
  ;; outline
  (make-local-variable 'outline-regexp)
  (make-local-variable 'outline-level)
  (japanlaw-outline-regexps)
  (and japanlaw-mode-line
       (setq mode-line-buffer-identification japanlaw-mode-line))
  (run-hooks 'japanlaw-mode-hook))

(defun japanlaw-setup ()
  (when japanlaw-setup-p

    (when japanlaw-use-buffer-law-name
      (add-hook 'japanlaw-mode-hook 'japanlaw-rename-buffer))

    ;; Read bookmark file.
    (japanlaw-bookmark-alist)

    ;; Read Recent file.
    (japanlaw-recent-alist)

    ;; `japanlaw-bookmark-alist'
    (add-hook 'kill-emacs-hook 'japanlaw-bookmark-save)

    ;; `japanlaw-recent-alist'
    (add-hook 'kill-emacs-hook 'japanlaw-recent-save)

    ;; `japanlaw-recent-add'
    (add-hook 'find-file-hook 'japanlaw-recent-add)

    (setq japanlaw-setup-p nil)
    (message "japanlaw setup...done")))

(defun japanlaw-exit ()
  (interactive)
  (unless (memq major-mode '(japanlaw-mode japanlaw-index-mode))
    (error ""))
  (unless (y-or-n-p "Exit japanlaw? ")
    (error ""))
  (japanlaw-bookmark-save)
  (japanlaw-recent-save)
  (remove-hook 'kill-emacs-hook 'japanlaw-recent-save)
  (remove-hook 'kill-emacs-hook 'japanlaw-bookmark-save)
  (mapc (lambda (cel)
	  (kill-buffer (get-file-buffer (japanlaw-expand-data-file (cdr cel)))))
	(japanlaw-opened-alist))
  (setq japanlaw-alist nil
	japanlaw-abbrev nil
	japanlaw-abbrev-alist nil
	japanlaw-bookmark-alist nil
	japanlaw-recent-alist nil
	japanlaw-opened-alist nil
	japanlaw-winconf-list nil
	japanlaw-winconf-index 0
	japanlaw-display-toggle-winconf nil
	japanlaw-names-list nil
	japanlaw-iswitchb-present-list nil)
  (setq japanlaw-setup-p t)
  (message "Initialize japanlaw variables...done")
  (when (get-buffer japanlaw-index-buffer)
    (kill-buffer japanlaw-index-buffer))
  (message "Kill all japanlaw buffers...done"))

(add-hook 'japanlaw-index-mode-hook 'japanlaw-setup)
(add-hook 'japanlaw-mode-hook 'japanlaw-setup)

(provide 'japanlaw)

;;; japanlaw.el ends here
