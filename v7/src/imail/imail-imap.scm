;;; -*-Scheme-*-
;;;
;;; $Id: imail-imap.scm,v 1.81 2000/05/23 04:23:05 cph Exp $
;;;
;;; Copyright (c) 1999-2000 Massachusetts Institute of Technology
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

;;;; IMAIL mail reader: IMAP back end

(declare (usual-integrations))

;;;; URL

(define-class <imap-url> (<url>)
  ;; User name to connect as.
  (user-id define accessor)
  ;; Name or IP address of host to connect to.
  (host define accessor)
  ;; Port number to connect to.
  (port define accessor)
  ;; Name of mailbox to access.
  (mailbox define accessor))

(define-url-protocol "imap" <imap-url>)

(define make-imap-url
  (let ((constructor
	 (instance-constructor <imap-url> '(USER-ID HOST PORT MAILBOX))))
    (lambda (user-id host port mailbox)
      (intern-url (constructor user-id
			       (string-downcase host)
			       port
			       (canonicalize-imap-mailbox mailbox))))))

(define (make-imap-url-string user-id host port mailbox)
  (string-append "//"
		 (url:encode-string user-id)
		 "@"
		 (string-downcase host)
		 (if (= port 143)
		     ""
		     (string-append ":" (number->string port)))
		 (if mailbox
		     (string-append
		      "/"
		      (url:encode-string (canonicalize-imap-mailbox mailbox)))
		     "")))

(define (canonicalize-imap-mailbox mailbox)
  (cond ((string-ci=? mailbox "inbox") "inbox")
	((and (string-prefix-ci? "inbox." mailbox)
	      (not (string-prefix? "inbox." mailbox)))
	 (let ((mailbox (string-copy mailbox)))
	   (substring-downcase! mailbox 0 6)
	   mailbox))
	(else mailbox)))

(define-method url-body ((url <imap-url>))
  (make-imap-url-string (imap-url-user-id url)
			(imap-url-host url)
			(imap-url-port url)
			(imap-url-mailbox url)))

(define-method url-presentation-name ((url <imap-url>))
  (imap-url-mailbox url))

(define-method url-body-container-string ((url <imap-url>))
  (make-imap-url-string (imap-url-user-id url)
			(imap-url-host url)
			(imap-url-port url)
			""))

(define-method url-exists? ((url <imap-url>))
  url
  #t)

(define (compatible-imap-urls? url1 url2)
  ;; Can URL1 and URL2 both be accessed from the same IMAP session?
  ;; E.g. can the IMAP COPY command work between them?
  (and (string=? (imap-url-user-id url1) (imap-url-user-id url2))
       (string=? (imap-url-host url1) (imap-url-host url2))
       (= (imap-url-port url1) (imap-url-port url2))))

(define-method url-pass-phrase-key ((url <imap-url>))
  (make-url-string "imap"
		   (make-imap-url-string (imap-url-user-id url)
					 (imap-url-host url)
					 (imap-url-port url)
					 #f)))

(define-method parse-url-body (string default-url)
  (call-with-values (lambda () (parse-imap-url-body string default-url))
    (lambda (user-id host port mailbox)
      (if user-id
	  (make-imap-url user-id host port mailbox)
	  (error:bad-range-argument string 'PARSE-URL-BODY)))))

(define parse-imap-url-body
  (let ((parser
	 (let ((//server
		(sequence-parser (noise-parser (string-matcher "//"))
				 (imap:server-parser #f)))
	       (/mbox
		(sequence-parser (noise-parser (string-matcher "/"))
				 (optional-parser imap:parse:enc-mailbox))))
	   (alternatives-parser
	    (sequence-parser //server (optional-parser /mbox))
	    /mbox
	    imap:parse:enc-mailbox))))
    (lambda (string default-url)
      (let ((pv (parse-string parser string)))
	(if pv
	    (values (or (parser-token pv 'USER-ID)
			(imap-url-user-id default-url))
		    (or (parser-token pv 'HOST)
			(imap-url-host default-url))
		    (cond ((parser-token pv 'PORT) => string->number)
			  ((parser-token pv 'HOST) 143)
			  (else (imap-url-port default-url)))
		    (or (parser-token pv 'MAILBOX)
			(imap-url-mailbox default-url)))
	    (values #f #f #f #f))))))

(define-method %url-complete-string
    ((string <string>) (default-url <imap-url>)
		       if-unique if-not-unique if-not-found)
  (call-with-values (lambda () (imap-completion-args string default-url))
    (lambda (mailbox url)
      (if mailbox
	  (let ((convert
		 (lambda (mailbox)
		   (make-imap-url-string (imap-url-user-id url)
					 (imap-url-host url)
					 (imap-url-port url)
					 mailbox))))
	    (complete-imap-mailbox mailbox url
	      (lambda (mailbox)
		(if-unique (convert mailbox)))
	      (lambda (prefix get-mailboxes)
		(if-not-unique (convert prefix)
			       (lambda () (map convert (get-mailboxes)))))
	      if-not-found))
	  (if-not-found)))))

(define-method %url-string-completions
    ((string <string>) (default-url <imap-url>))
  (call-with-values (lambda () (imap-completion-args string default-url))
    (lambda (mailbox url)
      (if mailbox
	  (map (lambda (mailbox)
		 (make-imap-url-string (imap-url-user-id url)
				       (imap-url-host url)
				       (imap-url-port url)
				       mailbox))
	       (imap-mailbox-completions mailbox url))
	  '()))))

(define (imap-completion-args string default-url)
  (if (string-null? string)
      (values string default-url)
      (call-with-values (lambda () (parse-imap-url-body string default-url))
	(lambda (user-id host port mailbox)
	  (if user-id
	      (values mailbox (make-imap-url user-id host port "inbox"))
	      (values #f #f))))))

(define (complete-imap-mailbox mailbox url
			       if-unique if-not-unique if-not-found)
  (if (string-null? mailbox)
      (if-not-unique mailbox
		     (lambda () (imap-mailbox-completions mailbox url)))
      (let ((responses (imap-mailbox-completions mailbox url)))
	(cond ((not (pair? responses))
	       (if-not-found))
	      ((pair? (cdr responses))
	       (if-not-unique (string-greatest-common-prefix responses)
			      (lambda () responses)))
	      (else
	       (if-unique (car responses)))))))

(define (imap-mailbox-completions mailbox url)
  (map imap:response:list-mailbox
       (with-open-imap-connection url
	 (lambda (connection)
	   (imap:command:list connection "" (string-append mailbox "*"))))))

;;;; Server connection

(define-class (<imap-connection> (constructor (url))) ()
  (url             define accessor)
  (port            define standard initial-value #f)
  (greeting        define standard initial-value #f)
  (sequence-number define standard initial-value 0)
  (response-queue  define accessor initializer (lambda () (cons '() '())))
  (folder          define standard initial-value #f)
  (reference-count define standard initial-value 0))

(define-method write-instance ((connection <imap-connection>) port)
  (write-instance-helper 'IMAP-CONNECTION connection port
    (lambda ()
      (write-char #\space port)
      (write (url-body (imap-connection-url connection)) port))))

(define (reset-imap-connection connection)
  (without-interrupts
   (lambda ()
     (set-imap-connection-sequence-number! connection 0)
     (let ((queue (imap-connection-response-queue connection)))
       (set-car! queue '())
       (set-cdr! queue '()))
     (set-imap-connection-folder! connection #f))))

(define (next-imap-command-tag connection)
  (let ((n (imap-connection-sequence-number connection)))
    (set-imap-connection-sequence-number! connection (+ n 1))
    (nonnegative-integer->base26-string n 3)))

(define (nonnegative-integer->base26-string n min-length)
  (let ((s
	 (make-string (max (ceiling->exact (/ (log (+ n 1)) (log 26)))
			   min-length)
		      #\A)))
    (let loop ((n n) (i (fix:- (string-length s) 1)))
      (let ((q.r (integer-divide n 26)))
	(string-set! s i (string-ref "ABCDEFGHIJKLMNOPQRSTUVWXYZ" (cdr q.r)))
	(if (not (= (car q.r) 0))
	    (loop (car q.r) (fix:- i 1)))))
    s))

(define (base26-string->nonnegative-integer s)
  (let ((end (string-length s)))
    (let loop ((start 0) (n 0))
      (if (fix:< start end)
	  (let ((digit (- (vector-8b-ref s start) (char->integer #\A))))
	    (if (not (<= 0 digit 25))
		(error:bad-range-argument s
					  'BASE26-STRING->NONNEGATIVE-INTEGER))
	    (loop (fix:+ start 1) (+ (* n 26) digit)))
	  n))))

(define (enqueue-imap-response connection response)
  (let ((queue (imap-connection-response-queue connection)))
    (let ((next (cons response '())))
      (without-interrupts
       (lambda ()
	 (if (pair? (cdr queue))
	     (set-cdr! (cdr queue) next)
	     (set-car! queue next))
	 (set-cdr! queue next))))))

(define (dequeue-imap-responses connection)
  (let ((queue (imap-connection-response-queue connection)))
    (without-interrupts
     (lambda ()
       (let ((responses (car queue)))
	 (set-car! queue '())
	 (set-cdr! queue '())
	 responses)))))

(define (get-imap-connection url for-folder?)
  (let loop ((connections memoized-imap-connections) (prev #f) (near #f))
    (cond ((weak-pair? connections)
	   (let ((connection (weak-car connections)))
	     (if connection
		 (if (let ((url* (imap-connection-url connection)))
		       (if for-folder?
			   (eq? url* url)
			   (compatible-imap-urls? url* url)))
		     (if (or for-folder?
			     (test-imap-connection-open connection))
			 connection
			 (loop (weak-cdr connections) connections connection))
		     (loop (weak-cdr connections) connections near))
		 (let ((next (weak-cdr connections)))
		   (if prev
		       (weak-set-cdr! prev next)
		       (set! memoized-imap-connections next))
		   (loop next prev near)))))
	  (near)
	  (else
	   (let ((connection (make-imap-connection url)))
	     (without-interrupts
	      (lambda ()
		(set! memoized-imap-connections
		      (weak-cons connection memoized-imap-connections))))
	     connection)))))

(define memoized-imap-connections '())

(define (guarantee-imap-connection-open connection)
  (if (test-imap-connection-open connection)
      #f
      (let ((url (imap-connection-url connection)))
	(let ((port
	       (open-tcp-stream-socket (imap-url-host url)
				       (or (imap-url-port url) "imap2")
				       #f
				       "\n")))
	  (let ((finished? #f))
	    (dynamic-wind
	     (lambda () unspecific)
	     (lambda ()
	       (set-imap-connection-port! connection port)
	       (set-imap-connection-greeting!
		connection
		(let ((response (imap:read-server-response port)))
		  (if (imap:response:ok? response)
		      (imap:response:response-text-string response)
		      response)))
	       (reset-imap-connection connection)
	       (if (not (memq 'IMAP4REV1 (imap:command:capability connection)))
		   (error "Server doesn't support IMAP4rev1:" url))
	       (let ((response
		      (imail-call-with-pass-phrase
		       (imap-connection-url connection)
		       (lambda (pass-phrase)
			 (imap:command:login connection
					     (imap-url-user-id url)
					     pass-phrase)))))
		 (if (imap:response:no? response)
		     (error "Unable to log in:" response)))
	       (set! finished? #t))
	     (lambda ()
	       (if (not finished?)
		   (close-imap-connection connection))))))
	#t)))

(define (test-imap-connection-open connection)
  (let ((port (imap-connection-port connection)))
    (and port
	 (let* ((process
		 (lambda ()
		   (process-responses connection #f
				      (dequeue-imap-responses connection))))
		(lose
		 (lambda ()
		   (process)
		   (close-imap-connection connection)
		   #f)))
	   (let loop ()
	     (cond ((not (char-ready? port))
		    (process)
		    #t)
		   ((eof-object? (peek-char port))
		    (lose))
		   (else
		    (let ((response
			   (ignore-errors
			    (lambda ()
			      (imap:read-server-response port)))))
		      (if (or (condition? response)
			      (begin
				(enqueue-imap-response connection response)
				(imap:response:bye? response)))
			  (lose)
			  (loop))))))))))

(define (close-imap-connection connection)
  (let ((port
	 (without-interrupts
	  (lambda ()
	    (let ((port (imap-connection-port connection)))
	      (set-imap-connection-port! connection #f)
	      (let loop ((connections memoized-imap-connections) (prev #f))
		(if (weak-pair? connections)
		    (let ((next (weak-cdr connections)))
		      (if (eq? (weak-car connections) connection)
			  (if prev
			      (weak-set-cdr! prev next)
			      (set! memoized-imap-connections next))
			  (loop next connections)))))
	      port)))))
    (if port
	(close-port port)))
  (reset-imap-connection connection))

(define (imap-connection-server-type connection)
  (let ((greeting (imap-connection-greeting connection)))
    (cond ((not (string? greeting)) #f)
	  ((string-search-forward " Cyrus " greeting) 'CYRUS)
	  (else #f))))

(define (with-open-imap-connection url receiver)
  (let ((connection (get-imap-connection url #f)))
    (dynamic-wind (lambda ()
		    (set-imap-connection-reference-count!
		     connection
		     (+ (imap-connection-reference-count connection) 1)))
		  (lambda ()
		    (guarantee-imap-connection-open connection)
		    (let ((v (receiver connection)))
		      (maybe-close-imap-connection connection)
		      v))
		  (lambda ()
		    (set-imap-connection-reference-count!
		     connection
		     (- (imap-connection-reference-count connection) 1))))))

(define (maybe-close-imap-connection connection)
  (if (= (imap-connection-reference-count connection)
	 (if (imap-connection-folder connection) 0 1))
      (close-imap-connection connection)))

;;;; Folder datatype

(define-class (<imap-folder> (constructor (url connection))) (<folder>)
  (connection define accessor)
  (read-only? define standard)
  (allowed-flags define standard)
  (permanent-flags define standard)
  (permanent-keywords? define standard)
  (uidnext define standard)
  (uidvalidity define standard)
  (unseen define standard)
  (messages-synchronized? define standard)
  (n-messages define standard initial-value 0)
  (messages define standard initial-value '#()))

(define (reset-imap-folder! folder)
  (without-interrupts
   (lambda ()
     (detach-all-messages! folder)
     (set-imap-folder-read-only?! folder #f)
     (set-imap-folder-allowed-flags! folder '())
     (set-imap-folder-permanent-flags! folder '())
     (set-imap-folder-permanent-keywords?! folder #f)
     (set-imap-folder-uidnext! folder #f)
     (set-imap-folder-uidvalidity! folder #f)
     (set-imap-folder-unseen! folder #f)
     (set-imap-folder-messages-synchronized?! folder #f)
     (set-imap-folder-n-messages! folder 0)
     (set-imap-folder-messages! folder (initial-messages)))))

(define (new-imap-folder-uidvalidity! folder uidvalidity)
  (without-interrupts
   (lambda ()
     (detach-all-messages! folder)
     (fill-messages-vector! folder 0)
     (if (imap-folder-uidvalidity folder)
	 (set-imap-folder-unseen! folder #f))
     (set-imap-folder-uidvalidity! folder uidvalidity)))
  (read-message-headers! folder 0))

(define (detach-all-messages! folder)
  (let ((v (imap-folder-messages folder))
	(n (imap-folder-n-messages folder)))
    (do ((i 0 (fix:+ i 1)))
	((fix:= i n))
      (detach-message! (vector-ref v i)))))

(define (fill-messages-vector! folder start)
  (let ((v (imap-folder-messages folder))
	(n (imap-folder-n-messages folder)))
    (do ((index start (fix:+ index 1)))
	((fix:= index n))
      (vector-set! v index (make-imap-message folder index)))))

(define (read-message-headers! folder start)
  (if (imap-folder-uidvalidity folder)
      ((imail-message-wrapper "Reading message UIDs")
       (lambda ()
	 (imap:command:fetch-range (imap-folder-connection folder)
				   start #f '(UID))))))

(define (remove-imap-folder-message folder index)
  (without-interrupts
   (lambda ()
     (let ((v (imap-folder-messages folder))
	   (n (fix:- (imap-folder-n-messages folder) 1)))
       (detach-message! (vector-ref v index))
       (do ((i index (fix:+ i 1)))
	   ((fix:= i n))
	 (let ((m (vector-ref v (fix:+ i 1))))
	   (set-message-index! m i)
	   (vector-set! v i m)))
       (vector-set! v n #f)
       (set-imap-folder-n-messages! folder n)
       (set-imap-folder-unseen! folder #f)
       (let ((new-length (compute-messages-length v n)))
	 (if new-length
	     (set-imap-folder-messages! folder
					(vector-head v new-length))))
       (folder-modified! folder 'EXPUNGE (- index 1))))))

(define (initial-messages)
  (make-vector 64 #f))

(define (compute-messages-length v count)
  (let ((old-length (vector-length v))
	(min-length 64))
    (if (> count old-length)
	(let loop ((n (* old-length 2)))
	  (if (<= count n)
	      n
	      (loop (* n 2))))
	(and (> old-length min-length)
	     (<= count (quotient old-length 2))
	     (let loop ((n (quotient old-length 2)))
	       (let ((n/2 (quotient n 2)))
		 (if (or (> count n/2) (= n min-length))
		     n
		     (loop n/2))))))))

;;; SET-IMAP-FOLDER-LENGTH! needs explanation.  There are two basic
;;; cases.

;;; In the first case, our folder is synchronized with the server,
;;; meaning that our folder has the same length and UIDs as the
;;; server's mailbox.  In that case, length changes can only be
;;; increases, and we know that no deletions occur except those
;;; reflected by EXPUNGE responses (both constraints required by the
;;; IMAP specification).

;;; In the second case, we have lost synchrony with the server,
;;; usually because the connection was closed and then reopened.  Here
;;; we must resynchronize, matching up messages by UID.  Our strategy
;;; is to detach all of the existing messages, create a new message
;;; set with empty messages, read in the UIDs for the new messages,
;;; then match up the old messages with the new.  Any old message that
;;; matches a new one replaces it in the folder, thus preserving
;;; message pointers where possible.

;;; The reason for this complexity in the second case is that we can't
;;; be guaranteed that we will complete reading the UIDs for the new
;;; messages, either due to error or the user aborting the read.  So
;;; we must have everything in a consistent (if nonoptimal) state
;;; while reading.  If the read finishes, we can do the match/replace
;;; operation atomically.

(define (set-imap-folder-length! folder count)
  (if (or (imap-folder-messages-synchronized? folder)
	  (= 0 (imap-folder-n-messages folder)))
      (let ((n
	     (without-interrupts
	      (lambda ()
		(let ((v (imap-folder-messages folder))
		      (n (imap-folder-n-messages folder)))
		  (cond ((> count n)
			 (let ((new-length (compute-messages-length v count)))
			   (if new-length
			       (set-imap-folder-messages!
				folder
				(vector-grow v new-length #f))))
			 (set-imap-folder-n-messages! folder count)
			 (fill-messages-vector! folder n)
			 (set-imap-folder-messages-synchronized?! folder #t)
			 (folder-modified! folder 'INCREASE-LENGTH)
			 n)
			((= count n)
			 (set-imap-folder-messages-synchronized?! folder #t)
			 #f)
			(else
			 (error "EXISTS response decreased folder length:"
				folder))))))))
	(if n
	    (read-message-headers! folder n)))
      (let ((v.n
	     (without-interrupts
	      (lambda ()
		(detach-all-messages! folder)
		(let ((v (imap-folder-messages folder))
		      (n (imap-folder-n-messages folder)))
		  (set-imap-folder-n-messages! folder count)
		  (set-imap-folder-messages!
		   folder
		   (make-vector (or (compute-messages-length v count)
				    (vector-length v))
				#f))
		  (fill-messages-vector! folder 0)
		  (set-imap-folder-messages-synchronized?! folder #t)
		  (folder-modified! folder 'SET-LENGTH)
		  (cons v n))))))
	((imail-message-wrapper "Reading message UIDs")
	 (lambda ()
	   (imap:command:fetch-all (imap-folder-connection folder) '(UID))))
	(without-interrupts
	 (lambda ()
	   (let ((v (car v.n))
		 (n (cdr v.n))
		 (v* (imap-folder-messages folder))
		 (n* (imap-folder-n-messages folder)))
	     (let loop ((i 0) (i* 0))
	       (if (and (fix:< i n) (fix:< i* n*))
		   (let ((m (vector-ref v i))
			 (m* (vector-ref v* i*)))
		     (if (= (imap-message-uid m) (imap-message-uid m*))
			 (begin
			   ;; Flags might have been updated while
			   ;; reading the UIDs.
			   (if (%message-flags-initialized? m*)
			       (%set-message-flags! m (message-flags m*)))
			   (detach-message! m*)
			   (attach-message! m folder i*)
			   (vector-set! v* i* m)
			   (loop (fix:+ i 1) (fix:+ i* 1)))
			 (begin
			   (if (> (imap-message-uid m) (imap-message-uid m*))
			       (error "Message inserted into folder:" m*))
			   (loop (fix:+ i 1) i*))))))))))))

;;;; Message datatype

(define-class (<imap-message> (constructor (folder index))) (<message>)
  (uid)
  (length))

(define-generic imap-message-uid (message))
(define-generic imap-message-length (message))

(define-method set-message-flags! ((message <imap-message>) flags)
  (with-imap-message-open message
    (lambda (connection)
      (imap:command:uid-store-flags connection
				    (imap-message-uid message)
				    (map imail-flag->imap-flag
					 (flags-delete "\\recent" flags))))))

(define (imap-flag->imail-flag flag)
  (case flag
    ((\ANSWERED) "answered")
    ((\DELETED) "deleted")
    ((\SEEN) "seen")
    (else (symbol->string flag))))

(define (imail-flag->imap-flag flag)
  (cond ((string-ci=? flag "answered") '\ANSWERED)
	((string-ci=? flag "deleted") '\DELETED)
	((string-ci=? flag "seen") '\SEEN)
	(else (intern flag))))

(define-method message-internal-time ((message <imap-message>))
  (with-imap-message-open message
    (lambda (connection)
      (imap:response:fetch-attribute
       (imap:command:uid-fetch connection
			       (imap-message-uid message)
			       '(INTERNALDATE))
       'INTERNALDATE))))

(define-method message-length ((message <imap-message>))
  (with-imap-message-open message
    (lambda (connection)
      connection
      (imap-message-length message))))

(define (with-imap-message-open message receiver)
  (let ((folder (message-folder message)))
    (if folder
	(begin
	  (guarantee-imap-folder-open folder)
	  (receiver (imap-folder-connection folder))))))

;;; These reflectors are needed to guarantee that we read the
;;; appropriate information from the server.  Normally most message
;;; slots are filled in by READ-MESSAGE-HEADERS!, but it's possible
;;; for READ-MESSAGE-HEADERS! to be interrupted, leaving unfilled
;;; slots.  Also, we don't want to fill the BODY slot until it is
;;; requested, as the body might be very large.

(let ((accessor (slot-accessor <imap-message> 'UID))
      (initpred (slot-initpred <imap-message> 'UID)))
  (define-method imap-message-uid ((message <imap-message>))
    (if (not (initpred message))
	(with-imap-message-open message
	  (lambda (connection)
	    (let ((index (message-index message)))
	      (let ((suffix
		     (string-append " UID for message "
				    (number->string (+ index 1)))))
		((imail-message-wrapper "Reading" suffix)
		 (lambda ()
		   (imap:command:fetch connection index '(UID))
		   (if (not (initpred message))
		       (begin
			 ;; Still don't have the goods.  Send a NOOP, in
			 ;; case the server is holding it back because it
			 ;; also needs to send an EXPUNGE.
			 (imap:command:noop connection)
			 (if (not (initpred message))
			     (error
			      (string-append "Unable to obtain"
					     suffix))))))))))))
    (accessor message)))

(define (guarantee-headers-initialized message initpred)
  (guarantee-slot-initialized message initpred "headers"
			      '(FLAGS RFC822.SIZE RFC822.HEADER)))

(define (guarantee-body-initialized message initpred)
  (guarantee-slot-initialized message initpred "body" '(RFC822.TEXT)))

(define (guarantee-slot-initialized message initpred noun keywords)
  (if (not (initpred message))
      (with-imap-message-open message
	(lambda (connection)
	  (let ((uid (imap-message-uid message)))
	    (let ((suffix
		   (string-append
		    " " noun " for message "
		    (number->string (+ (message-index message) 1)))))
	      ((imail-message-wrapper "Reading" suffix)
	       (lambda ()
		 (imap:read-literal-progress-hook imail-progress-meter
		   (lambda ()
		     (imap:command:uid-fetch connection uid keywords)
		     (if (not (initpred message))
			 (error
			  (string-append "Unable to obtain" suffix)))))))))))))

(let ((reflector
       (lambda (generic-procedure slot-name guarantee)
	 (let ((initpred (slot-initpred <imap-message> slot-name)))
	   (define-method generic-procedure ((message <imap-message>))
	     (guarantee message initpred)
	     (call-next-method message))))))
  (reflector message-header-fields 'HEADER-FIELDS
	     guarantee-headers-initialized)
  (reflector message-body 'BODY guarantee-body-initialized)
  (reflector message-flags 'FLAGS guarantee-headers-initialized))

(let ((reflector
       (lambda (generic-procedure slot-name)
	 (let ((accessor (slot-accessor <imap-message> slot-name))
	       (initpred (slot-initpred <imap-message> slot-name)))
	   (define-method generic-procedure ((message <imap-message>))
	     (guarantee-headers-initialized message initpred)
	     (accessor message))))))
  (reflector imap-message-length 'LENGTH))

;;;; Server operations

(define-method %create-folder ((url <imap-url>))
  (with-open-imap-connection url
    (lambda (connection)
      (imap:command:create connection (imap-url-mailbox url)))))

(define-method %delete-folder ((url <imap-url>))
  (with-open-imap-connection url
    (lambda (connection)
      (imap:command:delete connection (imap-url-mailbox url)))))

(define-method %rename-folder ((url <imap-url>) (new-url <imap-url>))
  (if (compatible-imap-urls? url new-url)
      (with-open-imap-connection url
	(lambda (connection)
	  (imap:command:rename connection
			       (imap-url-mailbox url)
			       (imap-url-mailbox new-url))))
      (error "Unable to perform rename between different IMAP accounts:"
	     url new-url)))

(define-method %append-message ((message <message>) (url <imap-url>))
  (let ((folder (message-folder message))
	(maybe-create
	 (lambda (connection thunk)
	   (let ((response (thunk)))
	     (if (imap:response:no? response)
		 (if (imap:response-code:trycreate?
		      (imap:response:response-text-code response))
		     (begin
		       (imap:command:create connection (imap-url-mailbox url))
		       (let ((response (thunk)))
			 (if (imap:response:no? response)
			     (imap:server-error response))))
		     (imap:server-error response)))))))
    (if (let ((url* (folder-url folder)))
	  (and (imap-url? url*)
	       (compatible-imap-urls? url url*)))
	(begin
	  (guarantee-imap-folder-open folder)
	  (let ((connection (imap-folder-connection folder)))
	    (maybe-create connection
	      (lambda ()
		(imap:command:uid-copy connection
				       (imap-message-uid message)
				       (imap-url-mailbox url))))))
	(with-open-imap-connection url
	  (lambda (connection)
	    (maybe-create connection
	      (lambda ()
		(imap:command:append connection
				     (imap-url-mailbox url)
				     (map imail-flag->imap-flag
					  (flags-delete
					   "\\recent"
					   (message-flags message)))
				     (message-internal-time message)
				     (message->string message)))))))))

(define-method available-folder-names ((url <imap-url>))
  url
  (error "Unimplemented operation:" 'AVAILABLE-FOLDER-NAMES))

;;;; Folder operations

(define-method %open-folder ((url <imap-url>))
  (let ((folder (make-imap-folder url (get-imap-connection url #t))))
    (reset-imap-folder! folder)
    (guarantee-imap-folder-open folder)
    folder))

(define (guarantee-imap-folder-open folder)
  (let ((connection (imap-folder-connection folder)))
    (if (or (guarantee-imap-connection-open connection)
	    (not (eq? folder (imap-connection-folder connection))))
	(begin
	  (set-imap-folder-messages-synchronized?! folder #f)
	  (set-imap-connection-folder! connection folder)
	  (if (not
	       (imap:command:select connection
				    (imap-url-mailbox (folder-url folder))))
	      (set-imap-connection-folder! connection #f))
	  #t))))

(define-method %close-folder ((folder <imap-folder>))
  (let ((connection (imap-folder-connection folder)))
    (maybe-close-imap-connection connection)
    (set-imap-connection-folder! connection #f))
  (folder-modified! folder 'STATUS))

(define-method folder-length ((folder <imap-folder>))
  (imap-folder-n-messages folder))

(define-method %get-message ((folder <imap-folder>) index)
  (vector-ref (imap-folder-messages folder) index))

(define-method first-unseen-message-index ((folder <imap-folder>))
  (or (imap-folder-unseen folder) 0))

(define-method expunge-deleted-messages ((folder <imap-folder>))
  (guarantee-imap-folder-open folder)
  (imap:command:expunge (imap-folder-connection folder)))

(define-method search-folder ((folder <imap-folder>) criteria)
  (guarantee-imap-folder-open folder)
  (map (lambda (index) (- index 1))
       (imap:response:search-indices
	(let ((connection (imap-folder-connection folder)))
	  (cond ((string? criteria)
		 (imap:command:search connection 'TEXT criteria))
		(else
		 (error:wrong-type-argument criteria
					    "search criteria"
					    'SEARCH-FOLDER)))))))

(define-method folder-sync-status ((folder <imap-folder>))
  ;; Changes are always written through.
  folder
  'SYNCHRONIZED)

(define-method save-folder ((folder <imap-folder>))
  ;; Changes are always written through.
  folder
  unspecific)

(define-method discard-folder-cache ((folder <imap-folder>))
  (close-folder folder)
  (reset-imap-folder! folder))

(define-method probe-folder ((folder <imap-folder>))
  (guarantee-imap-folder-open folder)
  (imap:command:noop (imap-folder-connection folder)))

(define-method folder-connection-status ((folder <imap-folder>))
  (if (test-imap-connection-open (imap-folder-connection folder))
      'ONLINE
      'OFFLINE))

(define-method disconnect-folder ((folder <imap-folder>))
  (close-folder folder))

;;;; IMAP command invocation

(define (imap:command:capability connection)
  (imap:response:capabilities
   (imap:command:single-response imap:response:capability? connection
				 'CAPABILITY)))

(define (imap:command:login connection user-id pass-phrase)
  ((imail-message-wrapper "Logging in as " user-id)
   (lambda ()
     (imap:command:no-response-1 connection 'LOGIN user-id pass-phrase))))

(define (imap:command:select connection mailbox)
  ((imail-message-wrapper "Select mailbox " mailbox)
   (lambda ()
     (imap:response:ok?
      (imap:command:no-response-1 connection 'SELECT mailbox)))))

(define (imap:command:fetch connection index items)
  (imap:command:single-response imap:response:fetch? connection
				'FETCH (+ index 1) items))

(define (imap:command:uid-fetch connection uid items)
  (imap:command:single-response imap:response:fetch? connection
				'UID 'FETCH uid items))

(define (imap:command:fetch-all connection items)
  (imap:command:multiple-response imap:response:fetch? connection
				  'FETCH (cons 'ATOM "1:*") items))

(define (imap:command:fetch-range connection start end items)
  (imap:command:multiple-response
   imap:response:fetch? connection
   'FETCH
   (cons 'ATOM
	 (string-append (number->string (+ start 1))
			":"
			(if end (number->string end) "*")))
   items))

(define (imap:command:uid-store-flags connection uid flags)
  (imap:command:no-response connection 'UID 'STORE uid 'FLAGS flags))

(define (imap:command:expunge connection)
  ((imail-message-wrapper "Expunging messages")
   (lambda ()
     (imap:command:no-response connection 'EXPUNGE))))

(define (imap:command:noop connection)
  (imap:command:no-response connection 'NOOP))

(define (imap:command:create connection mailbox)
  (imap:command:no-response connection 'CREATE mailbox))

(define (imap:command:delete connection mailbox)
  (imap:command:no-response connection 'DELETE mailbox))

(define (imap:command:rename connection from to)
  (imap:command:no-response connection 'RENAME from to))

(define (imap:command:uid-copy connection uid mailbox)
  (imap:command:no-response-1 connection 'UID 'COPY uid mailbox))

(define (imap:command:append connection mailbox flags time text)
  (imap:command:no-response-1 connection 'APPEND mailbox
			      (and (pair? flags) flags)
			      (imap:universal-time->date-time time)
			      (cons 'LITERAL text)))

(define (imap:command:search connection . key-plist)
  (apply imap:command:single-response imap:response:search? connection
	 'SEARCH key-plist))

(define (imap:command:list connection reference pattern)
  (imap:command:multiple-response imap:response:list? connection
				  'LIST reference pattern))

(define (imap:command:no-response connection command . arguments)
  (let ((response
	 (apply imap:command:no-response-1 connection command arguments)))
    (if (not (imap:response:ok? response))
	(imap:server-error response))))

(define (imap:command:no-response-1 connection command . arguments)
  (let ((responses (apply imap:command connection command arguments)))
    (if (not (null? (cdr responses)))
	(error "Malformed response from IMAP server:" responses))
    (car responses)))

(define (imap:command:single-response predicate connection command . arguments)
  (let ((responses (apply imap:command connection command arguments)))
    (if (imap:response:ok? (car responses))
	(if (and (pair? (cdr responses))
		 (predicate (cadr responses))
		 (null? (cddr responses)))
	    (cadr responses)
	    (error "Malformed response from IMAP server:" responses))
	(imap:server-error (car responses)))))

(define (imap:command:multiple-response predicate
					connection command . arguments)
  (let ((responses (apply imap:command connection command arguments)))
    (if (imap:response:ok? (car responses))
	(if (for-all? (cdr responses) predicate)
	    (cdr responses)
	    (error "Malformed response from IMAP server:" responses))
	(imap:server-error (car responses)))))

(define (imap:server-error response)
  (let ((msg
	 (string-append "Server signalled a command error: "
			(imap:response:response-text-string response)))
	(code (imap:response:response-text-code response)))
    (if code
	(error msg code)
	(error msg))))

(define (imap:command connection command . arguments)
  (handle-broken-pipe
   (lambda (condition)
     condition
     (close-imap-connection connection)
     (error "Connection to IMAP server broken; please try again."))
   (lambda ()
     (imap:wait-for-tagged-response
      connection
      (imap:send-command connection command arguments)
      (if (eq? command 'UID)
	  (car arguments)
	  command)))))

(define imail-trace? #f)
(define imail-trace-output)

(define (start-imail-trace)
  (without-interrupts
   (lambda ()
     (set! imail-trace? #t)
     (set! imail-trace-output '())
     unspecific)))

(define (stop-imail-trace)
  (reverse!
   (without-interrupts
    (lambda ()
      (set! imail-trace? #f)
      (let ((output imail-trace-output))
	(set! imail-trace-output)
	output)))))

(define (save-imail-trace pathname)
  (call-with-output-file pathname
    (lambda (port)
      (for-each (lambda (x) (write-line x port))
		(stop-imail-trace)))))

(define (imail-trace-record-output object)
  (without-interrupts
   (lambda ()
     (set! imail-trace-output (cons object imail-trace-output))
     unspecific)))

(define (imap:send-command connection command arguments)
  (let ((tag (next-imap-command-tag connection))
	(port (imap-connection-port connection)))
    (if imail-trace?
	(imail-trace-record-output (cons* 'SEND tag command arguments)))
    (imap-transcript-write-string tag port)
    (imap-transcript-write-char #\space port)
    (imap-transcript-write command port)
    (for-each (lambda (argument)
		(if argument
		    (begin
		      (imap-transcript-write-char #\space port)
		      (imap:send-command-argument connection tag argument))))
	      arguments)
    (imap-transcript-write-char #\return port)
    (imap-transcript-write-char #\linefeed port)
    (imap-transcript-flush-output port)
    tag))

(define (imap:send-command-argument connection tag argument)
  (let ((port (imap-connection-port connection)))
    (let loop ((argument argument))
      (cond ((or (symbol? argument)
		 (exact-nonnegative-integer? argument))
	     (imap-transcript-write argument port))
	    ((and (pair? argument)
		  (eq? (car argument) 'ATOM)
		  (string? (cdr argument)))
	     (imap-transcript-write-string (cdr argument) port))
	    ((and (pair? argument)
		  (eq? (car argument) 'LITERAL)
		  (string? (cdr argument)))
	     (imap:write-literal-string connection tag (cdr argument)))
	    ((string? argument)
	     (if (imap:string-may-be-quoted? argument)
		 (imap:write-quoted-string argument port)
		 (imap:write-literal-string connection tag argument)))
	    ((list? argument)
	     (imap-transcript-write-char #\( port)
	     (if (pair? argument)
		 (begin
		   (loop (car argument))
		   (for-each (lambda (object)
			       (imap-transcript-write-char #\space port)
			       (loop object))
			     (cdr argument))))
	     (imap-transcript-write-char #\) port))
	    (else (error "Illegal IMAP syntax:" argument))))))

(define (imap:write-literal-string connection tag string)
  (let ((port (imap-connection-port connection)))
    (imap:write-literal-string-header string port)
    (imap-transcript-flush-output port)
    (let loop ()
      (let ((response (imap:read-server-response port)))
	(cond ((imap:response:continue? response)
	       (imap:write-literal-string-body string port))
	      ((and (imap:response:tag response)
		    (string-ci=? tag (imap:response:tag response)))
	       (error "Unable to finish continued command:" response))
	      (else
	       (enqueue-imap-response connection response)
	       (loop)))))))

(define (imap:wait-for-tagged-response connection tag command)
  (let ((port (imap-connection-port connection)))
    (let loop ()
      (let ((response (imap:read-server-response port)))
	(if imail-trace?
	    (imail-trace-record-output (list 'RECEIVE response)))
	(let ((tag* (imap:response:tag response)))
	  (if tag*
	      (let ((responses
		     (process-responses
		      connection command
		      (dequeue-imap-responses connection))))
		(if (string-ci=? tag tag*)
		    (if (or (imap:response:ok? response)
			    (imap:response:no? response))
			(cons response responses)
			(error "IMAP protocol error:" response))
		    (if (< (base26-string->nonnegative-integer tag*)
			   (base26-string->nonnegative-integer tag))
			;; If this is an old tag, ignore it and move on.
			(loop)
			(error "Out-of-sequence tag:" tag* tag))))
	      (begin
		(enqueue-imap-response connection response)
		(loop))))))))

(define (process-responses connection command responses)
  (if (pair? responses)
      (if (process-response connection command (car responses))
	  (cons (car responses)
		(process-responses connection command (cdr responses)))
	  (process-responses connection command (cdr responses)))
      '()))

(define (process-response connection command response)
  (cond ((imap:response:status-response? response)
	 (let ((code (imap:response:response-text-code response))
	       (text (imap:response:response-text-string response)))
	   (if code
	       (process-response-text connection command code text))
	   (if (and (imap:response:bye? response)
		    (not (memq command '(LOGOUT #F))))
	       (begin
		 (close-imap-connection connection)
		 (error "Server shut down connection:" text)))
	   (if (or (imap:response:no? response)
		   (imap:response:bad? response))
	       (imail-present-user-alert
		(lambda (port)
		  (write-string "Notice from IMAP server:" port)
		  (newline port)
		  (display text port)
		  (newline port)))))
	 (imap:response:preauth? response))
	((imap:response:exists? response)
	 (with-imap-connection-folder connection
	   (lambda (folder)
	     (set-imap-folder-length! folder
				      (imap:response:exists-count response))))
	 #f)
	((imap:response:expunge? response)
	 (with-imap-connection-folder connection
	   (lambda (folder)
	     (remove-imap-folder-message
	      folder
	      (- (imap:response:expunge-index response) 1))))
	 #f)
	((imap:response:flags? response)
	 (with-imap-connection-folder connection
	   (lambda (folder)
	     (set-imap-folder-allowed-flags!
	      folder
	      (map imap-flag->imail-flag (imap:response:flags response)))))
	 #f)
	((imap:response:recent? response)
	 #f)
	((imap:response:capability? response)
	 (eq? command 'CAPABILITY))
	((imap:response:list? response)
	 (eq? command 'LIST))
	((imap:response:lsub? response)
	 (eq? command 'LSUB))
	((imap:response:search? response)
	 (eq? command 'SEARCH))
	((imap:response:status? response)
	 (eq? command 'STATUS))
	((imap:response:fetch? response)
	 (with-imap-connection-folder connection
	   (lambda (folder)
	     (process-fetch-attributes
	      (get-message folder
			   (- (imap:response:fetch-index response) 1))
	      response)))
	 (eq? command 'FETCH))
	(else
	 (error "Illegal server response:" response))))

(define (process-response-text connection command code text)
  command
  (cond ((imap:response-code:alert? code)
	 (imail-present-user-alert
	  (lambda (port)
	    (write-string "Alert from IMAP server:" port)
	    (newline port)
	    (display text port)
	    (newline port))))
	((imap:response-code:permanentflags? code)
	 (with-imap-connection-folder connection
	   (lambda (folder)
	     (let ((pflags (imap:response-code:permanentflags code)))
	       (set-imap-folder-permanent-keywords?!
		folder
		(if (memq '\* pflags) #t #f))
	       (set-imap-folder-permanent-flags!
		folder
		(map imap-flag->imail-flag (delq '\* pflags)))))))
	((imap:response-code:read-only? code)
	 (with-imap-connection-folder connection
	   (lambda (folder)
	     (set-imap-folder-read-only?! folder #t))))
	((imap:response-code:read-write? code)
	 (with-imap-connection-folder connection
	   (lambda (folder)
	     (set-imap-folder-read-only?! folder #f))))
	((imap:response-code:uidnext? code)
	 (with-imap-connection-folder connection
	   (lambda (folder)
	     (set-imap-folder-uidnext! folder
				       (imap:response-code:uidnext code)))))
	((imap:response-code:uidvalidity? code)
	 (with-imap-connection-folder connection
	   (lambda (folder)
	     (let ((uidvalidity (imap:response-code:uidvalidity code)))
	       (if (not (eqv? uidvalidity (imap-folder-uidvalidity folder)))
		   (new-imap-folder-uidvalidity! folder uidvalidity))))))
	((imap:response-code:unseen? code)
	 (with-imap-connection-folder connection
	   (lambda (folder)
	     (set-imap-folder-unseen!
	      folder
	      (- (imap:response-code:unseen code) 1)))))
	#|
	  ((or (imap:response-code:badcharset? code)
	       (imap:response-code:newname? code)
	       (imap:response-code:parse? code)
	       (imap:response-code:trycreate? code))
	   unspecific)
	  |#
	))

(define (process-fetch-attributes message response)
  (for-each
   (lambda (keyword)
     (process-fetch-attribute message
			      keyword
			      (imap:response:fetch-attribute response
							     keyword)))
   (imap:response:fetch-attribute-keywords response)))

(define (process-fetch-attribute message keyword datum)
  (case keyword
    ((FLAGS)
     (%set-message-flags! message (map imap-flag->imail-flag datum))
     #t)
    ((RFC822.HEADER)
     (%set-message-header-fields! message
				  (lines->header-fields (string->lines datum)))
     #t)
    ((RFC822.SIZE)
     (%set-imap-message-length! message datum)
     #t)
    ((RFC822.TEXT)
     (%set-message-body! message datum)
     #t)
    ((UID)
     (%set-imap-message-uid! message datum)
     #t)
    (else #f)))

(define (with-imap-connection-folder connection receiver)
  (let ((folder (imap-connection-folder connection)))
    (if folder
	(receiver folder))))

(define %set-message-header-fields!
  (slot-modifier <imap-message> 'HEADER-FIELDS))

(define %set-message-body!
  (slot-modifier <imap-message> 'BODY))

(define %message-flags-initialized?
  (slot-initpred <imap-message> 'FLAGS))

(define %set-imap-message-uid!
  (slot-modifier <imap-message> 'UID))

(define %set-imap-message-length!
  (slot-modifier <imap-message> 'LENGTH))