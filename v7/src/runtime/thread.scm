#| -*-Scheme-*-

$Id: thread.scm,v 1.12 1993/04/28 19:47:27 cph Exp $

Copyright (c) 1991-1993 Massachusetts Institute of Technology

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

;;;; Multiple Threads of Control
;;; package: (runtime thread)

(declare (usual-integrations))

(define-structure (thread
		   (constructor %make-thread ())
		   (conc-name thread/))
  (execution-state 'RUNNING)
  ;; One of:
  ;; RUNNING
  ;; RUNNING-WITHOUT-PREEMPTION
  ;; WAITING
  ;; DEAD

  (next #f)
  ;; Pointer to next thread in run queue, or #F if none.

  (continuation #f)
  ;; #F if current thread or exited, else continuation for thread.

  (block-events? #f)
  ;; If true, events may not be delivered to this thread.  Instead,
  ;; they are queued.

  (pending-events (make-ring) read-only #t)
  ;; Doubly-linked circular list of events waiting to be delivered.

  (joined-threads '())
  ;; List of threads that have successfully called JOIN-THREAD on this
  ;; thread.

  (joined-to '())
  ;; List of threads to which this thread has joined.

  (exit-value no-exit-value-marker)
  ;; If the thread exits, the exit value is stored here so that
  ;; joined threads can get it.  If the thread has been detached,
  ;; this field holds a condition of type THREAD-DETACHED.

  (root-state-point #f)
  ;; Root state-point of the local state space of the thread.  Used to
  ;; unwind the thread's state space when it is exited.

  (mutexes '())
  ;; List of mutexes that this thread owns or is waiting to own.  Used
  ;; to disassociate the thread from those mutexes when it is exited.

  (properties (make-1d-table) read-only #t))

(define-integrable (guarantee-thread thread procedure)
  (if (not (thread? thread))
      (error:wrong-type-argument thread "thread" procedure)))

(define no-exit-value-marker
  (list 'NO-EXIT-VALUE-MARKER))

(define-integrable (thread-waiting? thread)
  (eq? 'WAITING (thread/execution-state thread)))

(define-integrable (thread-dead? thread)
  (eq? 'DEAD (thread/execution-state thread)))

(define thread-population)
(define first-running-thread)
(define last-running-thread)
(define thread-timer-running?)
(define root-continuation-default)

(define (initialize-package!)
  (initialize-error-conditions!)
  (set! thread-population (make-population))
  (set! first-running-thread #f)
  (set! last-running-thread #f)
  (set! thread-timer-running? #f)
  (set! timer-records #f)
  (set! timer-interval 100)
  (set! last-real-time #f)
  (initialize-input-blocking)
  (add-event-receiver! event:after-restore initialize-input-blocking)
  (detach-thread (make-thread #f))
  (add-event-receiver! event:before-exit stop-thread-timer))

(define (make-thread continuation)
  (let ((thread (%make-thread)))
    (set-thread/continuation! thread continuation)
    (set-thread/root-state-point! thread
				  (current-state-point state-space:local))
    (add-to-population! thread-population thread)
    (thread-running thread)
    thread))

(define-integrable (without-interrupts thunk)
  (let ((interrupt-mask (set-interrupt-enables! interrupt-mask/gc-ok)))
    (let ((value (thunk)))
      (set-interrupt-enables! interrupt-mask)
      value)))

(define (threads-list)
  (map-over-population thread-population (lambda (thread) thread)))

(define (thread-execution-state thread)
  (guarantee-thread thread thread-execution-state)
  (thread/execution-state thread))

(define (create-thread root-continuation thunk)
  (if (not (or (not root-continuation) (continuation? root-continuation)))
      (error:wrong-type-argument root-continuation
				 "continuation or #f"
				 create-thread))
  (call-with-current-continuation
   (lambda (return)
     (%within-continuation (or root-continuation root-continuation-default)
			   true
       (lambda ()
	 (fluid-let ((state-space:local (make-state-space)))
	   (call-with-current-continuation
	    (lambda (continuation)
	      (let ((thread (make-thread continuation)))
		(%within-continuation (let ((k return)) (set! return #f) k)
				      true
				      (lambda () thread)))))
	   (set-interrupt-enables! interrupt-mask/all)
	   (exit-current-thread (thunk))))))))

(define (create-thread-continuation)
  root-continuation-default)

(define (with-create-thread-continuation continuation thunk)
  (if (not (continuation? continuation))
      (error:wrong-type-argument continuation
				 "continuation"
				 with-create-thread-continuation))
  (fluid-let ((root-continuation-default continuation))
    (thunk)))

(define-integrable (current-thread)
  (or first-running-thread (error "No current thread!")))

(define (other-running-threads?)
  (thread/next (current-thread)))

(define (thread-continuation thread)
  (guarantee-thread thread thread-continuation)
  (without-interrupts
   (lambda ()
     (and (thread-waiting? thread)
	  (thread/continuation thread)))))

(define (thread-running thread)
  (%thread-running thread)
  (%maybe-toggle-thread-timer))

(define (%thread-running thread)
  (set-thread/execution-state! thread 'RUNNING)
  (let ((prev last-running-thread))
    (if prev
	(set-thread/next! prev thread)
	(set! first-running-thread thread)))
  (set! last-running-thread thread)
  unspecific)

(define (thread-not-running thread state)
  (set-thread/execution-state! thread state)
  (let ((thread* (thread/next thread)))
    (set-thread/next! thread false)
    (set! first-running-thread thread*)
    (if (not thread*)
	(begin
	  (set! last-running-thread thread*)
	  (%maybe-toggle-thread-timer)
	  (wait-for-input))
	(run-thread thread*))))

(define (run-thread thread)
  (let ((continuation (thread/continuation thread)))
    (set-thread/continuation! thread #f)
    (%within-continuation continuation #t
      (lambda ()
	(%resume-current-thread thread)))))

(define (%resume-current-thread thread)
  (if (thread/block-events? thread)
      (%maybe-toggle-thread-timer)
      (let ((event (handle-thread-events thread)))
	(set-thread/block-events?! thread #f)
	(%maybe-toggle-thread-timer)
	(if (eq? #t event) #f event))))

(define (suspend-current-thread)
  (without-interrupts %suspend-current-thread))

(define (%suspend-current-thread)
  (let ((thread (current-thread)))
    (let ((block-events? (thread/block-events? thread)))
      (set-thread/block-events?! thread false)
      (maybe-signal-input-thread-events)
      (let ((event
	     (let ((event (handle-thread-events thread)))
	       (if (eq? #t event)
		   (begin
		     (set-thread/block-events?! thread #f)
		     (call-with-current-continuation
		      (lambda (continuation)
			(set-thread/continuation! thread continuation)
			(thread-not-running thread 'WAITING))))
		   event))))
	(if (not block-events?)
	    (set-thread/block-events?! thread #f))
	event))))

(define (disallow-preempt-current-thread)
  (set-thread/execution-state! (current-thread) 'RUNNING-WITHOUT-PREEMPTION))

(define (allow-preempt-current-thread)
  (set-thread/execution-state! (current-thread) 'RUNNING))

(define (thread-timer-interrupt-handler)
  (set-interrupt-enables! interrupt-mask/gc-ok)
  (deliver-timer-events)
  (maybe-signal-input-thread-events)
  (let ((thread first-running-thread))
    (cond ((not thread)
	   (%maybe-toggle-thread-timer))
	  ((thread/continuation thread)
	   (run-thread thread))
	  ((not (eq? 'RUNNING-WITHOUT-PREEMPTION
		     (thread/execution-state thread)))
	   (yield-thread thread))
	  (else
	   (%resume-current-thread thread)))))

(define (yield-current-thread)
  (let ((thread (current-thread)))
    (without-interrupts
     (lambda ()
       ;; Allow preemption now, since the current thread has
       ;; volunteered to yield control.
       (set-thread/execution-state! thread 'RUNNING)
       (yield-thread thread)))))

(define (yield-thread thread)
  (let ((next (thread/next thread)))
    (if (not next)
	(%resume-current-thread thread)
	(call-with-current-continuation
	 (lambda (continuation)
	   (set-thread/continuation! thread continuation)
	   (set-thread/next! thread false)
	   (set-thread/next! last-running-thread thread)
	   (set! last-running-thread thread)
	   (set! first-running-thread next)
	   (run-thread next))))))

(define (exit-current-thread value)
  (let ((thread (current-thread)))
    (set-interrupt-enables! interrupt-mask/gc-ok)
    (set-thread/block-events?! thread #t)
    (ring/discard-all (thread/pending-events thread))
    (translate-to-state-point (thread/root-state-point thread))
    (%deregister-input-thread-events thread)
    (%discard-thread-timer-records thread)
    (%disassociate-joined-threads thread)
    (%disassociate-thread-mutexes thread)
    (if (eq? no-exit-value-marker (thread/exit-value thread))
	(release-joined-threads thread value))
    (thread-not-running thread 'DEAD)))

(define (join-thread thread event-constructor)
  (guarantee-thread thread join-thread)
  (let ((self (current-thread)))
    (if (eq? thread self)
	(signal-thread-deadlock self "join thread" join-thread thread)
	(without-interrupts
	 (lambda ()
	   (let ((value (thread/exit-value thread)))
	     (cond ((eq? value no-exit-value-marker)
		    (set-thread/joined-threads!
		     thread
		     (cons (cons self event-constructor)
			   (thread/joined-threads thread)))
		    (set-thread/joined-to!
		     self
		     (cons thread (thread/joined-to self))))
		   ((eq? value detached-thread-marker)
		    (signal-thread-detached thread))
		   (else
		    (signal-thread-event
		     self
		     (event-constructor thread value))))))))))

(define (detach-thread thread)
  (guarantee-thread thread detach-thread)
  (without-interrupts
   (lambda ()
     (if (eq? (thread/exit-value thread) detached-thread-marker)
	 (signal-thread-detached thread))
     (release-joined-threads thread detached-thread-marker))))

(define detached-thread-marker
  (list 'DETACHED-THREAD-MARKER))

(define (release-joined-threads thread value)
  (set-thread/exit-value! thread value)
  (do ((joined (thread/joined-threads thread) (cdr joined)))
      ((null? joined))
    (let ((joined (caar joined))
	  (event ((cdar joined) thread value)))
      (set-thread/joined-to! joined (delq! thread (thread/joined-to joined)))
      (%signal-thread-event joined event)))
  (%maybe-toggle-thread-timer))

(define (%disassociate-joined-threads thread)
  (do ((threads (thread/joined-to thread) (cdr threads)))
      ((null? threads))
    (set-thread/joined-threads!
     (car threads)
     (del-assq! thread (thread/joined-threads (car threads)))))
  (set-thread/joined-to! thread '()))

;;;; Input Thread Events

(define input-registry)
(define input-registrations)

(define-structure (dentry (conc-name dentry/))
  (descriptor #f read-only #t)
  first-tentry
  last-tentry
  prev
  next)

(define-structure (tentry (conc-name tentry/) (constructor make-tentry ()))
  dentry
  thread
  event
  prev
  next)

(define (initialize-input-blocking)
  (set! input-registry (make-select-registry))
  (set! input-registrations #f)
  unspecific)

(define-integrable (maybe-signal-input-thread-events)
  (if input-registrations
      (let ((result (select-registry-test input-registry #f)))
	(if (pair? result)
	    (signal-input-thread-events result)))))

(define (wait-for-input)
  (if (not input-registrations)
      (begin
	;; Busy-waiting here is a bad idea -- should implement a
	;; primitive to block the Scheme process while waiting for a
	;; signal.
	(set-interrupt-enables! interrupt-mask/all)
	(do () (false)))
      (begin
	(set-interrupt-enables! interrupt-mask/all)
	(let ((result (select-registry-test input-registry #t)))
	  (set-interrupt-enables! interrupt-mask/gc-ok)
	  (if (pair? result)
	      (signal-input-thread-events result))
	  (let ((thread first-running-thread))
	    (if thread
		(if (thread/continuation thread)
		    (run-thread thread))
		(wait-for-input)))))))

(define (block-on-input-descriptor descriptor)
  (without-interrupts
   (lambda ()
     (let ((delivered? #f)
	   (registration))
       (dynamic-wind
	(lambda ()
	  (set! registration
		(%register-input-thread-event descriptor
					      (current-thread)
					      (lambda ()
						(set! delivered? #t)
						unspecific)
					      #t))
	  unspecific)
	(lambda ()
	  (%suspend-current-thread)
	  delivered?)
	(lambda ()
	  (%deregister-input-thread-event registration)))))))

(define (permanently-register-input-thread-event descriptor thread event)
  (guarantee-thread thread permanently-register-input-thread-event)
  (let ((tentry (make-tentry)))
    (letrec ((register!
	      (lambda ()
		 (%%register-input-thread-event descriptor thread
						wrapped-event #f tentry)))
	     (wrapped-event (lambda () (register!) (event))))
      (without-interrupts register!)
      tentry)))

(define (register-input-thread-event descriptor thread event)
  (guarantee-thread thread register-input-thread-event)
  (without-interrupts
   (lambda ()
     (let ((tentry (%register-input-thread-event descriptor thread event #f)))
       (%maybe-toggle-thread-timer)
       tentry))))

(define (%register-input-thread-event descriptor thread event front?)
  (let ((tentry (make-tentry)))
    (%%register-input-thread-event descriptor thread event front? tentry)
    tentry))

(define (%%register-input-thread-event descriptor thread event front? tentry)
  (set-tentry/thread! tentry thread)
  (set-tentry/event! tentry event)
  (let ((dentry
	 (let loop ((dentry input-registrations))
	   (and dentry
		(if (= descriptor (dentry/descriptor dentry))
		    dentry
		    (loop (dentry/next dentry)))))))
    (if (not dentry)
	(let ((dentry (make-dentry descriptor #f #f #f #f)))
	  (set-tentry/dentry! tentry dentry)
	  (set-tentry/prev! tentry #f)
	  (set-tentry/next! tentry #f)
	  (set-dentry/first-tentry! dentry tentry)
	  (set-dentry/last-tentry! dentry tentry)
	  (if input-registrations
	      (set-dentry/prev! input-registrations dentry))
	  (set-dentry/next! dentry input-registrations)
	  (set! input-registrations dentry)
	  (add-to-select-registry! input-registry descriptor))
	(begin
	  (set-tentry/dentry! tentry dentry)
	  (if front?
	      (let ((next (dentry/first-tentry dentry)))
		(set-tentry/prev! tentry #f)
		(set-tentry/next! tentry next)
		(set-dentry/first-tentry! dentry tentry)
		(set-tentry/prev! next tentry))
	      (let ((prev (dentry/last-tentry dentry)))
		(set-tentry/prev! tentry prev)
		(set-tentry/next! tentry #f)
		(set-dentry/last-tentry! dentry tentry)
		(set-tentry/next! prev tentry)))))))

(define (deregister-input-thread-event tentry)
  (if (not (tentry? tentry))
      (error:wrong-type-argument tentry "input thread event registration"
				 'DEREGISTER-INPUT-THREAD-EVENT))
  (without-interrupts
   (lambda ()
     (%deregister-input-thread-event tentry)
     (%maybe-toggle-thread-timer))))

(define (%deregister-input-thread-event tentry)
  (if (tentry/dentry tentry)
      (delete-tentry! tentry)))

(define (%deregister-input-thread-events thread)
  (let loop ((dentry input-registrations) (tentries '()))
    (if (not dentry)
	(do ((tentries tentries (cdr tentries)))
	    ((null? tentries))
	  (delete-tentry! (car tentries)))
	(loop (dentry/next dentry)
	      (let loop
		  ((tentry (dentry/first-tentry dentry)) (tentries tentries))
		(if (not tentry)
		    tentries
		    (loop (tentry/next tentry)
			  (if (eq? thread (tentry/thread tentry))
			      (cons tentry tentries)
			      tentries))))))))

(define (signal-input-thread-events descriptors)
  (let loop ((dentry input-registrations) (tentries '()))
    (if (not dentry)
	(begin
	  (do ((tentries tentries (cdr tentries)))
	      ((null? tentries))
	    (%signal-thread-event (tentry/thread (car tentries))
				  (tentry/event (car tentries)))
	    (delete-tentry! (car tentries)))
	  (%maybe-toggle-thread-timer))
	(loop (dentry/next dentry)
	      (if (let ((descriptor (dentry/descriptor dentry)))
		    (let loop ((descriptors descriptors))
		      (and (not (null? descriptors))
			   (or (= descriptor (car descriptors))
			       (loop (cdr descriptors))))))
		  (cons (dentry/first-tentry dentry) tentries)
		  tentries)))))

(define (delete-tentry! tentry)
  (let ((dentry (tentry/dentry tentry))
	(prev (tentry/prev tentry))
	(next (tentry/next tentry)))
    (set-tentry/dentry! tentry #f)
    (set-tentry/thread! tentry #f)
    (set-tentry/event! tentry #f)
    (set-tentry/prev! tentry #f)
    (set-tentry/next! tentry #f)
    (if prev
	(set-tentry/next! prev next)
	(set-dentry/first-tentry! dentry next))
    (if next
	(set-tentry/prev! next prev)
	(set-dentry/last-tentry! dentry prev))
    (if (not (or prev next))
	(begin
	  (remove-from-select-registry! input-registry
					(dentry/descriptor dentry))
	  (let ((prev (dentry/prev dentry))
		(next (dentry/next dentry)))
	    (if prev
		(set-dentry/next! prev next)
		(set! input-registrations next))
	    (if next
		(set-dentry/prev! next prev))))))
  unspecific)

;;;; Events

(define (block-thread-events)
  (without-interrupts
   (lambda ()
     (let ((thread (current-thread)))
       (let ((result (thread/block-events? thread)))
	 (set-thread/block-events?! thread true)
	 result)))))

(define (unblock-thread-events)
  (without-interrupts
   (lambda ()
     (let ((thread (current-thread)))
       (handle-thread-events thread)
       (set-thread/block-events?! thread #f)))))

(define (signal-thread-event thread event)
  (guarantee-thread thread signal-thread-event)
  (let ((self first-running-thread))
    (if (eq? thread self)
	(let ((block-events? (block-thread-events)))
	  (ring/enqueue (thread/pending-events thread) event)
	  (if (not block-events?)
	      (unblock-thread-events)))
	(without-interrupts
	 (lambda ()
	   (if (thread-dead? thread)
	       (signal-thread-dead thread "signal event to"
				   signal-thread-event thread event))
	   (%signal-thread-event thread event)
	   (if (and (not self) first-running-thread)
	       (run-thread first-running-thread)
	       (%maybe-toggle-thread-timer)))))))

(define (%signal-thread-event thread event)
  (ring/enqueue (thread/pending-events thread) event)
  (if (and (not (thread/block-events? thread))
	   (thread-waiting? thread))
      (%thread-running thread)))

(define (handle-thread-events thread)
  (let loop ((result #t))
    (let ((event (ring/dequeue (thread/pending-events thread) #t)))
      (if (eq? #t event)
	  result
	  (begin
	    (if event
		(begin
		  (set-thread/block-events?! thread true)
		  (event)
		  (set-interrupt-enables! interrupt-mask/gc-ok)))
	    (loop (if (or (eq? #f result) (eq? #t result))
		      event
		      result)))))))

;;;; Timer Events

(define last-real-time)
(define timer-records)
(define timer-interval)

(define-structure (timer-record
		   (conc-name timer-record/))
  (time false read-only false)
  thread
  event
  next)

(define (register-timer-event interval event)
  (let ((time (+ (real-time-clock) interval)))
    (let ((new-record (make-timer-record time (current-thread) event false)))
      (without-interrupts
       (lambda ()
	 (let loop ((record timer-records) (prev false))
	   (if (or (not record) (< time (timer-record/time record)))
	       (begin
		 (set-timer-record/next! new-record record)
		 (if prev
		     (set-timer-record/next! prev new-record)
		     (set! timer-records new-record)))
	       (loop (timer-record/next record) record)))))
      new-record)))

(define (sleep-current-thread interval)
  (let ((delivered? #f))
    (let ((block-events? (block-thread-events)))
      (register-timer-event interval
			    (lambda () (set! delivered? #t) unspecific))
      (do () (delivered?)
	(suspend-current-thread))
      (if (not block-events?)
	  (unblock-thread-events)))))

(define (deliver-timer-events)
  (let ((time (real-time-clock)))
    (if (and last-real-time
	     (< time last-real-time))
	;; The following adjustment is correct, assuming that the
	;; real-time timer wraps around to 0, and assuming that there
	;; has been no GC or OS time slice between the time when the
	;; timer interrupt was delivered and the time when REAL-TIME-CLOCK
	;; was called above.
	(let ((wrap-value (+ last-real-time
			     (if (not timer-interval)
				 0
				 (- timer-interval time)))))
	  (let update ((record timer-records))
	    (if record
		(begin
		  (set-timer-record/time!
		   record
		   (- (timer-record/time record) wrap-value))
		  (update (timer-record/next record)))))))
    (set! last-real-time time)
    (let loop ((record timer-records))
      (if (or (not record) (< time (timer-record/time record)))
	  (set! timer-records record)
	  (begin
	    (let ((thread (timer-record/thread record))
		  (event (timer-record/event record)))
	      (set-timer-record/thread! record #f)
	      (set-timer-record/event! record #f)
	      (%signal-thread-event thread event))
	    (loop (timer-record/next record))))))
  unspecific)

(define (deregister-timer-event registration)
  (if (not (timer-record? registration))
      (error:wrong-type-argument registration "timer event registration"
				 'DEREGISTER-TIMER-EVENT))
  (without-interrupts
   (lambda ()
     (let loop ((record timer-records) (prev #f))
       (if record
	   (let ((next (timer-record/next record)))
	     (if (eq? record registration)
		 (if prev
		     (set-timer-record/next! prev next)
		     (set! timer-records next))
		 (loop next record)))))
     (%maybe-toggle-thread-timer))))

(define-integrable (threads-pending-timer-events?)
  timer-records)

(define (%discard-thread-timer-records thread)
  (let loop ((record timer-records) (prev #f))
    (if record
	(let ((next (timer-record/next record)))
	  (if (eq? thread (timer-record/thread record))
	      (begin
		(if prev
		    (set-timer-record/next! prev next)
		    (set! timer-records next))
		(loop next prev))
	      (loop next record))))))

(define (thread-timer-interval)
  timer-interval)

(define (set-thread-timer-interval! interval)
  (if (not (or (false? interval)
	       (and (exact-integer? interval)
		    (> interval 0))))
      (error:wrong-type-argument interval false 'SET-THREAD-TIMER-INTERVAL!))
  (without-interrupts
    (lambda ()
      (set! timer-interval interval)
      (%maybe-toggle-thread-timer))))

(define (start-thread-timer)
  (without-interrupts %maybe-toggle-thread-timer))

(define (stop-thread-timer)
  (without-interrupts %stop-thread-timer))

(define (%maybe-toggle-thread-timer)
  (if (and timer-interval
	   (or (let ((current-thread first-running-thread))
		 (and current-thread
		      (or (thread/next current-thread)
			  input-registrations)))
	       (threads-pending-timer-events?)))
      (if (not thread-timer-running?)
	  (begin
	    ((ucode-primitive real-timer-set) timer-interval timer-interval)
	    (set! thread-timer-running? true)
	    unspecific))
      (%stop-thread-timer)))

(define (%stop-thread-timer)
  (if thread-timer-running?
      (begin
	((ucode-primitive real-timer-clear))
	(set! thread-timer-running? false)
	((ucode-primitive clear-interrupts!) interrupt-bit/timer))))

;;;; Mutexes

(define-structure (thread-mutex
		   (constructor make-thread-mutex ())
		   (conc-name thread-mutex/))
  (waiting-threads (make-ring) read-only #t)
  (owner #f))

(define-integrable (guarantee-thread-mutex mutex procedure)
  (if (not (thread-mutex? mutex))
      (error:wrong-type-argument mutex "thread-mutex" procedure)))

(define (thread-mutex-owner mutex)
  (guarantee-thread-mutex mutex thread-mutex-owner)
  (thread-mutex/owner mutex))

(define (lock-thread-mutex mutex)
  (guarantee-thread-mutex mutex lock-thread-mutex)
  (without-interrupts
   (lambda ()
     (let ((thread (current-thread))
	   (owner (thread-mutex/owner mutex)))
       (if (eq? owner thread)
	   (signal-thread-deadlock thread "lock thread mutex"
				   lock-thread-mutex mutex))
       (%lock-thread-mutex mutex thread owner)))))

(define (%lock-thread-mutex mutex thread owner)
  (add-thread-mutex! thread mutex)
  (if owner
      (begin
	(ring/enqueue (thread-mutex/waiting-threads mutex) thread)
	(do () ((eq? thread (thread-mutex/owner mutex)))
	  (%suspend-current-thread)))
      (set-thread-mutex/owner! mutex thread)))

(define (unlock-thread-mutex mutex)
  (guarantee-thread-mutex mutex unlock-thread-mutex)
  (without-interrupts
   (lambda ()
     (let ((owner (thread-mutex/owner mutex)))
       (if (and thread (not (eq? owner (current-thread))))
	   (error "Don't own mutex:" mutex))
       (%unlock-thread-mutex mutex owner)))))

(define (%unlock-thread-mutex mutex owner)
  (remove-thread-mutex! owner mutex)
  (if (%%unlock-thread-mutex mutex)
      (%maybe-toggle-thread-timer)))

(define (%%unlock-thread-mutex mutex)
  (let ((thread (ring/dequeue (thread-mutex/waiting-threads mutex) #f)))
    (set-thread-mutex/owner! mutex thread)
    (if thread (%signal-thread-event thread #f))
    thread))

(define (try-lock-thread-mutex mutex)
  (guarantee-thread-mutex mutex try-lock-thread-mutex)
  (without-interrupts
   (lambda ()
     (and (not (thread-mutex/owner mutex))
	  (let ((thread (current-thread)))
	    (set-thread-mutex/owner! mutex thread)
	    (add-thread-mutex! thread mutex)
	    #t)))))

(define (with-thread-mutex-locked mutex thunk)
  (guarantee-thread-mutex mutex lock-thread-mutex)
  (let ((thread (current-thread))
	(grabbed-lock?))
    (dynamic-wind
     (lambda ()
       (let ((owner (thread-mutex/owner mutex)))
	 (if (eq? owner thread)
	     (begin
	       (set! grabbed-lock? #f)
	       unspecific)
	     (begin
	       (set! grabbed-lock? #t)
	       (%lock-thread-mutex mutex thread owner)))))
     thunk
     (lambda ()
       (if (and grabbed-lock? (eq? (thread-mutex/owner mutex) thread))
	   (%unlock-thread-mutex mutex thread))))))

(define (%disassociate-thread-mutexes thread)
  (do ((mutexes (thread/mutexes thread) (cdr mutexes)))
      ((null? mutexes))
    (let ((mutex (car mutexes)))
      (if (eq? (thread-mutex/owner mutex) thread)
	  (%%unlock-thread-mutex mutex)
	  (ring/remove-item (thread-mutex/waiting-threads mutex) thread))))
  (set-thread/mutexes! thread '()))

(define-integrable (add-thread-mutex! thread mutex)
  (set-thread/mutexes! thread (cons mutex (thread/mutexes thread))))

(define-integrable (remove-thread-mutex! thread mutex)
  (set-thread/mutexes! thread (delq! mutex (thread/mutexes thread))))

;;;; Circular Rings

(define-structure (link (conc-name link/))
  prev
  next
  item)

(define (make-ring)
  (let ((link (make-link false false false)))
    (set-link/prev! link link)
    (set-link/next! link link)
    link))

(define-integrable (ring/empty? ring)
  (eq? (link/next ring) ring))

(define (ring/enqueue ring item)
  (let ((prev (link/prev ring)))
    (let ((link (make-link prev ring item)))
      (set-link/next! prev link)
      (set-link/prev! ring link))))

(define (ring/dequeue ring default)
  (let ((link (link/next ring)))
    (if (eq? link ring)
	default
	(begin
	  (let ((next (link/next link)))
	    (set-link/next! ring next)
	    (set-link/prev! next ring))
	  (link/item link)))))

(define (ring/discard-all ring)
  (set-link/prev! ring ring)
  (set-link/next! ring ring))

(define (ring/remove-item ring item)
  (let loop ((link (link/next ring)))
    (if (not (eq? link ring))
	(if (eq? (link/item link) item)
	    (let ((prev (link/prev link))
		  (next (link/next link)))
	      (set-link/next! prev next)
	      (set-link/prev! next prev))
	    (loop (link/next link))))))

;;;; Error Conditions

(define condition-type:thread-control-error)
(define thread-control-error/thread)
(define condition-type:thread-deadlock)
(define signal-thread-deadlock)
(define thread-deadlock/description)
(define thread-deadlock/operator)
(define thread-deadlock/operand)
(define condition-type:thread-detached)
(define signal-thread-detached)
(define condition-type:thread-dead)
(define signal-thread-dead)
(define thread-dead/verb)

(define (initialize-error-conditions!)
  (set! condition-type:thread-control-error
	(make-condition-type 'THREAD-CONTROL-ERROR condition-type:control-error
	    '(THREAD)
	  (lambda (condition port)
	    (write-string "Anonymous error associated with " port)
	    (write (thread-control-error/thread condition) port)
	    (write-string "." port))))
  (set! thread-control-error/thread
	(condition-accessor condition-type:thread-control-error 'THREAD))

  (set! condition-type:thread-deadlock
	(make-condition-type 'THREAD-DEADLOCK
	    condition-type:thread-control-error
	    '(DESCRIPTION OPERATOR OPERAND)
	  (lambda (condition port)
	    (write-string "Deadlock detected while trying to " port)
	    (write-string (thread-deadlock/description condition) port)
	    (write-string ": " port)
	    (write (thread-deadlock/operand condition) port)
	    (write-string "." port))))
  (set! signal-thread-deadlock
	(condition-signaller condition-type:thread-deadlock
			     '(THREAD DESCRIPTION OPERATOR OPERAND)
			     standard-error-handler))
  (set! thread-deadlock/description
	(condition-accessor condition-type:thread-deadlock 'DESCRIPTION))
  (set! thread-deadlock/operator
	(condition-accessor condition-type:thread-deadlock 'OPERATOR))
  (set! thread-deadlock/operand
	(condition-accessor condition-type:thread-deadlock 'OPERAND))

  (set! condition-type:thread-detached
	(make-condition-type 'THREAD-DETACHED
	    condition-type:thread-control-error
	    '()
	  (lambda (condition port)
	    (write-string "Attempt to join detached thread: " port)
	    (write (thread-control-error/thread condition) port)
	    (write-string "." port))))
  (set! signal-thread-detached
	(condition-signaller condition-type:thread-detached
			     '(THREAD)
			     standard-error-handler))

  (set! condition-type:thread-dead
	(make-condition-type 'THREAD-DEAD condition-type:thread-control-error
	    '(VERB OPERATOR OPERANDS)
	  (lambda (condition port)
	    (write-string "Unable to " port)
	    (write-string (thread-dead/verb condition) port)
	    (write-string " thread " port)
	    (write (thread-control-error/thread condition) port)
	    (write-string " because it is dead." port))))
  (set! signal-thread-dead
	(let ((signaller
	       (condition-signaller condition-type:thread-dead
				    '(THREAD VERB OPERATOR OPERANDS)
				    standard-error-handler)))
	  (lambda (thread verb operator . operands)
	    (signaller thread verb operator operands))))
  (set! thread-dead/verb
	(condition-accessor condition-type:thread-dead 'VERB))
  unspecific)