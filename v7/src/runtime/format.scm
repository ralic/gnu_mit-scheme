#| -*-Scheme-*-

$Header: /Users/cph/tmp/foo/mit-scheme/mit-scheme/v7/src/runtime/format.scm,v 14.1 1988/07/07 15:13:22 cph Exp $

Copyright (c) 1988 Massachusetts Institute of Technology

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

;;;; Output Formatter
;;; package: (runtime format)

(declare (usual-integrations))

;;; Please don't believe this implementation!  I don't like either the
;;; calling interface or the control string syntax, but I need the
;;; functionality pretty badly and I don't have the time to think
;;; about all of that right now -- CPH.

;;; (format port format-string argument ...)
;;;
;;; Format strings are normally interpreted literally, except that
;;; certain escape sequences allow insertion of computed values.  The
;;; following escape sequences are recognized:
;;;
;;; ~n% inserts n newlines
;;; ~n~ inserts n tildes
;;;
;;; ~<c> inserts the next argument.
;;; ~n<c> pads the argument on the left to size n.
;;; ~n@<c> pads the argument on the right to size n.
;;;
;;; where <c> may be:
;;; A meaning the argument is printed using `display'.
;;; S meaning the argument is printed using `write'.

;;;; Top Level

(define (format destination format-string . arguments)
  (if (not (string? format-string))
      (error "FORMAT: illegal format string" format-string))
  (let ((start
	 (lambda (port)
	   (format-loop port format-string arguments)
	   ((output-port/flush-output port) port)
	   *the-non-printing-object*)))
    (cond ((not destination)
	   (with-output-to-string (lambda () (start (current-output-port)))))
	  ((eq? destination true)
	   (start (current-output-port)))
	  ((output-port? destination)
	   (start destination))
	  (else
	   (error "FORMAT: illegal destination" destination)))))

(define-integrable (*unparse-char port char)
  ((output-port/write-char port) port char))

(define-integrable (*unparse-string port string)
  ((output-port/write-string port) port string))

(define (format-loop port string arguments)
  (let ((index (string-find-next-char string #\~)))
    (cond (index
	   (if (not (zero? index))
	       (*unparse-string port (substring string 0 index)))
	   (parse-dispatch port
			   (string-tail string (1+ index))
			   arguments
			   '()
			   '()))
	  ((null? arguments)
	   (*unparse-string port string))
	  (else
	   (error "Too many arguments" 'FORMAT arguments)))))

(define (parse-dispatch port string supplied-arguments parsed-arguments
			modifiers)
  ((vector-ref format-dispatch-table (vector-8b-ref string 0))
   port
   string
   supplied-arguments
   parsed-arguments
   modifiers))

(define format-dispatch-table)

(define (parse-default port string supplied-arguments parsed-arguments
		       modifiers)
  (error "FORMAT: Unknown formatting character" (string-ref string 0)))

;;;; Argument Parsing

(define ((format-wrapper operator)
	 port string supplied-arguments parsed-arguments modifiers)
  ((apply operator modifiers (reverse! parsed-arguments))
   port
   (string-tail string 1)
   supplied-arguments))

(define ((parse-modifier keyword)
	 port string supplied-arguments parsed-arguments modifiers)
  (parse-dispatch port
		  (string-tail string 1)
		  supplied-arguments
		  parsed-arguments
		  (cons keyword modifiers)))

(define (parse-digit port string supplied-arguments parsed-arguments modifiers)
  (let accumulate ((acc (char->digit (string-ref string 0) 10)) (i 1))
    (if (char-numeric? (string-ref string i))
	(accumulate (+ (* acc 10) (char->digit (string-ref string i) 10))
		    (1+ i))
	(parse-dispatch port
			(string-tail string i)
			supplied-arguments
			(cons acc parsed-arguments)
			modifiers))))

(define (parse-ignore port string supplied-arguments parsed-arguments
		      modifiers)
  (parse-dispatch port (string-tail string 1) supplied-arguments
		  parsed-arguments modifiers))

(define (parse-arity port string supplied-arguments parsed-arguments modifiers)
  (parse-dispatch port
		  (string-tail string 1)
		  supplied-arguments
		  (cons (length supplied-arguments) parsed-arguments)
		  modifiers))

(define (parse-argument port string supplied-arguments parsed-arguments
			modifiers)
  (parse-dispatch port
		  (string-tail string 1)
		  (cdr supplied-arguments)
		  (cons (car supplied-arguments) parsed-arguments)
		  modifiers))

;;;; Formatters

(define (((format-insert-character character) modifiers #!optional n)
	 port string arguments)
  (if (default-object? n)
      (*unparse-char port character)
      (let loop ((i 0))
	(if (not (= i n))
	    (begin (*unparse-char port character)
		   (loop (1+ i))))))
  (format-loop port string arguments))

(define ((format-ignore-comment modifiers) port string arguments)
  (format-loop port
	       (substring string
			  (1+ (string-find-next-char string #\Newline))
			  (string-length string))
	       arguments))

(define ((format-ignore-whitespace modifiers) port string arguments)
  (format-loop port
	       (cond ((null? modifiers) (eliminate-whitespace string))
		     ((memq 'AT modifiers)
		      (string-append "\n" (eliminate-whitespace string)))
		     (else string))
	       arguments))

(define (eliminate-whitespace string)
  (let ((limit (string-length string)))
    (let loop ((n 0))
      (cond ((= n limit) "")
	    ((let ((char (string-ref string n)))
	       (and (char-whitespace? char)
		    (not (char=? char #\Newline))))
	     (loop (1+ n)))
	    (else
	     (substring string n limit))))))

(define (((format-object write) modifiers #!optional n-columns)
	 port string arguments)
  (if (null? arguments)
      (error "FORMAT: too few arguments" string))
  (if (default-object? n-columns)
      (write (car arguments) port)
      (*unparse-string port
		       ((if (memq 'AT modifiers)
			    string-pad-left
			    string-pad-right)
			(with-output-to-string
			  (lambda ()
			    (write (car arguments))))
			n-columns)))
  (format-loop port string (cdr arguments)))

;;;; Dispatcher Setup

(define (initialize-package!)
  (set! format-dispatch-table
	(let ((table (make-vector 256 parse-default)))
	  (for-each (lambda (entry)
		      (vector-set! table
				   (char->ascii (car entry))
				   (cadr entry)))
		    (let ((format-string
			   (format-wrapper (format-object display)))
			  (format-object
			   (format-wrapper (format-object write))))
		      `((#\0 ,parse-digit)
			(#\1 ,parse-digit)
			(#\2 ,parse-digit)
			(#\3 ,parse-digit)
			(#\4 ,parse-digit)
			(#\5 ,parse-digit)
			(#\6 ,parse-digit)
			(#\7 ,parse-digit)
			(#\8 ,parse-digit)
			(#\9 ,parse-digit)
			(#\, ,parse-ignore)
			(#\# ,parse-arity)
			(#\V ,parse-argument)
			(#\v ,parse-argument)
			(#\@ ,(parse-modifier 'AT))
			(#\: ,(parse-modifier 'COLON))
			(#\%
			 ,(format-wrapper (format-insert-character #\Newline)))
			(#\~ ,(format-wrapper (format-insert-character #\~)))
			(#\; ,(format-wrapper format-ignore-comment))
			(#\Newline ,(format-wrapper format-ignore-whitespace))
			(#\A ,format-string)
			(#\a ,format-string)
			(#\S ,format-object)
			(#\s ,format-object))))
	  table)))