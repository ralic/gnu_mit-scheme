;;; -*-Scheme-*-
;;;
;;; $Id: ed-ffi.scm,v 1.2 2000/01/18 20:57:19 cph Exp $
;;;
;;; Copyright (c) 2000 Massachusetts Institute of Technology
;;;
;;; This program is free software; you can redistribute it and/or
;;; modify it under the terms of the GNU General Public License as
;;; published by the Free Software Foundation; either version 2 of the
;;; License, or (at your option) any later version.
;;;
;;; This program is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;;; General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with this program; if not, write to the Free Software
;;; Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

;;;; IMAIL mail reader: Edwin buffer packaging info

(standard-scheme-find-file-initialization
 '#(("imail-core" (edwin imail) system-global-syntax-table)
    ("imail-file" (edwin imail) system-global-syntax-table)
    ("imail-rmail" (edwin imail) system-global-syntax-table)
    ("imail-top" (edwin imail) edwin-syntax-table)
    ("imail-umail" (edwin imail) system-global-syntax-table)
    ("imail-util" (edwin imail) system-global-syntax-table)
    ("rfc822" (edwin imail) system-global-syntax-table)))