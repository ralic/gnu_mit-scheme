/* -*-C-*-

$Header: /Users/cph/tmp/foo/mit-scheme/mit-scheme/v7/src/microcode/comutl.c,v 1.15 1988/12/23 04:32:24 cph Exp $

Copyright (c) 1987, 1988 Massachusetts Institute of Technology

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

/* Compiled Code Utilities */

#include "scheme.h"
#include "prims.h"

extern Pointer
  *compiled_entry_to_block_address();

extern long
  compiled_entry_to_block_offset(),
  coerce_to_compiled();

extern void
  compiled_entry_type();

#define COMPILED_CODE_ADDRESS_P(object)			\
   ((OBJECT_TYPE (object)) == TC_COMPILED_ENTRY)

DEFINE_PRIMITIVE ("COMPILED-CODE-ADDRESS->BLOCK", Prim_comp_code_address_block, 1, 1,
  "Given a compiled code address, return its compiled code block.")
{
  PRIMITIVE_HEADER (1);

  CHECK_ARG (1, COMPILED_CODE_ADDRESS_P);
  PRIMITIVE_RETURN
    (Make_Pointer (TC_COMPILED_CODE_BLOCK,
		   (compiled_entry_to_block_address (ARG_REF (1)))));
}

DEFINE_PRIMITIVE ("COMPILED-CODE-ADDRESS->OFFSET", Prim_comp_code_address_offset, 1, 1,
  "Given a compiled code address, return its offset into its block.")
{
  PRIMITIVE_HEADER (1);

  CHECK_ARG (1, COMPILED_CODE_ADDRESS_P);
  PRIMITIVE_RETURN
    (MAKE_SIGNED_FIXNUM (compiled_entry_to_block_offset (ARG_REF (1))));
}

#ifndef USE_STACKLETS

DEFINE_PRIMITIVE ("STACK-TOP-ADDRESS", Prim_stack_top_address, 0, 0, 0)
{
  PRIMITIVE_HEADER (0);

  PRIMITIVE_RETURN (C_Integer_To_Scheme_Integer (OBJECT_DATUM (Stack_Top)));
}

#define STACK_ADDRESS_P(object)						\
   ((OBJECT_TYPE (object)) == TC_STACK_ENVIRONMENT)

DEFINE_PRIMITIVE ("STACK-ADDRESS-OFFSET", Prim_stack_address_offset, 1, 1, 0)
{
  PRIMITIVE_HEADER (1);

  CHECK_ARG (1, STACK_ADDRESS_P);
  PRIMITIVE_RETURN
    (C_Integer_To_Scheme_Integer
     ((STACK_LOCATIVE_DIFFERENCE
       ((OBJECT_DATUM (ARG_REF (1))), (OBJECT_DATUM (Stack_Top))))
      / (sizeof (Pointer))));
}

#endif /* USE_STACKLETS */

DEFINE_PRIMITIVE ("COMPILED-ENTRY-KIND", Prim_compiled_entry_type, 1, 1, 0)
{
  fast Pointer *temp;
  Pointer result;
  PRIMITIVE_HEADER(1);

  CHECK_ARG (1, COMPILED_CODE_ADDRESS_P);

  Primitive_GC_If_Needed(3);
  temp = Free;
  Free = &temp[3];
  compiled_entry_type(ARG_REF(1), temp);
  temp[0] = MAKE_UNSIGNED_FIXNUM(((long) temp[0]));
  temp[1] = MAKE_SIGNED_FIXNUM(((long) temp[1]));
  temp[2] = MAKE_SIGNED_FIXNUM(((long) temp[2]));
  PRIMITIVE_RETURN (Make_Pointer(TC_HUNK3, temp));
}

DEFINE_PRIMITIVE ("COERCE-TO-COMPILED-PROCEDURE", Prim_coerce_to_closure, 2, 2, 0)
{
  Pointer temp;
  long value, result;
  PRIMITIVE_HEADER(2);

  CHECK_ARG (2, FIXNUM_P);

  FIXNUM_VALUE(ARG_REF(2), value);
  result = coerce_to_compiled(ARG_REF(1), value, &temp);
  switch(result)
  {
    case PRIM_DONE:
      PRIMITIVE_RETURN(temp);

    case PRIM_INTERRUPT:
      Primitive_GC(10);
      /*NOTREACHED*/
      
    default:
      Primitive_Error(ERR_ARG_2_BAD_RANGE);
      /*NOTREACHED*/
  }
}

DEFINE_PRIMITIVE ("COMPILED-CLOSURE->ENTRY", Prim_compiled_closure_to_entry, 1, 1,
  "Given a compiled closure, return the entry point which it invokes.")
{
  Pointer entry_type [3];
  Pointer closure;
  extern void compiled_entry_type ();
  extern long compiled_entry_manifest_closure_p ();
  extern Pointer compiled_closure_to_entry ();
  PRIMITIVE_HEADER (1);

  CHECK_ARG (1, COMPILED_CODE_ADDRESS_P);
  closure = (ARG_REF (1));
  compiled_entry_type (closure, (& entry_type));
  if (! (((entry_type [0]) == 0) &&
	 (compiled_entry_manifest_closure_p (closure))))
    error_bad_range_arg (1);
  PRIMITIVE_RETURN (compiled_closure_to_entry (closure));
}
