#| -*-Scheme-*-

$Header: /Users/cph/tmp/foo/mit-scheme/mit-scheme/v7/src/compiler/back/lapgn3.scm,v 1.1 1987/06/13 21:18:20 cph Exp $

Copyright (c) 1987 Massachusetts Institute of Technology

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

;;;; LAP Generator

(declare (usual-integrations))

;;;; Constants

(define *next-constant*)
(define *interned-constants*)
(define *interned-variables*)
(define *interned-uuo-links*)

(define (allocate-constant-label)
  (let ((label
	 (string->symbol
	  (string-append "CONSTANT-" (write-to-string *next-constant*)))))
    (set! *next-constant* (1+ *next-constant*))
    label))

(define (constant->label constant)
  (let ((entry (assv constant *interned-constants*)))
    (if entry
	(cdr entry)
	(let ((label (allocate-constant-label)))
	  (set! *interned-constants*
		(cons (cons constant label)
		      *interned-constants*))
	  label))))

(define (free-reference-label name)
  (let ((entry (assq name *interned-variables*)))
    (if entry
	(cdr entry)
	(let ((label (allocate-constant-label)))
	  (set! *interned-variables*
		(cons (cons name label)
		      *interned-variables*))
	  label))))

(define (free-uuo-link-label name)
  (let ((entry (assq name *interned-uuo-links*)))
    (if entry
	(cdr entry)
	(let ((label (allocate-constant-label)))
	  (set! *interned-uuo-links*
		(cons (cons name label)
		      *interned-uuo-links*))
	  label))))

(define-integrable (set-current-branches! consequent alternative)
  (set-rtl-pnode-consequent-lap-generator! *current-rnode* consequent)
  (set-rtl-pnode-alternative-lap-generator! *current-rnode* alternative))

;;;; Frame Pointer

(define *frame-pointer-offset*)

(define (disable-frame-pointer-offset! instructions)
  (set! *frame-pointer-offset* false)
  instructions)

(define (enable-frame-pointer-offset! offset)
  (if (not offset) (error "Null frame-pointer offset"))
  (set! *frame-pointer-offset* offset))

(define (record-push! instructions)
  (if *frame-pointer-offset*
      (set! *frame-pointer-offset* (1+ *frame-pointer-offset*)))
  instructions)

(define (record-pop!)
  (if *frame-pointer-offset*
      (set! *frame-pointer-offset* (-1+ *frame-pointer-offset*))))

(define (decrement-frame-pointer-offset! n instructions)
  (if *frame-pointer-offset*
      (set! *frame-pointer-offset*
	    (and (<= n *frame-pointer-offset*) (- *frame-pointer-offset* n))))
  instructions)

(define (guarantee-frame-pointer-offset!)
  (if (not *frame-pointer-offset*) (error "Frame pointer not initialized")))

(define (increment-frame-pointer-offset! n instructions)
  (guarantee-frame-pointer-offset!)
  (set! *frame-pointer-offset* (+ *frame-pointer-offset* n))
  instructions)

(define (frame-pointer-offset)
  (guarantee-frame-pointer-offset!)
  *frame-pointer-offset*)

(define (record-continuation-frame-pointer-offset! label)
  (let ((continuation (label->continuation label)))
    (guarantee-frame-pointer-offset!)
    (if (continuation-frame-pointer-offset continuation)
	(if (not (= (continuation-frame-pointer-offset continuation)
		    *frame-pointer-offset*))
	    (error "Continuation frame-pointer offset mismatch" continuation
		   *frame-pointer-offset*))
	(set-continuation-frame-pointer-offset! continuation
						*frame-pointer-offset*))
    (enqueue! *continuation-queue* continuation)))

(define (record-rnode-frame-pointer-offset! rnode offset)
  (if (rnode-frame-pointer-offset rnode)
      (if (not (and offset (= (rnode-frame-pointer-offset rnode) offset)))
	  (error "RNode frame-pointer offset mismatch" rnode offset))
      (set-rnode-frame-pointer-offset! rnode offset)))