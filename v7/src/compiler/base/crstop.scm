#| -*-Scheme-*-

$Header: /Users/cph/tmp/foo/mit-scheme/mit-scheme/v7/src/compiler/base/crstop.scm,v 1.2 1989/05/21 02:38:50 jinx Exp $
$MC68020-Header: toplev.scm,v 4.16 89/04/26 05:09:52 GMT cph Exp $

Copyright (c) 1988, 1989 Massachusetts Institute of Technology

This material was developed by the Scheme project at the Massachusetts
Institute of Technology, Department of Electrical Engineering and
Computer Science.  Permission to copy this software, to redistribute
it, and to use it for any purpose is granted, subject to the following
restrictions and understandings.

1. Any copy made of this software must include this copyright notice
in full.

2. Users of this software agree to make their best efforts (a) to
return to the MIT Scheme project any improvements or extensions that
they make, so that these may be included in future releases; and (b)
to inform MIT of noteworthy uses of this software.

3. All materials developed as a consequence of the use of this
software shall duly acknowledge such use, in accordance with the usual
standards of acknowledging credit in academic research.

4. MIT has made no warrantee or representation that the operation of
this software will be error-free, and MIT is under no obligation to
provide any services, by way of maintenance, update, or otherwise.

5. In conjunction with products arising from the use of this material,
there shall be no use of the name of the Massachusetts Institute of
Technology nor of any adaptation thereof in any advertising,
promotional, or sales literature without prior written consent from
MIT in each case. |#

;;;; Cross Compiler Top Level.
;;; This code shares and should be merged with toplev.scm.
;;; Many of the procedures only differ in the default extensions.

(declare (usual-integrations))

(define-macro (last-reference name)
  (let ((x (generate-uninterned-symbol)))
    `(IF COMPILER:PRESERVE-DATA-STRUCTURES?
	 ,name
	 (LET ((,x ,name))
	   (SET! ,name)
	   ,x))))

(define (cross-compile-bin-file input-string #!optional output-string)
  (let ((input-default
	 (make-pathname false false false false "bin" 'NEWEST))
	(output-default
	 (make-pathname false false false false "bits.x" false)))
    (compiler-pathnames
     input-string
     (if (not (default-object? output-string))
	 output-string
	 (merge-pathnames output-default
			  (pathname->input-truename
			   (merge-pathnames (->pathname input-string)
					    input-default))))
     input-default
     (lambda (input-pathname output-pathname)
       (cross-compile-scode (compiler-fasload input-pathname)
			    (and compiler:generate-rtl-files?
				 (pathname-new-type output-pathname "brtl.x"))
			    (pathname-new-type output-pathname "binf.x"))))))

(define (cross-compile-bin-file-end input-string #!optional output-string)
  (compiler-pathnames
   input-string
   (and (not (default-object? output-string)) output-string)
   (make-pathname false false false false "bits.x" 'NEWEST)
   (lambda (input-pathname output-pathname)
     (cross-compile-scode-end (compiler-fasload input-pathname)))))

(define (cross-compile-scode-end cross-compilation)
  (in-compiler
   (lambda ()
     (cross-link-end cross-compilation)
     compiler:expression)))

;; This should be merged with compile-scode

(define (cross-compile-scode scode
			     #!optional
			     rtl-output-pathname
			     info-output-pathname
			     wrapper)
  
  (if (default-object? rtl-output-pathname)
      (set! rtl-output-pathname false))
  (if (default-object? info-output-pathname)
      (set! info-output-pathname false))

  (fluid-let ((*info-output-pathname*
	       (if (and info-output-pathname
			(not (eq? info-output-pathname true)))
		   info-output-pathname
		   *info-output-pathname*))
	      (*rtl-output-pathname*
	       (if (and rtl-output-pathname
			(not (eq? rtl-output-pathname true)))		   rtl-output-pathname
		   *rtl-output-pathname*)))
    ((if (default-object? wrapper)
	 in-compiler
	 wrapper)
     (lambda ()
       (set! *input-scode* scode)
       (phase/fg-generation)
       (phase/fg-optimization)
       (phase/rtl-generation)
       (phase/rtl-optimization)
       (if rtl-output-pathname
	   (phase/rtl-file-output rtl-output-pathname))
       (phase/bit-generation)
       (phase/bit-linearization)
       (phase/assemble)
       (if info-output-pathname
	   (phase/info-generation-2 info-output-pathname))
       ;; Here is were this procedure differs from compile-scode
       (phase/cross-link)
       compiler:expression))))

(define-structure (cc-vector (constructor cc-vector/make)
			     (conc-name cc-vector/))
  (code-vector false read-only true)
  (entry-label false read-only true)
  (entry-points false read-only true)
  (label-bindings false read-only true)
  (ic-procedure-headers false read-only true))

(define (phase/cross-link)
  (compiler-phase
   "Cross Linkification"
   (lambda ()
     (set! compiler:expression
	 (cc-vector/make
	  (last-reference compiler:code-vector)
	  (last-reference compiler:entry-label)
	  (last-reference compiler:entry-points)
	  (last-reference compiler:label-bindings)
	  (last-reference *ic-procedure-headers*)))
     unspecific)))

(define (cross-link-end cc-vector)
  (set! compiler:code-vector (cc-vector/code-vector cc-vector))
  (set! compiler:entry-label (cc-vector/entry-label cc-vector))
  (set! compiler:entry-points (cc-vector/entry-points cc-vector))
  (set! compiler:label-bindings (cc-vector/label-bindings cc-vector))  (set! *ic-procedure-headers* (cc-vector/ic-procedure-headers cc-vector))
  (phase/link))