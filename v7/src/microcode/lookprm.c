/* -*-C-*-

$Header: /Users/cph/tmp/foo/mit-scheme/mit-scheme/v7/src/microcode/lookprm.c,v 1.5 1992/01/15 02:37:02 jinx Exp $

Copyright (c) 1988-1992 Massachusetts Institute of Technology

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
MIT in each case. */

/* This file contains environment manipulation primitives.
   It makes heavy use of procedures in lookup.c */

#include "scheme.h"
#include "locks.h"
#include "trap.h"
#include "lookup.h"
#include "prims.h"

/* NOTE:
   Although this code has been parallelized, it has not been
   exhaustively tried on a parallel processor.  There are probably
   various race conditions that have to be thought about carefully.
 */

/* Utility macros */

#define VALID_ENVIRONMENT_P(env)					\
  ((OBJECT_TYPE (env) == TC_ENVIRONMENT) ||				\
   ((OBJECT_TYPE (env) == GLOBAL_ENV) &&				\
    (OBJECT_DATUM (env) == GO_TO_GLOBAL)))

/* This used to be more paranoid, and check for interned symbols,
   rather than normal symbols.  Does it matter?
 */

#define lookup_primitive_type_test()					\
do									\
{									\
  CHECK_ARG(1, ENVIRONMENT_P);						\
  CHECK_ARG(2, SYMBOL_P);						\
} while (0)

#define lookup_primitive_action(action)					\
{									\
  long result;								\
									\
  result = (action);							\
  if (result != PRIM_DONE)						\
  {									\
    if (result == PRIM_INTERRUPT)					\
      signal_interrupt_from_primitive();				\
    else								\
      signal_error_from_primitive(result);				\
  }									\
}

#define lookup_primitive_end(value, action)				\
{									\
  lookup_primitive_action(action);					\
  PRIMITIVE_RETURN(value);						\
}

#define standard_lookup_primitive(action)				\
{									\
  lookup_primitive_type_test();						\
  lookup_primitive_end(Val, action);					\
  /*NOTREACHED*/							\
}

/* (LEXICAL-ASSIGNMENT ENVIRONMENT SYMBOL VALUE)
   Sets the value of the variable with the name given in SYMBOL, as
   seen in the lexical ENVIRONMENT, to the specified VALUE.
   Returns the previous value.

   It's indistinguishable from evaluating
   (set! <symbol> <value>) in <environment>.
*/

DEFINE_PRIMITIVE ("LEXICAL-ASSIGNMENT", Prim_lexical_assignment, 3, 3, 0)
{
  PRIMITIVE_HEADER (3);

  standard_lookup_primitive(Symbol_Lex_Set(ARG_REF (1),
					   ARG_REF (2), ARG_REF (3)));
}

/* (LEXICAL-REFERENCE ENVIRONMENT SYMBOL)
   Returns the value of the variable with the name given in SYMBOL,
   as seen in the lexical ENVIRONMENT.

   Indistinguishable from evaluating <symbol> in <environment>.
*/

DEFINE_PRIMITIVE ("LEXICAL-REFERENCE", Prim_lexical_reference, 2, 2, 0)
{
  PRIMITIVE_HEADER (2);

  standard_lookup_primitive(Symbol_Lex_Ref(ARG_REF (1), ARG_REF (2)));
}

/* (LOCAL-REFERENCE ENVIRONMENT SYMBOL)
   Identical to LEXICAL_REFERENCE, here for histerical reasons.
*/

DEFINE_PRIMITIVE ("LOCAL-REFERENCE", Prim_local_reference, 2, 2, 0)
{
  PRIMITIVE_HEADER (2);

  standard_lookup_primitive(Symbol_Lex_Ref(ARG_REF (1), ARG_REF (2)));
}

/* (LOCAL-ASSIGNMENT ENVIRONMENT SYMBOL VALUE)
   Should be called LEXICAL-DEFINE.

   If the variable specified by SYMBOL already exists in the
   lexical ENVIRONMENT, then its value there is changed to VALUE.
   Otherwise a new binding is created in that environment linking
   the specified variable to the value.  Returns SYMBOL.

   Indistinguishable from evaluating
   (define <symbol> <value>) in <environment>. */

DEFINE_PRIMITIVE ("LOCAL-ASSIGNMENT", Prim_local_assignment, 3, 3, 0)
{
  PRIMITIVE_HEADER (3);
  standard_lookup_primitive
    (Local_Set ((ARG_REF (1)), (ARG_REF (2)), (ARG_REF (3))));
}

/* (LEXICAL-UNASSIGNED? ENVIRONMENT SYMBOL)
   Returns #T if the variable corresponding to SYMBOL is bound
   but has the special UNASSIGNED value in ENVIRONMENT.  Returns
   #F otherwise.  Does a complete lexical search for SYMBOL
   starting in ENVIRONMENT.
   The special form (unassigned? <symbol>) is built on top of this. */

