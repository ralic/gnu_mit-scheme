#| -*-Scheme-*-

$Id: load.scm,v 1.1 2003/12/29 05:24:36 uid67408 Exp $

Copyright 2003 Massachusetts Institute of Technology

This file is part of MIT/GNU Scheme.

MIT/GNU Scheme is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or (at
your option) any later version.

MIT/GNU Scheme is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with MIT/GNU Scheme; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307,
USA.

|#

;;;; XDOC/mod-lisp loader

(load-option 'xml)
(load-option 'postgresql)
(load-option 'mime-codec)
(with-working-directory-pathname (directory-pathname (current-load-pathname))
  (lambda ()
    (load "xhtml-expander")
    (load "xhtml")
    (load "mod-lisp")
    (load "db")
    (load "matcher")
    (load "xdoc")
    (load "xmlrpc")))