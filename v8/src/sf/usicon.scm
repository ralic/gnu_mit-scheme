#| -*-Scheme-*-

Copyright (c) 1987-1999 Massachusetts Institute of Technology

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or (at
your option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
|#

;;;; SCode Optimizer: Usual Integrations: Constants
;;; package: (scode-optimizer)

(declare (usual-integrations)
	 (integrate-external "object"))

(define usual-integrations/constant-names)
(define usual-integrations/constant-values)
(define usual-integrations/constant-alist)
(define usual-integrations/constant-alist-names*values)

(define (usual-integrations/delete-constant! name)
  (set! global-constant-objects (delq! name global-constant-objects))
  (usual-integrations/cache!))

(define (usual-integrations/cache!)
  (set! usual-integrations/constant-names
	(list-copy global-constant-objects))
  (set! usual-integrations/constant-values
	(map (lambda (name)
	       (let ((object
		      (lexical-reference system-global-environment name)))
		 (if (not (memq (microcode-type/code->name
				 (object-type object))
				'(BIGNUM
				  CHARACTER
				  POSITIVE-FIXNUM  NEGATIVE-FIXNUM  FIXNUM
				  FLONUM
				  INTERNED-SYMBOL
				  NULL
				  PAIR
				  PRIMITIVE
				  QUAD
				  RATNUM
				  RECNUM
				  RETURN-CODE
				  STRING
				  TRIPLE
				  CONSTANT TRUE
				  UNINTERNED-SYMBOL
				  VECTOR
				  VECTOR-16B
				  VECTOR-1B)))
		     (error "USUAL-INTEGRATIONS: not a constant" name))
		 (constant->integration-info object)))
	     usual-integrations/constant-names))
  (set! usual-integrations/constant-alist
	(map (lambda (name)
	       (cons name
		     (constant/make
		      false
		      (lexical-reference system-global-environment name))))
	     usual-integrations/constant-names))
  (set! usual-integrations/constant-alist-names*values
	(map cons usual-integrations/constant-names
	          usual-integrations/constant-values))
  'DONE)