DEFINE_PRIMITIVE ("LEXICAL-UNASSIGNED?", Prim_unassigned_test, 2, 2, 0)
{
  extern long EXFUN (Symbol_Lex_unassigned_p, (SCHEME_OBJECT, SCHEME_OBJECT));
  PRIMITIVE_HEADER (2);
  standard_lookup_primitive
    (Symbol_Lex_unassigned_p ((ARG_REF (1)), (ARG_REF (2))));
}

/* (LEXICAL-UNBOUND? ENVIRONMENT SYMBOL)
   Returns #T if the variable corresponding to SYMBOL has no
   binding in ENVIRONMENT.  Returns #F otherwise.  Does a complete
   lexical search for SYMBOL starting in ENVIRONMENT.
   The special form (unbound? <symbol>) is built on top of this. */

DEFINE_PRIMITIVE ("LEXICAL-UNBOUND?", Prim_unbound_test, 2, 2, 0)
{
  extern long EXFUN (Symbol_Lex_unbound_p, (SCHEME_OBJECT, SCHEME_OBJECT));
  PRIMITIVE_HEADER (2);
  standard_lookup_primitive
    (Symbol_Lex_unbound_p ((ARG_REF (1)), (ARG_REF (2))));
}

/* (LEXICAL-UNREFERENCEABLE? ENVIRONMENT SYMBOL)
   Returns #T if evaluating <symbol> in <environment> would cause
   a variable lookup error (unbound or unassigned).
*/

DEFINE_PRIMITIVE ("LEXICAL-UNREFERENCEABLE?", Prim_unreferenceable_test, 2, 2, 0)
{
  long Result;
  PRIMITIVE_HEADER (2);

  lookup_primitive_type_test();
  Result = Symbol_Lex_Ref(ARG_REF (1), ARG_REF (2));
  switch (Result)
  {
    case PRIM_DONE:
      PRIMITIVE_RETURN (SHARP_F);

    case PRIM_INTERRUPT:
      signal_interrupt_from_primitive();
      /*NOTREACHED*/

    case ERR_UNASSIGNED_VARIABLE:
    case ERR_UNBOUND_VARIABLE:
      PRIMITIVE_RETURN(SHARP_T);

    default:
      signal_error_from_primitive(Result);
  }
  /*NOTREACHED*/
}

SCHEME_OBJECT
extract_or_create_cache(frame, sym)
     SCHEME_OBJECT frame, sym;
{
  extern SCHEME_OBJECT compiler_cache_variable[];
  extern long EXFUN (compiler_cache,
		     (SCHEME_OBJECT *, SCHEME_OBJECT, SCHEME_OBJECT,
		      SCHEME_OBJECT, long, long, Boolean));
  SCHEME_OBJECT *cell, value;
  long trap_kind, result;

  cell = deep_lookup(frame, sym, compiler_cache_variable);
  value = MEMORY_FETCH (cell[0]);
  if (REFERENCE_TRAP_P(value))
  {
    get_trap_kind(trap_kind, value);
    switch (trap_kind)
    {
      case TRAP_UNBOUND:
      case TRAP_UNBOUND_DANGEROUS:
        signal_error_from_primitive(ERR_UNBOUND_VARIABLE);

      case TRAP_COMPILER_CACHED:
      case TRAP_COMPILER_CACHED_DANGEROUS:
	return (FAST_MEMORY_REF (value, TRAP_EXTRA));

      /* This should list the traps explicitely */
      default:
        break;
    }
  }
  result = compiler_cache(cell, frame, sym, SHARP_F, 0,
			  TRAP_REFERENCES_LOOKUP, true);
  if (result != PRIM_DONE)
  {
    if (result == PRIM_INTERRUPT)
      signal_interrupt_from_primitive();
    else
      signal_error_from_primitive(result);
  }
  value = MEMORY_FETCH (cell[0]);
  return (FAST_MEMORY_REF (value, TRAP_EXTRA));
}

void
error_bad_environment(arg)
     long arg;
{
  if (OBJECT_TYPE (ARG_REF(arg)) == GLOBAL_ENV)
    error_bad_range_arg(arg);
  else
    error_wrong_type_arg(arg);
  /*NOTREACHED*/
}

/* (ENVIRONMENT-LINK-NAME <env1> <env2> <symbol>)
   <symbol> must be locally undefined in <env1>, and defined in <env2>.
   It defines <symbol> in <env1> and makes it share its value cell with
   <symbol> in <env2>.

   This code returns #t if it succeeds, or the following errors
   (besides type and range errors) with the following meanings:

   - ERR_UNBOUND_VARIABLE:
      <symbol> is unbound in <env2>.

   - ERR_BAD_SET:
      <symbol> is bound locally in <env1>.

   - ERR_BAD_FRAME:
      Inconsistency in the code.  Bad value found.

   - ILLEGAL_REFERENCE_TRAP:
      A bad reference trap was found.

   *UNDEFINE*: If undefine is ever implemented, the code below may be
   affected.  It will have to be rethought.

   NOTE: The following procedure and extract_or_create_cache have NOT
   been parallelized.  They needs thinking.
*/

