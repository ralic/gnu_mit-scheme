#| -*-Scheme-*-

Copyright (C) 1986, 1987, 1988, 1989, 1990, 1991, 1992, 1993, 1994,
    1995, 1996, 1997, 1998, 1999, 2000, 2001, 2002, 2003, 2004, 2005,
    2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014, 2015, 2016,
    2017 Massachusetts Institute of Technology

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
Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301,
USA.

|#

;;;; Predicates: lattice
;;; package: (runtime predicate-lattice)

(declare (usual-integrations))

(define (predicate<= predicate1 predicate2)
  (tag<= (predicate->tag predicate1)
         (predicate->tag predicate2)))

(define (predicate>= predicate1 predicate2)
  (predicate<= predicate2 predicate1))

(define (tag= tag1 tag2)
  (guarantee tag? tag1 'tag=)
  (guarantee tag? tag2 'tag=)
  (eq? tag1 tag2))

(define (tag<= tag1 tag2)
  (guarantee tag? tag1 'tag<=)
  (guarantee tag? tag2 'tag<=)
  (cached-tag<= tag1 tag2))

(define (tag>= tag1 tag2)
  (tag<= tag2 tag1))

(define (cached-tag<= tag1 tag2)
  (hash-table-intern! tag<=-cache
		      (cons tag1 tag2)
		      (lambda () (uncached-tag<= tag1 tag2))))

(define (uncached-tag<= tag1 tag2)
  (or (eq? tag1 tag2)
      (tag-is-bottom? tag1)
      (tag-is-top? tag2)
      (and (not (tag-is-top? tag1))
	   (not (tag-is-bottom? tag2))
	   (let ((v
		  (find (lambda (v)
			  (and ((vector-ref v 0) tag1)
			       ((vector-ref v 1) tag2)))
			tag<=-overrides)))
	     (if v
		 ((vector-ref v 2) tag1 tag2)
		 (any (lambda (tag)
			(cached-tag<= tag tag2))
		      (get-tag-supersets tag1)))))))

(define (define-tag<= test1 test2 handler)
  (set! tag<=-overrides
	(cons (vector test1 test2 handler)
	      tag<=-overrides))
  unspecific)

(define (top-tag) the-top-tag)
(define (bottom-tag) the-bottom-tag)

(define-integrable (tag-is-top? tag) (eq? the-top-tag tag))
(define-integrable (tag-is-bottom? tag) (eq? the-bottom-tag tag))

;; These definitions will be overwritten when the tags are created:
(define the-top-tag #f)
(define the-bottom-tag #f)

(define tag<=-cache)
(define tag<=-overrides)
(add-boot-init!
 (lambda ()
   ;; TODO(cph): should be a weak-key table, but we don't have tables that have
   ;; weak compound keys.
   (set! tag<=-cache (make-equal-hash-table))
   (set! tag<=-overrides '())
   (add-event-receiver! event:predicate-metadata metadata-event!)))

(define (metadata-event! operator tag . rest)
  (if (and (eq? operator 'set-tag<=!)
           (pair? rest))
      (let ((superset (car rest)))
        (if (tag<= tag superset)
            (error "Tag already has this superset:" tag superset))
        (if (tag>= tag superset)
            (error "Not allowed to create a superset loop:" tag superset))))
  (hash-table-clear! tag<=-cache))