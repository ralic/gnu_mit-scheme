#| -*-Scheme-*-

$Id: xdoc.scm,v 1.1 2003/12/29 05:24:51 uid67408 Exp $

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

;;;; XDOC implementation

(declare (usual-integrations))

(define *xdoc-environment*)
(define *xdoc-root*)
(define *xdoc-late?*)
(define *xdoc-element-properties*)
(define *xdoc-id-map*)
(define *xdoc-inputs*)
(define *xdoc-outputs*)
(define *trace-expansion-port* #f)

(define-mime-handler '(application/xdoc+xml "xdoc")
  (lambda (pathname port)
    ;; Should be "application/xhtml+xml" -- IE loses.
    (http-response-header 'content-type "text/html")
    (write-xml
     (with-xdoc-expansion-context (pathname->ps-number pathname) pathname
       (lambda (document)
	 (memoize-xdoc-inputs)
	 (memoize-xdoc-outputs)
	 (let ((pad-misc
		(lambda (misc)
		  (cons "\n"
			(append-map! (lambda (item) (list item "\n"))
				     misc)))))
	   (make-xml-document (or (xml-document-declaration document)
				  (make-xml-declaration "1.0" "utf-8" #f))
			      (pad-misc (xml-document-misc-1 document))
			      xhtml-dtd
			      (pad-misc (xml-document-misc-2 document))
			      (generate-xdoc-html (xml-document-root document))
			      (pad-misc (xml-document-misc-3 document))))))
     port
     'indent-dtd? #t
     'indent-attributes? #t)))

(define (pathname->ps-number pathname)
  (let ((s (car (last-pair (pathname-directory pathname)))))
    (let ((regs (re-string-match "\\`ps\\([0-9]+\\)\\'" s #t)))
      (if regs
	  (string->number (re-match-extract s regs 1))
	  0))))

(define (with-xdoc-expansion-context ps-number pathname procedure)
  (with-database-connection ps-number pathname
    (lambda ()
      (let ((environment (make-expansion-environment pathname)))
	(fluid-let ((*xdoc-environment* environment)
		    (*xdoc-root*)
		    (*xdoc-late?*)
		    (*xdoc-element-properties* (make-eq-hash-table))
		    (*xdoc-id-map* (make-eq-hash-table))
		    (*xdoc-inputs* (make-eq-hash-table))
		    (*xdoc-outputs* (make-eq-hash-table)))
	  (let ((document (read/expand-xml-file pathname environment)))
	    (set! *xdoc-root* (xml-document-root document))
	    (set! *xdoc-late?* (due-date-in-past?))
	    (xdoc-pre-passes document)
	    (if *trace-expansion-port*
		(begin
		  (write-xml document *trace-expansion-port*)
		  (fresh-line *trace-expansion-port*)
		  (flush-output *trace-expansion-port*)))
	    (procedure document)))))))

(define (trace-expansion filename)
  (set! *trace-expansion-port* (open-output-file filename))
  unspecific)

(define (untrace-expansion)
  (let ((port *trace-expansion-port*))
    (set! *trace-expansion-port* #f)
    (if port
	(close-port port))))

;;;; Document analysis

(define (xdoc-pre-passes document)
  (let ((root (xml-document-root document)))
    (strip-xdoc-space document)
    (save-structure-properties root)))

(define (strip-xdoc-space document)
  (let ((strip!
	 (lambda (object accessor modifier)
	   (modifier object
		     (delete-matching-items! (accessor object)
		       xml-comment?))
	   (modifier object
		     (delete-matching-items! (accessor object)
		       xml-whitespace-string?)))))
    (strip! document xml-document-misc-1 set-xml-document-misc-1!)
    (set-xml-document-dtd! document #f)
    (strip! document xml-document-misc-2 set-xml-document-misc-2!)
    (let loop ((elt (xml-document-root document)))
      (if (memq (xdoc-content-type elt) '(empty element))
	  (strip! elt xml-element-contents set-xml-element-contents!))
      (for-each (lambda (item)
		  (if (xml-element? item)
		      (loop item)))
		(xml-element-contents elt)))
    (strip! document xml-document-misc-3 set-xml-document-misc-3!)))

(define (save-structure-properties root)
  (receive (prefix n) (ps-info root)
    ;; Make unique top-level ID.
    (save-container-props root '() (string-append "xdoc_" prefix) 1 (- n 1))
    (let ((get-misc-id
	   (let ((prefix (string-append prefix (number->string n) "-"))
		 (count 0))
	     (lambda ()
	       (let ((id
		      (string->symbol
		       (string-append prefix
				      (string-pad-left (number->string count)
						       4
						       #\0)))))
		 (set! count (+ count 1))
		 id)))))
      (let walk-container
	  ((elt root)
	   (containers (list root))
	   (prefix prefix)
	   (offset (- n 1)))
	(let loop ((items (xml-element-contents elt)) (count 1))
	  (if (pair? items)
	      (let ((item (car items)))
		(if (xdoc-internal-container? item)
		    (begin
		      (walk-container item
				      (cons item containers)
				      (save-container-props item
							    containers
							    prefix
							    count
							    offset)
				      0)
		      (loop (cdr items) (+ count 1)))
		    (begin
		      (let walk-html ((item item))
			(if (xdoc-container? item)
			    (error "No containers in HTML:" item))
			(if (xdoc-element? item)
			    (save-element-props item containers (get-misc-id)))
			(if (xml-element? item)
			    (for-each walk-html (xml-element-contents item))))
		      (loop (cdr items) count))))))))))

(define-expander 'xdoc-part-number
  (lambda (name)
    (if (string-prefix? "xdoc_" name)
	(string-tail name 5)
	name)))

(define (ps-info elt)
  (let ((no (find-attribute 'first-problem elt #f)))
    (if no
	(let ((regs
	       (re-string-match "\\`\\(\\([0-9]+.\\)*\\)\\([0-9]+\\)\\'" no)))
	  (if (not regs)
	      (error "Malformed first-problem attribute:" no))
	  (values (re-match-extract no regs 1)
		  (string->number (re-match-extract no regs 3))))
	(values "" 1))))

(define (save-container-props elt containers prefix count offset)
  (let ((number (+ count offset)))
    (let ((db-id (string-append prefix (number->string number))))
      (hash-table/put! *xdoc-element-properties* elt
		       (vector (string->symbol db-id)
			       containers
			       prefix
			       number
			       count))
      (save-xdoc-id elt)
      (string-append db-id "."))))

(define (save-element-props elt containers db-id)
  (hash-table/put! *xdoc-element-properties* elt (vector db-id containers))
  (save-xdoc-id elt)
  (cond ((xdoc-input? elt)
	 (hash-table/put! *xdoc-inputs* elt #f))
	((xdoc-output? elt)
	 (hash-table/put! *xdoc-outputs* elt #f))))

(define (save-xdoc-id elt)
  (let ((id (id-attribute 'id elt #f)))
    (if id
	(begin
	  (if (hash-table/get *xdoc-id-map* id #f)
	      (error "ID attribute not unique:" id))
	  (hash-table/put! *xdoc-id-map* id elt)))))

(define (xdoc-db-id elt)
  (vector-ref (%xdoc-element-properties elt) 0))

(define (xdoc-element-containers elt)
  (vector-ref (%xdoc-element-properties elt) 1))

(define (xdoc-element-properties elt)
  (let ((v (%xdoc-element-properties elt)))
    (values (vector-ref v 2)
	    (vector-ref v 3)
	    (length (vector-ref v 1))
	    (vector-ref v 4))))

(define (%xdoc-element-properties elt)
  (let ((v (hash-table/get *xdoc-element-properties* elt #f)))
    (if (not v)
	(error:wrong-type-argument elt "XDOC element"
				   'xdoc-element-properties))
    v))

(define (nearest-container elt)
  (let ((containers (xdoc-element-containers elt)))
    (if (not (pair? containers))
	(error "Unable to find XDOC element container."))
    (car containers)))

(define (named-element id)
  (or (hash-table/get *xdoc-id-map* id #f)
      (error:bad-range-argument id 'named-element)))

;;;; I/O memoization

(define (memoize-xdoc-inputs)
  (for-each (lambda (elt)
	      (hash-table/put! *xdoc-inputs* elt (memoize-xdoc-input elt)))
	    (hash-table/key-list *xdoc-inputs*)))

(define (memoize-xdoc-input elt)
  (let ((id (xdoc-db-id elt)))
    (receive (value submitter) (db-previously-saved-input id)
      (if submitter
	  (cons value submitter)
	  (receive (value* submitter) (xdoc-active-input-status elt)
	    (let ((value (or value "")))
	      (if (or submitter
		      (and value* (not (string=? value* value))))
		  (db-save-input! id (or value* value) submitter))
	      (cons (or value* value) submitter)))))))

(define (memoize-xdoc-outputs)
  (for-each (lambda (elt)
	      (receive (correctness submitter) (memoize-xdoc-output elt)
		(hash-table/put! *xdoc-outputs* elt
				 (cons correctness submitter))))
	    (hash-table/key-list *xdoc-outputs*)))

(define (memoize-xdoc-output elt)
  (let ((id (xdoc-db-id elt)))
    (receive (correctness submitter) (db-previously-saved-output id)
      (if submitter
	  (values correctness submitter)
	  (receive (correctness* submitter) (xdoc-active-output-status elt)
	    (let ((correctness (or correctness "unspecified")))
	      (if (or submitter
		      (not (string=? correctness* correctness)))
		  (db-save-output! id
				   correctness*
				   submitter
				   *xdoc-late?*)))
	    (values correctness* submitter))))))

(define (current-input-status elt)
  (let ((p (%current-input-status elt)))
    (values (car p) (cdr p))))

(define (input-submitted? elt)
  (and (cdr (%current-input-status elt)) #t))

(define (%current-input-status elt)
  (or (hash-table/get *xdoc-inputs* elt #f)
      (error:wrong-type-argument elt
				 "XDOC input element"
				 'current-input-status)))

(define (current-inputs-status sources)
  (receive (value submitter) (current-input-status (car sources))
    (let loop
	((sources (cdr sources))
	 (vals (list value))
	 (submitter submitter))
      (if (pair? sources)
	  (receive (value submitter*) (current-input-status (car sources))
	    (loop (cdr sources)
		  (cons value vals)
		  (and (eq? submitter* submitter) submitter)))
	  (values (reverse! vals) submitter)))))

(define (current-output-status elt)
  (let ((p (%current-output-status elt)))
    (values (car p) (cdr p))))

(define (output-submitted? elt)
  (and (cdr (%current-output-status elt)) #t))

(define (%current-output-status elt)
  (or (hash-table/get *xdoc-outputs* elt #f)
      (error:wrong-type-argument elt
				 "XDOC output element"
				 'current-output-status)))

;;;; HTML generator

(define (generate-xdoc-html root)
  (if (not (xd:xdoc? root))
      (error "Top level element must be <xd:xdoc>:" root))
  (html (xdoc-attributes root 'xmlns xhtml-iri)
	"\n"
	(head #f
	      "\n  "
	      (style-link "/styles/xdoc.css")
	      (append-map (lambda (item)
			    (if (xd:head? item)
				(xml-element-contents item)
				'()))
			  (xml-element-contents root)))
	"\n"
	(body #f "\n" ((xdoc-html-generator root) root) "\n")
	"\n"))

(define (define-html-generator name handler)
  (hash-table/put! html-generators name handler))

(define (xdoc-html-generator item)
  (hash-table/get html-generators (xdoc-element-name item) #f))

(define html-generators
  (make-xml-name-hash-table))

(define (generate-container-items items extra-content?)
  (generate-container-groups
   (parse-container-groups items xd:answer?)
   (let ((expand-xdoc
	  (lambda (elt valid-content?)
	    (if (not (valid-content? elt))
		(error "Illegal content in this context:" elt))
	    (let ((handler (xdoc-html-generator elt)))
	      (if (not handler)
		  (error "Unhandled element type:" (xml-element-name elt)))
	      (handler elt)))))
     (lambda (items)
       (map (lambda (item)
	      (cond ((xdoc-element? item)
		     (expand-xdoc item
		       (lambda (elt)
			 (or (memq (xdoc-element-type elt)
				   '(internal-container
				     output
				     content-selector
				     action))
			     (extra-content? elt)))))
		    ((xml-element? item)
		     (generate-xdoc-in-html item
		       (lambda (elt)
			 (expand-xdoc elt
			   (lambda (elt)
			     (memq (xdoc-element-type elt)
				   '(output content-selector action)))))))
		    (else item)))
	    items)))
   generate-answer-block))

(define (generate-xdoc-in-html elt procedure)
  (let loop ((elt elt))
    (make-xml-element (xml-element-name elt)
		      (xml-element-attributes elt)
		      (flatten-xml-element-contents
		       (map (lambda (item)
			      (cond ((xdoc-element? item) (procedure item))
				    ((xml-element? item) (loop item))
				    (else item)))
			    (xml-element-contents elt))))))

(define (generate-container-groups groups generate-even generate-odd)
  (let loop ((groups groups))
    (if (pair? groups)
	(cons (generate-even (car groups))
	      (if (pair? (cdr groups))
		  (cons (generate-odd (cadr groups))
			(loop (cddr groups)))
		  '()))
	'())))

(define (parse-container-groups items container?)
  (letrec
      ((collect-non-containers
	(lambda (items group groups)
	  (if (pair? items)
	      (if (container? (car items))
		  (collect-containers (cdr items)
				      (list (car items))
				      (cons (reverse! group) groups))
		  (collect-non-containers (cdr items)
					  (cons (car items) group)
					  groups))
	      (reverse! (cons (reverse! group) groups)))))
       (collect-containers
	(lambda (items group groups)
	  (if (pair? items)
	      (cond ((container? (car items))
		     (collect-containers (cdr items)
					 (cons (car items) group)
					 groups))
		    ((spacer? (car items))
		     (skip-spacers (cdr items)
				   (list (car items))
				   group
				   groups))
		    (else
		     (collect-non-containers (cdr items)
					     (list (car items))
					     (cons (reverse! group) groups))))
	      (reverse! (cons (reverse! group) groups)))))
       (skip-spacers
	(lambda (items spacers group groups)
	  (if (pair? items)
	      (cond ((spacer? (car items))
		     (skip-spacers (cdr items)
				   (cons (car items) spacers)
				   group
				   groups))
		    ((container? (car items))
		     (collect-containers (cdr items)
					 (cons (car items)
					       (append! spacers group))
					 groups))
		    (else
		     (collect-non-containers (cdr items)
					     (cons (car items) spacers)
					     (cons (reverse! group) groups))))
	      (reverse!
	       (cons* (reverse! spacers)
		      (reverse! group)
		      groups)))))
       (spacer?
	(lambda (item)
	  (or (xml-whitespace-string? item)
	      (xml-comment? item)))))
    (collect-non-containers items '() '())))

;;;; Containers

(define-html-generator 'xdoc
  (lambda (elt)
    (int0-attribute 'problem-set elt #t)	;require attribute
    (form (attributes
	   'method "post"
	   'action (or (find-attribute 'form-url elt #f) (http-request-url)))
	  (generate-container-items (xml-element-contents elt)
				    (lambda (elt)
				      (or (xd:head? elt)
					  (xd:due-date? elt)))))))

(define-html-generator 'head
  (lambda (elt)
    elt
    '()))

(define-html-generator 'due-date
  (lambda (elt)
    (let ((dt (due-date->decoded-time elt)))
      (p (merge-attributes (xdoc-due-date-attributes dt)
			   (preserved-attributes elt))
	 (xdoc-due-date-string dt)))))

(define (due-date->decoded-time elt)
  (make-decoded-time
   0
   (or (index0-attribute 'minute 60 elt #f) 0)
   (index0-attribute 'hour 24 elt #t)
   (index1-attribute 'day 31 elt #t)
   (index1-attribute 'month 12 elt #t)
   (numeric-attribute 'year
		      (lambda (z)
			(and (exact-integer? z)
			     (>= z 1970)))
		      elt
		      #t)))

(define-expander 'xdoc-due-date-attributes
  (lambda (dt)
    (attributes 'class
		(string-append "xdoc-due-date "
			       (if (decoded-time-in-past? dt)
				   "xdoc-due-date-overdue"
				   "xdoc-due-date-on-time")))))

(define-expander 'xdoc-due-date-string
  (lambda (dt)
    (let ((hour (decoded-time/hour dt))
	  (minute (decoded-time/minute dt)))
      (string-append "Due: "
		     (day-of-week/long-string (decoded-time/day-of-week dt))
		     " "
		     (month/short-string (decoded-time/month dt))
		     ". "
		     (number->string (decoded-time/day dt))
		     " at "
		     (number->string
		      (cond ((> hour 12) (- hour 12))
			    ((> hour 0) hour)
			    (else 12)))
		     (if (> minute 0)
			 (string-append ":" (string-pad-left minute 2 #\0))
			 "")
		     " "
		     (if (> hour 12) "PM" "AM")))))

(define (due-date-in-past?)
  (let ((elt (find-named-child 'due-date *xdoc-root* #f)))
    (and elt
	 (decoded-time-in-past? (due-date->decoded-time elt)))))

(define (decoded-time-in-past? dt)
  (< (decoded-time->universal-time dt) (get-universal-time)))

(define-html-generator 'problem
  (lambda (elt)
    (receive (prefix number depth count) (xdoc-element-properties elt)
      (let ((formatter
	     (procedure-attribute 'number-format (nearest-container elt) #f))
	    (body (generate-problem-body elt)))
	(let ((class-attrs
	       (lambda (part)
		 (attributes 'class
			     (let ((base (string-append "xdoc-problem-" part)))
			       (string-append base "-" (number->string depth)
					      " " base))))))
	  (let ((label-attrs (class-attrs "label"))
		(body-attrs (class-attrs "body")))
	    (list (if (and (> count 1) (problem-separator? elt))
		      (list (hr) "\n")
		      '())
		  (if (> depth 1)
		      (case (problem-group-type (nearest-container elt))
			((dl)
			 (list (dt label-attrs
				   (if formatter
				       (formatter prefix number elt)
				       (list number ":")))
			       "\n"
			       (dd body-attrs "\n" body)))
			((ol)
			 (li (append body-attrs (attributes 'value number))
			     body))
			((ul) (li body-attrs body))
			(else (div body-attrs body)))
		      (list (p label-attrs
			       (if formatter
				   (formatter prefix number elt)
				   (list "Problem " prefix number)))
			    "\n"
			    (div body-attrs "\n" body))))))))))

(define (generate-problem-body elt)
  (let ((wrap
	 (case (problem-group-type elt)
	   ((dl) dl)
	   ((ol) ol)
	   ((ul) ul)
	   (else div)))
	(attrs (xdoc-attributes elt 'class "xdoc-problem-group"))
	(generate-group
	 (lambda (items)
	   (generate-container-items items (lambda (elt) elt #f)))))
    (generate-container-groups
     (parse-container-groups (xml-element-contents elt) xd:problem?)
     generate-group
     (lambda (items)
       (list "\n"
	     (wrap attrs "\n" (generate-group items)))))))

(define (problem-group-type elt)
  (if (find-attribute 'number-format elt #f)
      'dl
      (let ((type (or (symbol-attribute 'number-type elt #f) 'ol)))
	(if (not (memq type '(dl ol ul none)))
	    (error "Illegal number-type attribute:" type))
	type)))

(define (problem-separator? elt)
  (eq? (let ((elt (nearest-container elt)))
	 (or (boolean-attribute 'problem-separator elt #f)
	     (let ((local (xdoc-element-name elt)))
	       (case local
		 ((xdoc) 'true)
		 ((problem) 'false)
		 (else (error "Illegal <xd:problem> container:" local))))))
       'true))

(define (generate-answer-block elts)
  (fluid-let ((*answer-block-appendixes* '()))
    (let ((t
	   (table (attributes 'class "xdoc-answer-block"
			      'cellspacing "8")
		  (append-map (lambda (elt)
				(list "\n  "
				      (tr (xdoc-attributes elt)
					  (generate-answer-row elt)
					  "\n  ")
				      "\n"))
			      elts))))
      ;; Let forces order of evaluation.
      (cons t (reverse! *answer-block-appendixes*)))))

(define (append-to-answer-block . items)
  (set! *answer-block-appendixes*
	(append! *answer-block-appendixes* items))
  unspecific)

(define *answer-block-appendixes*)

(define (generate-answer-row elt)
  (append-map generate-answer-item
	      (xml-element-contents elt)))

(define (generate-answer-item elt)
  (let* ((name (xdoc-element-name elt)))
    (if (not (or (memq (xdoc-element-type elt)
		       '(input output content-selector action))
		 (xd:label? elt)))
	(error "Unknown <xd:answer> content:" elt))
    (let ((items
	   (flatten-xml-element-contents ((xdoc-html-generator elt) elt))))
      (if (null? items)
	  '()
	  (list "\n    "
		(td (xdoc-attributes elt
				     'class (symbol-append 'xdoc-answer- name))
		    "\n      "
		    items
		    "\n    "))))))

(define-html-generator 'label
  (lambda (elt)
    (xml-element-contents elt)))

;;;; Inputs

(define (define-xdoc-input local canonicalizer generator)
  (hash-table/put! xdoc-input-canonicalizers local canonicalizer)
  (define-html-generator local generator))

(define (xdoc-active-input-status elt)
  (receive (request submitter) (xdoc-active-element-request elt)
    (values (canonicalize-xdoc-input-value
	     elt
	     (http-request-post-parameter (xdoc-db-id elt))
	     request)
	    (and (eq? request 'submit) submitter))))

(define (xdoc-active-element-request elt)
  (let ((bindings (http-request-post-parameter-bindings)))
    (let per-elt ((elt elt) (containers (xdoc-element-containers elt)))
      (let* ((id (xdoc-db-id elt))
	     (suffix (string-append "-" (symbol-name id))))
	(cond ((find-matching-item bindings
		 (lambda (binding)
		   (string-suffix? suffix (symbol-name (car binding)))))
	       => (lambda (binding)
		    (values (let ((name (symbol-name (car binding))))
			      (substring->symbol
			       name
			       0
			       (fix:- (string-length name)
				      (string-length suffix))))
			    id)))
	      ((pair? containers)
	       (per-elt (car containers) (cdr containers)))
	      (else
	       (values #f #f)))))))

(define (canonicalize-xdoc-input-value elt value request)
  (let ((local (xdoc-element-name elt)))
    (if (eq? local 'checkbox)
	(if (and (not value) request) "false" value)
	(and value
	     ((or (hash-table/get xdoc-input-canonicalizers local #f)
		  (error:wrong-type-argument elt
					     "XDOC input element"
					     'canonicalize-xdoc-input-value))
	      value)))))

(define xdoc-input-canonicalizers
  (make-eq-hash-table))

(define-xdoc-input 'text
  string-trim
  (lambda (elt)
    (receive (value submitter) (current-input-status elt)
      (let ((width (int0-attribute 'width elt #t)))
	(input 'class "xdoc-text-input"
	       'type 'text
	       'size width
	       'maxlen width
	       'name (xdoc-db-id elt)
	       'value value
	       'disabled (and submitter 'disabled))))))

(define-xdoc-input 'menu
  (lambda (value) (if (string=? value menu-dummy-string) "" value))
  (lambda (elt)
    (receive (value submitter) (current-input-status elt)
      (let ((size (or (int1-attribute 'size elt #f) 1)))
	(list
	 (select (xdoc-attributes elt
				  'name (xdoc-db-id elt)
				  'size size
				  'disabled (and submitter 'disabled))
		 "\n"
		 (option #f menu-dummy-string)
		 (map (lambda (v)
			(list "\n"
			      (option (attributes 'selected (string=? v value))
				      v)))
		      (xd:menu-values elt))
		 "\n")
	 "\n")))))

(define menu-dummy-string
  "--select answer--")

(define (xd:menu-values elt)
  (map (lambda (elt)
	 (if (not (xd:menuitem? elt))
	     (error "Illegal <xd:menu> content:" elt))
	 (string-trim (xml-element-text elt)))
       (xml-element-contents elt)))

(define-xdoc-input 'checkbox
  #f ;; special, see canonicalize-xdoc-input-value
  (lambda (elt)
    (receive (value submitter) (current-input-status elt)
      (input 'class "xdoc-checkbox-input"
	     'type 'checkbox
	     'name (xdoc-db-id elt)
	     'value "true"
	     'checked (string=? value "true")
	     'disabled (and submitter 'disabled)))))

(define-xdoc-input 'radio-buttons
  identity-procedure
  (lambda (elt)
    (receive (value submitter) (current-input-status elt)
      (let ((id (xdoc-db-id elt)))
	(table
	 (attributes 'class "xdoc-radio-buttons-input")
	 (tr #f
	     (map (lambda (item)
		    (if (not (xd:radio-entry? item))
			(error "Illegal <xd:radio-buttons> content:" item))
		    (let ((value* (find-attribute 'value item #t)))
		      (list
		       (td #f
			   (input 'type 'radio
				  'name id
				  'value value*
				  'checked (string=? value* value)
				  'disabled (and submitter 'disabled)))
		       (th #f (xml-element-contents item)))))
		  (xml-element-contents elt))))))))

(define (xd:radio-button-values elt)
  (map (lambda (elt)
	 (if (not (xd:radio-entry? elt))
	     (error "Illegal <xd:radio-buttons> content:" elt))
	 (find-attribute 'value elt #t))
       (xml-element-contents elt)))

;;;; Outputs

(define (define-unary-xdoc-output local checkable? expected-value procedure)
  (hash-table/put! xdoc-output-definitions local
    (vector checkable?
	    expected-value
	    (lambda (elt)
	      (let ((source (unary-xdoc-output-source elt)))
		(receive (value submitter) (current-input-status source)
		  (values (if (string-null? value)
			      "unspecified"
			      (procedure elt value source))
			  submitter))))))
  (define-html-generator local (lambda (elt) elt '())))

(define (unary-xdoc-output-source elt)
  (or (idref-attribute 'source elt #f)
      (find-child (nearest-container elt) #t xdoc-input?)))

(define (define-n-ary-xdoc-output local checkable? expected-value procedure)
  (hash-table/put! xdoc-output-definitions local
    (vector checkable?
	    expected-value
	    (lambda (elt)
	      (let ((sources
		     (map named-element (ids-attribute 'sources elt #t))))
		(if (not (pair? sources))
		    (error
		     "Multiple-input test needs at least one input."))
		(receive (vals submitter) (current-inputs-status sources)
		  (values (if (there-exists? vals string-null?)
			      "unspecified"
			      (procedure elt vals sources))
			  submitter))))))
  (define-html-generator local (lambda (elt) elt '())))

(define (xdoc-output-checkable? elt)
  (and (vector-ref (%xdoc-output-definition elt) 0)
       (let ((b (boolean-attribute 'checkable elt #f)))
	 (if b
	     (eq? b 'true)
	     #t))))

(define (xdoc-output-expected-value elt)
  ((vector-ref (%xdoc-output-definition elt) 1) elt))

(define (xdoc-active-output-status elt)
  (receive (correctness submitter)
      ((vector-ref (%xdoc-output-definition elt) 2) elt)
    (if (not (string? correctness))
	(error "Illegal result from output procedure:" correctness))
    (values correctness submitter)))

(define (%xdoc-output-definition elt)
  (or (hash-table/get xdoc-output-definitions (xdoc-element-name elt) #f)
      (error:bad-range-argument elt 'xdoc-output-definition)))

(define xdoc-output-definitions
  (make-eq-hash-table))

(define-unary-xdoc-output 'check-input #t
  (lambda (elt)
    (find-attribute 'expected elt #f))
  (lambda (elt value source)
    ((procedure-attribute 'name elt #t) elt value source)))

(define-n-ary-xdoc-output 'check-inputs #t
  (lambda (elt)
    (find-attribute 'expected elt #f))
  (lambda (elt vals sources)
    ((procedure-attribute 'name elt #t) elt vals sources)))

(define-unary-xdoc-output 'number #t
  (lambda (elt)
    (complex-attribute 'expected elt #t))
  (lambda (elt value source)
    source
    (let ((expected (complex-attribute 'expected elt #t))
	  (tolerance (or (complex-attribute 'tolerance elt #f) 0))
	  (z (string->number value)))
      (if z
	  (if (close-enough? z expected tolerance)
	      "correct"
	      "incorrect")
	  "malformed"))))

(define close-enough?
  (let ((machine-epsilon
	 (let loop ((e 1.))
	   (if (> (+ e 1) 1)
	       (loop (/ e 2))
	       (* 2 e)))))
    (lambda (z expected tolerance)
      (if (= tolerance 0)
	  (= z expected)
	  (<= (magnitude (- z expected))
	      (/ (* (max tolerance machine-epsilon)
		    (+ (magnitude z)
		       (magnitude tolerance)
		       2))
		 2))))))

(define-unary-xdoc-output 'boolean #f
  (lambda (elt)
    (boolean-attribute 'expected elt #t))
  (lambda (elt value source)
    source
    (let ((expected (boolean-attribute 'expected elt #t)))
      (if (or (string=? value "true") (string=? value "false"))
	  (if (string=? value (symbol-name expected))
	      "correct"
	      "incorrect")
	  "malformed"))))

(let ((get-vals
       (lambda (source)
	 (cond ((xd:menu? source) (xd:menu-values source))
	       ((xd:radio-buttons? source) (xd:radio-button-values source))
	       (else (error "Illegal <xd:menuindex> source:" source)))))
      (get-expected
       (lambda (elt vals)
	 (list-ref vals
		   (- (index1-attribute 'expected (length vals) elt #t)
		      1)))))
  (define-unary-xdoc-output 'menuindex #f
    (lambda (elt)
      (get-expected elt (get-vals (unary-xdoc-output-source elt))))
    (lambda (elt value source)
      (let ((vals (get-vals source)))
	(if (member value vals)
	    (if (string=? value (get-expected elt vals))
		"correct"
		"incorrect")
	    "malformed")))))

;;;; Content selectors

(define-html-generator 'explain
  (lambda (elt)
    (if (descendant-outputs-submitted? (content-selector-source elt))
	(switched-content-selector elt "explanation")
	'())))

(define-html-generator 'hint
  (lambda (elt)
    (if (descendant-outputs-submitted? (content-selector-source elt))
	'()
	(switched-content-selector elt "hint"))))

(define (switched-content-selector elt noun)
  (let* ((type (xdoc-element-name elt))
	 (name (symbol-append type '- (xdoc-db-id elt)))
	 (value (db-get-persistent-value name #f)))
    (if (if (eq? value 'shown)
	    (not (http-request-post-parameter name))
	    (http-request-post-parameter name))
	(let ((text
	       (list
		"\n"
		(blockquote
		 (xdoc-attributes elt
				  'class
				  (string-append "xdoc-"
						 (symbol-name type)
						 "-blockquote"))
		 (xml-element-contents elt))
		"\n"))
	      (button
	       (input 'type 'submit
		      'name name
		      'value (string-append "Hide " noun))))
	  (if (not (eq? value 'shown))
	      (db-set-persistent-value! name 'shown))
	  (if (xd:answer? (nearest-container elt))
	      (begin
		(append-to-answer-block text)
		button)
	      (list button text)))
	(begin
	  (if (not (eq? value 'hidden))
	      (db-set-persistent-value! name 'hidden))
	  (input 'type 'submit
		 'name name
		 'value (string-append "Show " noun))))))

(define-html-generator 'expected-value
  (lambda (elt)
    (let ((source
	   (let ((source (content-selector-source elt)))
	     (let ((outputs (descendant-outputs source)))
	       (if (not (and (pair? outputs) (null? (cdr outputs))))
		   (error "Single source output required:" outputs))
	       (car outputs)))))
      (and (output-submitted? source)
	   (div (xdoc-attributes elt)
		(xdoc-output-expected-value source))))))

(define-html-generator 'when
  (lambda (elt)
    (and ((let ((condition (symbol-attribute 'condition elt #t)))
	    (or (hash-table/get when-conditions condition #f)
		(error "Unknown <xd:when> condition:" condition)))
	  (content-selector-source elt))
	 (div (xdoc-attributes elt)
	      (xml-element-contents elt)))))

(define (define-when-condition name procedure)
  (hash-table/put! when-conditions name procedure))

(define when-conditions
  (make-eq-hash-table))

(define-when-condition 'submitted
  (lambda (elt)
    (descendant-outputs-submitted? elt)))

(define-when-condition 'not-submitted
  (lambda (elt)
    (not (descendant-outputs-submitted? elt))))

(define-html-generator 'case
  (lambda (elt)
    (let ((children (xml-element-contents elt)))
      (let ((token
	     (let ((source
		    (let ((source (car children)))
		      (if (xd:refer? source)
			  (idref-attribute 'source source #t)
			  source))))
	       (if (not (xdoc-output? source))
		   (error "First child of <xd:case> must be output:" source))
	       (receive (correctness submitter) (current-output-status source)
		 (if (or submitter (xdoc-output-checkable? source))
		     correctness
		     "not-checkable")))))
	(let loop ((choices (cdr children)))
	  (if (pair? choices)
	      (let ((choice (car choices)))
		(if (cond ((xd:choice? choice)
			   (there-exists?
			       (attribute-value->list
				(find-attribute 'values choice #t))
			     (lambda (token*)
			       (string=? token* token))))
			  ((xd:default? choice)
			   (if (not (null? (cdr choices)))
			       (error "<xd:default> must be last child:"
				      choices))
			   #t)
			  (else
			   (error "Illegal <xd:case> child:" choice)))
		    (xml-element-contents choice)
		    (loop (cdr choices))))
	      '()))))))

(define (content-selector-source elt)
  (let ((source (idref-attribute 'source elt #f)))
    (if source
	(begin
	  (if (not (or (xdoc-container? source) (xdoc-output? source)))
	      (error "Source must be container or output:" source))
	  source)
	(nearest-container elt))))

(define (descendant-outputs-submitted? elt)
  (for-all? (descendant-outputs elt) output-submitted?))

(define (descendant-outputs elt)
  (matching-descendants-or-self elt xdoc-output?))

;;;; Actions

(define-html-generator 'check-action
  (lambda (elt)
    (submission-action elt 'check)))

(define-html-generator 'submit-action
  (lambda (elt)
    (submission-action elt 'submit)))

(define (submission-action elt prefix)
  (let ((container
	 (let ((container (idref-attribute 'scope elt #f)))
	   (if container
	       (begin
		 (if (not (xdoc-container? container))
		     (error "scope attribute must refer to container:"
			    container))
		 container)
	       (nearest-container elt)))))
    (let ((inputs (descendant-inputs container)))
      (if (for-all? inputs input-submitted?)
	  #f
	  (input
	   (xdoc-attributes
	    elt
	    'class "xdoc-submit-action"
	    'type 'submit
	    'name (symbol-append prefix '- (xdoc-db-id container))
	    'value
	    (string-append (string-capitalize (symbol-name prefix))
			   " answer"
			   (if (fix:= (length inputs) 1) "" "s"))))))))

(define (descendant-inputs elt)
  (matching-descendants-or-self elt xdoc-input?))

;;;; Attribute accessors

(define (find-attribute name elt error?)
  (let ((attr (%find-attribute name (xml-element-attributes elt))))
    (if attr
	(xml-attribute-value attr)
	(begin
	  (if error?
	      (error "Missing required XDOC attribute:" name elt))
	  #f))))

(define (%find-attribute name attrs)
  (find-matching-item attrs
    (lambda (attr)
      (xml-name=? (xml-attribute-name attr) name))))

(define (symbol-attribute name elt error?)
  (let ((string (find-attribute name elt error?)))
    (and string
	 (string->symbol string))))

(define (id-attribute name elt error?)
  (let ((string (find-attribute name elt error?)))
    (and string
	 (make-xml-qname string))))

(define (idref-attribute name elt error?)
  (let ((id (id-attribute name elt error?)))
    (and id
	 (named-element id))))

(define (ids-attribute name elt error?)
  (let ((string (find-attribute name elt error?)))
    (and string
	 (map make-xml-qname (attribute-value->list string)))))

(define (nmtokens-attribute name elt error?)
  (let ((string (find-attribute name elt error?)))
    (and string
	 (map make-xml-nmtoken (attribute-value->list string)))))

(define (attribute-value->list names)
  (burst-string names char-set:whitespace #t))

(define (boolean-attribute name elt error?)
  (let ((value (symbol-attribute name elt error?)))
    (if (and value (not (memq value '(true false))))
	(error "Ill-formed boolean attribute:" value))
    value))

(define (numeric-attribute name predicate elt error?)
  (let ((string (find-attribute name elt error?)))
    (and string
	 (let ((z (string->number string)))
	   (if (not (and z (predicate z)))
	       (error "Ill-formed number:" z))
	   z))))

(define (int0-attribute name elt error?)
  (numeric-attribute name exact-nonnegative-integer? elt error?))

(define (int1-attribute name elt error?)
  (numeric-attribute name exact-positive-integer? elt error?))

(define (complex-attribute name elt error?)
  (numeric-attribute name complex? elt error?))

(define (index0-attribute name limit elt error?)
  (numeric-attribute name
		     (lambda (z)
		       (and (exact-nonnegative-integer? z)
			    (< z limit)))
		     elt
		     error?))

(define (index1-attribute name limit elt error?)
  (numeric-attribute name
		     (lambda (z)
		       (and (exact-positive-integer? z)
			    (<= z limit)))
		     elt
		     error?))

(define (procedure-attribute name elt error?)
  (let ((name (procedure-name-attribute name elt error?)))
    (and name
	 (environment-lookup *xdoc-environment* name))))

(define (procedure-name-attribute name elt error?)
  (let ((symbol (symbol-attribute name elt error?)))
    (if (not (or (not symbol) (xdoc-procedure-name? symbol)))
	(error "Malformed procedure attribute:" symbol))
    symbol))

(define (xdoc-procedure-name? symbol)
  (re-string-match "[A-Za-z_][0-9A-Za-z_]*" (symbol-name symbol)))

;;;; Merging of attributes

(define (xdoc-attributes elt . keyword-list)
  (merge-attributes (apply attributes keyword-list)
		    (preserved-attributes elt)))

(define (preserved-attributes elt)
  (keep-matching-items (xml-element-attributes elt) preserved-attribute?))

(define (merge-attributes attrs defaults)
  (map* (delete-matching-items defaults
	  (lambda (attr)
	    (%find-attribute (xml-attribute-name attr) attrs)))
	(lambda (attr)
	  (let ((attr*
		 (and (merged-attribute? attr)
		      (%find-attribute (xml-attribute-name attr) defaults))))
	    (if attr*
		(merge-attribute attr attr*)
		attr)))
	attrs))

(define (preserved-attribute? attr)
  (let ((name (xml-attribute-name attr)))
    (or (xml-name=? name 'class)
	(xml-name=? name 'style)
	(and (xml-name-prefix=? name 'xmlns)
	     (not (string=? (xml-attribute-value attr)
			    (xml-namespace-iri-string xdoc-iri)))))))

(define (merged-attribute? attr)
  (let ((name (xml-attribute-name attr)))
    (xml-name=? name 'class)))

(define (merge-attribute attr1 attr2)
  (let ((name (xml-attribute-name attr1)))
    (cond ((xml-name=? name 'class)
	   (make-xml-attribute name
			       (class-union (xml-attribute-value attr1)
					    (xml-attribute-value attr2))))
	  (else
	   (error:bad-range-argument attr1 'MERGE-ATTRIBUTE)))))

(define (class-union c1 c2)
  (let ((classes
	 (let ((c2 (attribute-value->list c2)))
	   (let loop ((c1 (attribute-value->list c1)))
	     (if (pair? c1)
		 (if (member (car c1) c2)
		     (loop (cdr c1))
		     (cons (car c1) (loop (cdr c1))))
		 c2)))))
    (if (pair? classes)
	(call-with-output-string
	  (lambda (port)
	    (write-string (car classes) port)
	    (for-each (lambda (class)
			(write-char #\space port)
			(write-string class port))
		      (cdr classes))))
	"")))

;;;; Element accessors

(define (find-named-child local elt error?)
  (find-child elt error?
    (lambda (child)
      (xdoc-element-name=? child local))))

(define (find-child elt error? predicate)
  (%find-result (%find-child elt predicate) error?))

(define (%find-child elt predicate)
  (find-matching-item (xml-element-contents elt)
    (lambda (item)
      (and (xml-element? item)
	   (predicate item)))))

(define (%find-result elt error?)
  (if (and (not elt) error?)
      (error "Unable to find matching element."))
  elt)

(define (xml-element-text elt)
  (let loop ((items (xml-element-contents elt)) (text ""))
    (if (pair? items)
	(begin
	  (if (not (string? (car items)))
	      (error "Illegal text component:" (car items)))
	  (loop (cdr items)
		(string-append text (car items))))
	text)))

(define (find-named-descendant local elt error?)
  (find-descendant elt error?
    (lambda (elt)
      (xdoc-element-name=? elt local))))

(define (find-descendant elt error? predicate)
  (%find-result (%find-descendant elt predicate) error?))

(define (find-descendant-or-self elt error? predicate)
  (%find-result (%find-descendant-or-self elt predicate) error?))

(define (matching-descendants elt predicate)
  (reverse! (%matching-descendants elt predicate '())))

(define (matching-descendants-or-self elt predicate)
  (reverse! (%matching-descendants-or-self elt predicate '())))

(define (%find-descendant elt predicate)
  (let loop ((items (xml-element-contents elt)))
    (and (pair? items)
	 (or (and (xml-element? (car items))
		  (%find-descendant-or-self (car items) predicate))
	     (loop (cdr items))))))

(define (%find-descendant-or-self elt predicate)
  (if (predicate elt)
      elt
      (%find-descendant elt predicate)))

(define (%matching-descendants elt predicate matches)
  (let loop ((items (xml-element-contents elt)) (matches matches))
    (if (pair? items)
	(loop (cdr items)
	      (let ((item (car items)))
		(if (xml-element? item)
		    (%matching-descendants-or-self item predicate matches)
		    matches)))
	matches)))

(define (%matching-descendants-or-self elt predicate matches)
  (%matching-descendants elt
			 predicate
			 (if (predicate elt)
			     (cons elt matches)
			     matches)))

;;;; XDOC element data types

(define xdoc-iri
  (make-xml-namespace-iri "http://mit.edu/2003/XDOC"))

(define (xdoc-name? name)
  (xml-name-iri=? name xdoc-iri))

(define (xdoc-name=? name local)
  (and (xdoc-name? name)
       (xml-name-local=? name local)))

(define (xdoc-element? item)
  (and (xml-element? item)
       (xdoc-name? (xml-element-name item))))

(define (xdoc-element-name item)
  (and (xml-element? item)
       (let ((name (xml-element-name item)))
	 (and (xdoc-name? name)
	      (xml-name-local name)))))

(define (xdoc-element-name=? item local)
  (and (xml-element? item)
       (xdoc-name=? (xml-element-name item) local)))

(define (xdoc-content-type elt)
  (let ((local (xdoc-element-name elt)))
    (and local
	 (or (hash-table/get xdoc-content-types local #f)
	     (error "Unknown XDOC element name:" local)))))

(define xdoc-content-types
  (make-eq-hash-table))

(define (xdoc-element-type elt)
  (let ((local (xdoc-element-name elt)))
    (and local
	 (or (hash-table/get xdoc-element-types local #f)
	     (error "Unknown XDOC element name:" local)))))

(define xdoc-element-types
  (make-eq-hash-table))

(define (xdoc-container? elt)
  (let ((type (xdoc-element-type elt)))
    (or (eq? type 'top-level-container)
	(eq? type 'internal-container))))

(define (xdoc-internal-container? elt)
  (eq? (xdoc-element-type elt) 'internal-container))

(define (xdoc-input? elt)
  (eq? (xdoc-element-type elt) 'input))

(define (xdoc-output? elt)
  (eq? (xdoc-element-type elt) 'output))

(define (xdoc-content-selector? elt)
  (eq? (xdoc-element-type elt) 'content-selector))

(define (xdoc-action? elt)
  (eq? (xdoc-element-type elt) 'action))

(let ((define-element
	(lambda (local content-type elt-type)
	  (let ((qname (symbol-append 'xd: local)))
	    (define-expander qname
	      ((if (eq? content-type 'empty)
		   empty-element-constructor
		   standard-element-constructor)
	       qname xdoc-iri))
	    (define-expander (symbol-append qname '?)
	      (let ((name (make-xml-name qname xdoc-iri)))
		(lambda (object)
		  (and (xml-element? object)
		       (xml-name=? (xml-element-name object) name))))))
	  (hash-table/put! xdoc-content-types local content-type)
	  (hash-table/put! xdoc-element-types local elt-type))))
  (define-element 'xdoc 'mixed 'top-level-container)
  (define-element 'head 'mixed 'internal)
  (define-element 'due-date 'empty 'internal)
  (define-element 'problem 'mixed 'internal-container)
  (define-element 'answer 'element 'internal-container)
  (define-element 'label 'mixed 'internal)

  (define-element 'text 'empty 'input)
  (define-element 'menu 'element 'input)
  (define-element 'menuitem 'text 'internal)
  (define-element 'checkbox 'empty 'input)
  (define-element 'radio-buttons 'element 'input)
  (define-element 'radio-entry 'mixed 'internal)

  (define-element 'check-input 'empty 'output)
  (define-element 'check-inputs 'empty 'output)
  (define-element 'number 'empty 'output)
  (define-element 'boolean 'empty 'output)
  (define-element 'menuindex 'empty 'output)

  (define-element 'explain 'mixed 'content-selector)
  (define-element 'hint 'mixed 'content-selector)
  (define-element 'expected-value 'empty 'content-selector)
  (define-element 'when 'mixed 'content-selector)
  (define-element 'case 'element 'content-selector)
  (define-element 'refer 'empty 'internal)
  (define-element 'choice 'mixed 'internal)
  (define-element 'default 'mixed 'internal)

  (define-element 'check-action 'empty 'action)
  (define-element 'submit-action 'empty 'action))

(define-expander 'xd:true-false
  (lambda keyword-list
    (xd:radio-buttons (apply attributes keyword-list)
		      (xd:radio-entry (attributes 'value 'true) "True")
		      (xd:radio-entry (attributes 'value 'false) "False"))))

(define-expander 'xd:true-false?
  (lambda (object)
    (and (xd:radio-buttons? object)
	 (let ((entries (xml-element-contents object)))
	   (and (fix:= (length entries) 2)
		(let ((v1 (find-attribute 'value (car entries) #t))
		      (v2 (find-attribute 'value (cadr entries) #t)))
		  (or (and (string=? v1 "true") (string=? v2 "false"))
		      (and (string=? v1 "false") (string=? v2 "true")))))))))