DEFINE_PRIMITIVE ("ENVIRONMENT-LINK-NAME", Prim_environment_link_name, 3, 3, 0)
{
  extern SCHEME_OBJECT * EXFUN (scan_frame,
				(SCHEME_OBJECT, SCHEME_OBJECT, SCHEME_OBJECT *,
				 long, Boolean));
  SCHEME_OBJECT target, source, sym;
  SCHEME_OBJECT cache, *cell, *value_cell;
  PRIMITIVE_HEADER (3);

  target = ARG_REF (1);
  source = ARG_REF (2);
  sym = ARG_REF (3);

  if (!SYMBOL_P(sym))
    error_wrong_type_arg(3);

  if (!VALID_ENVIRONMENT_P(source))
    error_bad_environment(2);

  if (!VALID_ENVIRONMENT_P(target))
    error_bad_environment(1);

  cache = extract_or_create_cache(source, sym);

  if (OBJECT_TYPE (target) == GLOBAL_ENV)
  {
    long trap_kind;
    SCHEME_OBJECT value;

    cell = MEMORY_LOC (sym, SYMBOL_GLOBAL_VALUE);
    value = MEMORY_FETCH (cell[0]);

    if (!REFERENCE_TRAP_P(value))
      /* The variable is bound! */
      signal_error_from_primitive(ERR_BAD_SET);

    get_trap_kind(trap_kind, value);
    switch(trap_kind)
    {
      case TRAP_UNBOUND:
      case TRAP_UNBOUND_DANGEROUS:
      {
	/* Allocate new trap object. */
	fast SCHEME_OBJECT *trap;

	Primitive_GC_If_Needed(2);
	trap = Free;
	Free += 2;
	trap[0] = LONG_TO_UNSIGNED_FIXNUM((trap_kind == TRAP_UNBOUND) ?
				       TRAP_COMPILER_CACHED :
				       TRAP_COMPILER_CACHED_DANGEROUS);
	trap[1] = cache;
	MEMORY_STORE (cell[0], MAKE_POINTER_OBJECT (TC_REFERENCE_TRAP, trap));
	PRIMITIVE_RETURN(SHARP_T);
      }

      case TRAP_COMPILER_CACHED:
      case TRAP_COMPILER_CACHED_DANGEROUS:
      {
	if (MEMORY_REF (MEMORY_REF (value, TRAP_EXTRA), TRAP_EXTENSION_CELL) !=
	    UNBOUND_OBJECT)
	{
	  /* It is bound */

	  signal_error_from_primitive(ERR_BAD_SET);
	}
	lookup_primitive_action(compiler_uncache(cell, sym));
	value_cell = MEMORY_LOC (cache, TRAP_EXTENSION_CELL);
	lookup_primitive_action
	  (compiler_recache(shadowed_value_cell, value_cell, target,
			    sym, MEMORY_FETCH (value_cell[0]), false, true));
	MEMORY_SET (value, TRAP_EXTRA, cache);
	PRIMITIVE_RETURN(SHARP_T);
      }

      case TRAP_DANGEROUS:
      case TRAP_UNASSIGNED:
      case TRAP_UNASSIGNED_DANGEROUS:
      case TRAP_FLUID:
      case TRAP_FLUID_DANGEROUS:
        /* The variable is bound! */
        signal_error_from_primitive(ERR_BAD_SET);

      default:
        signal_error_from_primitive(ERR_ILLEGAL_REFERENCE_TRAP);
    }
  }

  else
  {
    SCHEME_OBJECT *trap;

    cell = scan_frame(target, sym, fake_variable_object, 0, true);

    /* Is it bound? */

    if ((cell != ((SCHEME_OBJECT *) NULL)) &&
	(MEMORY_FETCH (cell[0]) != DANGEROUS_UNBOUND_OBJECT))
    {
      signal_error_from_primitive(ERR_BAD_SET);
    }

    /* Allocate new trap object. */

    Primitive_GC_If_Needed(2);
    trap = Free;
    Free += 2;
    trap[1] = cache;

    lookup_primitive_action(extend_frame(target, sym, SHARP_F, target, false));

    if (cell == ((SCHEME_OBJECT *) NULL))
    {
      trap[0] = LONG_TO_UNSIGNED_FIXNUM(TRAP_COMPILER_CACHED);
      cell = scan_frame(target, sym, fake_variable_object, 0, true);
      if (cell == ((SCHEME_OBJECT *) NULL))
	signal_error_from_primitive(ERR_BAD_FRAME);
    }
    else
    {
      trap[0] = LONG_TO_UNSIGNED_FIXNUM(TRAP_COMPILER_CACHED_DANGEROUS);
    }

    if (MEMORY_FETCH (cell[0]) != DANGEROUS_UNBOUND_OBJECT)
      signal_error_from_primitive(ERR_BAD_FRAME);

    value_cell = MEMORY_LOC (cache, TRAP_EXTENSION_CELL);
    lookup_primitive_action
      (compiler_recache(shadowed_value_cell, value_cell, target,
			sym, MEMORY_FETCH (value_cell[0]), false, true));
    MEMORY_STORE (cell[0], MAKE_POINTER_OBJECT (TC_REFERENCE_TRAP, trap));
    PRIMITIVE_RETURN(SHARP_T);
  }
}
