/* -*-C-*-

$Header: /Users/cph/tmp/foo/mit-scheme/mit-scheme/v7/src/microcode/Attic/bintopsb.c,v 9.50 1992/02/11 21:14:38 mhwu Exp $

Copyright (c) 1987-1992 Massachusetts Institute of Technology

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

/* This File contains the code to translate internal format binary
   files to portable format. */

/* IO definitions */

#include "psbmap.h"
#include "trap.h"
#include "limits.h"
#define internal_file input_file
#define portable_file output_file

long
DEFUN (Load_Data, (Count, To_Where),
       long Count AND
       SCHEME_OBJECT *To_Where)
{
  return (fread (((char *) To_Where),
		 (sizeof (SCHEME_OBJECT)),
		 Count,
		 internal_file));
}

#define INHIBIT_FASL_VERSION_CHECK
#define INHIBIT_COMPILED_VERSION_CHECK
#define INHIBIT_CHECKSUMS
#include "load.c"
#include "bltdef.h"

/* Character macros and procedures */

extern int strlen ();

#ifndef isalpha

/* Just in case the stdio library atypically contains the character
   macros, just like the C book claims. */

#include <ctype.h>

#endif /* isalpha */

#ifndef ispunct

/* This is in some libraries but not others */

static char
  punctuation[] = "'\",<.>/?;:{}[]|`~=+-_()*&^%$#@!";

Boolean
DEFUN (ispunct, (c),
       fast char c)
{
  fast char *;

  s = &punctuation[0];
  while (*s != '\0')
  {
    if (*s++ == c)
    {
      return (true);
    }
  }
  return (false);
}

#endif /* ispunct */

/* Global data */

/* Needed to upgrade */
#define TC_PRIMITIVE_EXTERNAL	0x10

#define STRING_LENGTH_TO_LONG(value)					\
  ((long) (upgrade_lengths_p ? (OBJECT_DATUM (value)) : (value)))

static Boolean
  allow_compiled_p = false,
  allow_nmv_p = false,
  shuffle_bytes_p = false,
  swap_bytes_p = false,
  upgrade_compiled_p = false,
  upgrade_lengths_p = false,
  upgrade_primitives_p = false,
  upgrade_traps_p = false,
  vax_invert_p = false;

static long
  Heap_Relocation, Constant_Relocation,
  Free, Scan, Free_Constant, Scan_Constant,
  Objects, Constant_Objects;

static SCHEME_OBJECT
  *Mem_Base,
  *Free_Objects, *Free_Cobjects,
  *compiled_entry_table, *compiled_entry_pointer,
  *compiled_entry_table_end,
  *primitive_table, *primitive_table_end;

static long
  NFlonums,
  NIntegers, NBits,
  NBitstrs, NBBits,
  NStrings, NChars,
  NPChars;

#define OUT(s)								\
{									\
  fprintf(portable_file, (s));						\
  break;								\
}

void
DEFUN (print_a_char, (c, name),
       fast char c AND
       char *name)
{
  switch(c)
  {
    case '\n': OUT("\\n");
    case '\t': OUT("\\t");
    case '\b': OUT("\\b");
    case '\r': OUT("\\r");
    case '\f': OUT("\\f");
    case '\\': OUT("\\\\");
    case '\0': OUT("\\0");
    case ' ' : OUT(" ");

    default:
    if ((isascii(c)) && ((isalpha(c)) || (isdigit(c)) || (ispunct(c))))
    {
      putc(c, portable_file);
    }
    else
    {
      unsigned int x = (((int) c) & ((1 << CHAR_BIT) - 1));
      fprintf(stderr,
	      "%s: %s: File may not be portable: c = 0x%x\n",
	      program_name, name, x);
      /* This does not follow C conventions, but eliminates ambiguity */
      fprintf(portable_file, "\\X%d ", x);
    }
  }
  return;
}

#undef MAKE_BROKEN_HEART
#define MAKE_BROKEN_HEART(offset) (BROKEN_HEART_ZERO + (offset))

#define Do_Compound(Code, Rel, Fre, Scn, Obj, FObj, kernel_code)	\
{									\
  Old_Address += (Rel);							\
  Old_Contents = (*Old_Address);					\
  if (BROKEN_HEART_P (Old_Contents))					\
    (Mem_Base [(Scn)]) = (OBJECT_NEW_TYPE ((Code), Old_Contents));	\
  else									\
  {									\
    kernel_code;							\
  }									\
}

#define standard_kernel(kernel_code, type, Code, Scn, Obj, FObj)	\
{									\
  (Mem_Base [(Scn)]) = (MAKE_OBJECT ((Code), (Obj)));			\
  {									\
    fast long length = (OBJECT_DATUM (Old_Contents));			\
    kernel_code;							\
    (*Old_Address++) = (MAKE_BROKEN_HEART (Obj));			\
    (Obj) += 1;								\
    (*(FObj)++) = (MAKE_OBJECT ((type), 0));				\
    (*(FObj)++) = Old_Contents;						\
    while ((length--) > 0)						\
      (*(FObj)++) = (*Old_Address++);					\
  }									\
}

#define do_string_kernel()						\
{									\
  NStrings += 1;							\
  NChars += (pointer_to_char (length - 1));				\
}

#define do_bignum_kernel()						\
{									\
  NIntegers += 1;							\
  NBits +=								\
    (((* ((bignum_digit_type *) (Old_Address + 1)))			\
      & BIGNUM_DIGIT_MASK)						\
     * BIGNUM_DIGIT_LENGTH);						\
}

#define do_bit_string_kernel()						\
{									\
  NBitstrs += 1;							\
  NBBits += (Old_Address [BIT_STRING_LENGTH_OFFSET]);			\
}

#define do_flonum_kernel(Code, Scn, Obj, FObj)				\
{									\
  (Mem_Base [(Scn)]) = (MAKE_OBJECT ((Code), (Obj)));			\
  NFlonums += 1;							\
  (*Old_Address++) = (MAKE_BROKEN_HEART (Obj));				\
  (Obj) += 1;								\
  ALIGN_FLOAT (FObj);							\
  (*(FObj)++) = (MAKE_OBJECT (TC_BIG_FLONUM, 0));			\
  (* ((double *) (FObj))) = (* ((double *) Old_Address));		\
  (FObj) += float_to_pointer;						\
}

#define Do_String(Code, Rel, Fre, Scn, Obj, FObj)			\
  Do_Compound (Code, Rel, Fre, Scn, Obj, FObj,				\
	       standard_kernel (do_string_kernel (),			\
				TC_CHARACTER_STRING,			\
				Code, Scn, Obj, FObj))

#define Do_Bignum(Code, Rel, Fre, Scn, Obj, FObj)			\
  Do_Compound (Code, Rel, Fre, Scn, Obj, FObj,				\
	       standard_kernel (do_bignum_kernel (), TC_BIG_FIXNUM,	\
				Code, Scn, Obj, FObj))

#define Do_Bit_String(Code, Rel, Fre, Scn, Obj, FObj)			\
  Do_Compound (Code, Rel, Fre, Scn, Obj, FObj,				\
	       standard_kernel (do_bit_string_kernel (), TC_BIT_STRING,	\
				Code, Scn, Obj, FObj))

#define Do_Flonum(Code, Rel, Fre, Scn, Obj, FObj)			\
  Do_Compound (Code, Rel, Fre, Scn, Obj, FObj,				\
	       do_flonum_kernel (Code, Scn, Obj, FObj))

void
DEFUN (print_a_fixnum, (val),
       long val)
{
  fast long size_in_bits;
  fast unsigned long temp;

  temp = ((val < 0) ? -val : val);
  for (size_in_bits = 0; temp != 0; size_in_bits += 1)
  {
    temp = temp >> 1;
  }
  fprintf(portable_file, "%02x %c ",
	  TC_FIXNUM,
	  (val < 0 ? '-' : '+'));
  if (val == 0)
  {
    fprintf(portable_file, "0\n");
  }
  else
  {
    fprintf(portable_file, "%ld ", size_in_bits);
    temp = ((val < 0) ? -val : val);
    while (temp != 0)
    {
      fprintf(portable_file, "%01lx", (temp & 0xf));
      temp = temp >> 4;
    }
    fprintf(portable_file, "\n");
  }
  return;
}

void
DEFUN (print_a_string_internal, (len, str),
       fast long len AND
       fast char *str)
{
  fprintf(portable_file, "%ld ", len);
  if (shuffle_bytes_p)
  {
    while(len > 0)
    {
      print_a_char(str[3], "print_a_string");
      if (len > 1)
      {
	print_a_char(str[2], "print_a_string");
      }
      if (len > 2)
      {
	print_a_char(str[1], "print_a_string");
      }
      if (len > 3)
      {
	print_a_char(str[0], "print_a_string");
      }
      len -= 4;
      str += 4;
    }
  }
  else
  {
    while(--len >= 0)
    {
      print_a_char(*str++, "print_a_string");
    }
  }
  putc('\n', portable_file);
  return;
}

void
DEFUN (print_a_string, (from),
       SCHEME_OBJECT *from)
{
  long len;
  long maxlen;

  maxlen = (pointer_to_char ((OBJECT_DATUM (*from++)) - 1));
  len = (STRING_LENGTH_TO_LONG (*from++));

  fprintf (portable_file,
	   "%02x %ld ",
	   TC_CHARACTER_STRING,
	   (compact_p ? len : maxlen));

  print_a_string_internal (len, ((char *) from));
  return;
}

void
DEFUN (print_a_primitive, (arity, length, name),
       long arity AND
       long length AND
       char *name)
{
  fprintf (portable_file, "%ld ", arity);
  print_a_string_internal (length, name);
  return;
}

static long
DEFUN (bignum_length, (bignum),
       SCHEME_OBJECT bignum)
{
  if (BIGNUM_ZERO_P (bignum))
    return (0);
  {
    bignum_length_type index = ((BIGNUM_LENGTH (bignum)) - 1);
    fast bignum_digit_type digit = (BIGNUM_REF (bignum, index));
    fast long result;
    if (index >= (LONG_MAX / BIGNUM_DIGIT_LENGTH))
      goto loser;
    result = (index * BIGNUM_DIGIT_LENGTH);
    while (digit > 0)
      {
	result += 1;
	if (result >= LONG_MAX)
	  goto loser;
	digit >>= 1;
      }
    return (result);
  }
 loser:
  fprintf (stderr, "%s: Bignum exceeds representable length.\n",
	   program_name);
  quit (1);
  /* NOTREACHED */
}

void
DEFUN (print_a_bignum, (bignum_ptr),
       SCHEME_OBJECT *bignum_ptr)
{
  SCHEME_OBJECT bignum;

  bignum = (MAKE_POINTER_OBJECT (TC_BIG_FIXNUM, bignum_ptr));

  if (BIGNUM_ZERO_P (bignum))
    {
      fprintf (portable_file, "%02x + 0\n",
	       (compact_p ? TC_FIXNUM : TC_BIG_FIXNUM));
      return;
    }
  {
    bignum_digit_type * scan = (BIGNUM_START_PTR (bignum));
    fast long length_in_bits = (bignum_length (bignum));
    fast int bits_in_digit = 0;
    fast bignum_digit_type accumulator;
    fprintf (portable_file, "%02x %c %ld ",
	     (compact_p ? TC_FIXNUM : TC_BIG_FIXNUM),
	     ((BIGNUM_NEGATIVE_P (bignum)) ? '-' : '+'),
	     length_in_bits);
    accumulator = (*scan++);
    bits_in_digit =
      ((length_in_bits < BIGNUM_DIGIT_LENGTH)
       ? length_in_bits
       : BIGNUM_DIGIT_LENGTH);
    while (length_in_bits > 0)
      {
	if (bits_in_digit > 4)
	  {
	    fprintf (portable_file, "%01lx", (accumulator & 0xf));
	    length_in_bits -= 4;
	    accumulator >>= 4;
	    bits_in_digit -= 4;
	  }
	else if (bits_in_digit == 4)
	  {
	    fprintf (portable_file, "%01lx", accumulator);
	    length_in_bits -= 4;
	    if (length_in_bits >= BIGNUM_DIGIT_LENGTH)
	      {
		accumulator = (*scan++);
		bits_in_digit = BIGNUM_DIGIT_LENGTH;
	      }
	    else if (length_in_bits > 0)
	      {
		accumulator = (*scan++);
		bits_in_digit = length_in_bits;
	      }
	    else
	      break;
	  }
	else if (bits_in_digit < length_in_bits)
	  {
	    int carry = accumulator;
	    int diff_bits = (4 - bits_in_digit);
	    accumulator = (*scan++);
	    fprintf (portable_file, "%01lx",
		     (carry |
		      ((accumulator & ((1 << diff_bits) - 1)) <<
		       bits_in_digit)));
	    length_in_bits -= 4;
	    bits_in_digit = (BIGNUM_DIGIT_LENGTH - diff_bits);
	    if (length_in_bits >= bits_in_digit)
	      accumulator >>= diff_bits;
	    else if (length_in_bits > 0)
	      {
		accumulator >>= diff_bits;
		bits_in_digit = length_in_bits;
	      }
	    else
	      break;
	  }
	else
	  {
	    fprintf (portable_file, "%01lx", accumulator);
	    break;
	  }
      }
  }
  fprintf (portable_file, "\n");
}

/* The following procedure assumes that a C long is at least 4 bits. */

void
DEFUN (print_a_bit_string, (from),
       SCHEME_OBJECT *from)
{
  SCHEME_OBJECT the_bit_string;
  fast long bits_remaining, leftover_bits;
  fast SCHEME_OBJECT accumulator, next_word, *scan;

  the_bit_string = (MAKE_POINTER_OBJECT (TC_BIT_STRING, from));
  bits_remaining = (BIT_STRING_LENGTH (the_bit_string));
  fprintf(portable_file, "%02x %ld", TC_BIT_STRING, bits_remaining);

  if (bits_remaining != 0)
  {
    fprintf(portable_file, " ");
    scan = BIT_STRING_LOW_PTR(the_bit_string);
    for (leftover_bits = 0;
	 bits_remaining > 0;
	 bits_remaining -= OBJECT_LENGTH)
    {
      next_word = *(INC_BIT_STRING_PTR(scan));

      if (bits_remaining < OBJECT_LENGTH)
	next_word &= LOW_MASK(bits_remaining);

      if (leftover_bits != 0)
      {
	accumulator &= LOW_MASK(leftover_bits);
	accumulator |=
	  ((next_word & LOW_MASK(4 - leftover_bits)) << leftover_bits);
	next_word = (next_word >> (4 - leftover_bits));
	leftover_bits += ((bits_remaining > OBJECT_LENGTH) ?
			  (OBJECT_LENGTH - 4) :
			  (bits_remaining - 4));
	fprintf(portable_file, "%01lx", (accumulator & 0xf));
      }
      else
      {
	leftover_bits = ((bits_remaining > OBJECT_LENGTH) ?
			 OBJECT_LENGTH :
			 bits_remaining);
      }

      for(accumulator = next_word; leftover_bits >= 4; leftover_bits -= 4)
      {
	fprintf(portable_file, "%01lx", (accumulator & 0xf));
	accumulator = accumulator >> 4;
      }
    }
    if (leftover_bits != 0)
    {
      fprintf(portable_file, "%01lx", (accumulator & 0xf));
    }
  }
  fprintf(portable_file, "\n");
  return;
}

void
DEFUN (print_a_flonum, (val),
       double val)
{
  fast long size_in_bits;
  fast double mant, temp;
  int expt;
  extern double frexp();

  fprintf(portable_file, "%02x %c ",
	  TC_BIG_FLONUM,
	  ((val < 0.0) ? '-' : '+'));
  if (val == 0.0)
  {
    fprintf(portable_file, "0\n");
    return;
  }
  mant = frexp(((val < 0.0) ? -val : val), &expt);
  size_in_bits = 1;

  for(temp = ((mant * 2.0) - 1.0);
      temp != 0;
      size_in_bits += 1)
  {
    temp *= 2.0;
    if (temp >= 1.0)
      temp -= 1.0;
  }
  fprintf(portable_file, "%ld %ld ", expt, size_in_bits);

  for (size_in_bits = hex_digits(size_in_bits);
       size_in_bits > 0;
       size_in_bits -= 1)
  {
    fast unsigned int digit;

    digit = 0;
    for (expt = 4; --expt >= 0;)
    {
      mant *= 2.0;
      digit = digit << 1;
      if (mant >= 1.0)
      {
	mant -= 1.0;
	digit += 1;
      }
    }
    fprintf(portable_file, "%01x", digit);
  }
  putc('\n', portable_file);
  return;
}

/* Normal Objects */

#define Do_Cell(Code, Rel, Fre, Scn, Obj, FObj)				\
{									\
  Old_Address += (Rel);							\
  Old_Contents = (*Old_Address);					\
  if (BROKEN_HEART_P (Old_Contents))					\
    (Mem_Base [(Scn)]) =						\
      (MAKE_OBJECT_FROM_OBJECTS (This, Old_Contents));			\
  else									\
    {									\
      (*Old_Address++) = (MAKE_BROKEN_HEART (Fre));			\
      (Mem_Base [(Scn)]) = (OBJECT_NEW_DATUM (This, (Fre)));		\
      (Mem_Base [(Fre)++]) = Old_Contents;				\
    }									\
}

#define Do_Pair(Code, Rel, Fre, Scn, Obj, FObj)				\
{									\
  Old_Address += (Rel);							\
  Old_Contents = (*Old_Address);					\
  if (BROKEN_HEART_P (Old_Contents))					\
    (Mem_Base [(Scn)]) =						\
      (MAKE_OBJECT_FROM_OBJECTS (This, Old_Contents));			\
  else									\
    {									\
      (*Old_Address++) = (MAKE_BROKEN_HEART (Fre));			\
      (Mem_Base [(Scn)]) = (OBJECT_NEW_DATUM (This, (Fre)));		\
      (Mem_Base [(Fre)++]) = Old_Contents;				\
      (Mem_Base [(Fre)++]) = (*Old_Address++);				\
    }									\
}

#define Do_Triple(Code, Rel, Fre, Scn, Obj, FObj)			\
{									\
  Old_Address += (Rel);							\
  Old_Contents = (*Old_Address);					\
  if (BROKEN_HEART_P (Old_Contents))					\
    (Mem_Base [(Scn)]) =						\
      (MAKE_OBJECT_FROM_OBJECTS (This, Old_Contents));			\
  else									\
    {									\
      (*Old_Address++) = (MAKE_BROKEN_HEART (Fre));			\
      (Mem_Base [(Scn)]) = (OBJECT_NEW_DATUM (This, (Fre)));		\
      (Mem_Base [(Fre)++]) = Old_Contents;				\
      (Mem_Base [(Fre)++]) = (*Old_Address++);				\
      (Mem_Base [(Fre)++]) = (*Old_Address++);				\
    }									\
}

#define Do_Quad(Code, Rel, Fre, Scn, Obj, FObj)				\
{									\
  Old_Address += (Rel);							\
  Old_Contents = (*Old_Address);					\
  if (BROKEN_HEART_P (Old_Contents))					\
    (Mem_Base [(Scn)]) =						\
      (MAKE_OBJECT_FROM_OBJECTS (This, Old_Contents));			\
  else									\
    {									\
      (*Old_Address++) = (MAKE_BROKEN_HEART (Fre));			\
      (Mem_Base [(Scn)]) = (OBJECT_NEW_DATUM (This, (Fre)));		\
      (Mem_Base [(Fre)++]) = Old_Contents;				\
      (Mem_Base [(Fre)++]) = (*Old_Address++);				\
      (Mem_Base [(Fre)++]) = (*Old_Address++);				\
      (Mem_Base [(Fre)++]) = (*Old_Address++);				\
    }									\
}

#define Copy_Vector(Scn, Fre)						\
{									\
  fast long len = (OBJECT_DATUM (Old_Contents));			\
  (*Old_Address++) = (MAKE_BROKEN_HEART (Fre));				\
  (Mem_Base [(Fre)++]) = Old_Contents;					\
  while ((len--) > 0)							\
    (Mem_Base [(Fre)++]) = (*Old_Address++);				\
}

#define Do_Vector(Code, Rel, Fre, Scn, Obj, FObj)			\
{									\
  Old_Address += (Rel);							\
  Old_Contents = (*Old_Address);					\
  if (BROKEN_HEART_P (Old_Contents))					\
    (Mem_Base [(Scn)]) =						\
      (MAKE_OBJECT_FROM_OBJECTS (This, Old_Contents));			\
  else									\
    {									\
      (Mem_Base [(Scn)]) = (OBJECT_NEW_DATUM (This, (Fre)));		\
      Copy_Vector (Scn, Fre);						\
    }									\
}

/* This is a hack to get the cross compiler to work from vaxen to other
   machines and viceversa. */

#define Do_Inverted_Block(Code, Rel, Fre, Scn, Obj, FObj)		\
{									\
  Old_Address += (Rel);							\
  Old_Contents = (*Old_Address);					\
  if (BROKEN_HEART_P (Old_Contents))					\
    (Mem_Base [(Scn)]) =						\
      (MAKE_OBJECT_FROM_OBJECTS (This, Old_Contents));			\
  else									\
    {									\
      fast long len1, len2;						\
      SCHEME_OBJECT * Saved;						\
      (Mem_Base [(Scn)]) = (OBJECT_NEW_DATUM (This, (Fre)));		\
      len1 = (OBJECT_DATUM (Old_Contents));				\
      (*Old_Address++) = (MAKE_BROKEN_HEART (Fre));			\
      (Mem_Base [(Fre)++]) = Old_Contents;				\
      if ((OBJECT_TYPE (*Old_Address)) != TC_MANIFEST_NM_VECTOR)	\
	{								\
	  fprintf (stderr, "%s: Bad compiled code block found.\n",	\
		  program_name);					\
	  quit (1);							\
	}								\
      len2 = (OBJECT_DATUM (*Old_Address));				\
      (Mem_Base [(Fre)++]) = (*Old_Address++);				\
      Old_Address += len2;						\
      Saved = Old_Address;						\
      len1 -= (len2 + 1);						\
      while ((len2--) > 0)						\
	(Mem_Base [(Fre)++]) = (*--Old_Address);			\
      Old_Address = Saved;						\
      while ((len1--) > 0)						\
	(Mem_Base [(Fre)++]) = (*Old_Address++);			\
    }									\
}

#ifdef HAS_COMPILER_SUPPORT

#define Do_Compiled_Entry(Code, Rel, Fre, Scn, Obj, FObj)		\
{									\
  long offset;								\
  SCHEME_OBJECT * saved;						\
  Old_Address += (Rel);							\
  saved = Old_Address;							\
  Get_Compiled_Block (Old_Address, saved);				\
  Old_Contents = (*Old_Address);					\
  (Mem_Base [(Scn)]) =							\
   (MAKE_OBJECT								\
    (TC_COMPILED_ENTRY,							\
     (compiled_entry_pointer - compiled_entry_table)));			\
  offset = (((char *) saved) - ((char *) Old_Address));			\
  (*compiled_entry_pointer++) = (LONG_TO_FIXNUM (offset));		\
  /* Base pointer */							\
  if (BROKEN_HEART_P (Old_Contents))					\
    (*compiled_entry_pointer++) =					\
      (MAKE_OBJECT_FROM_OBJECTS (This, Old_Contents));			\
  else									\
    {									\
      (*compiled_entry_pointer++) =					\
	(MAKE_OBJECT_FROM_OBJECTS (This, (Fre)));			\
      Copy_Vector (Scn, Fre);						\
    }									\
}

#else /* no HAS_COMPILER_SUPPORT */

#define Do_Compiled_Entry(Code, Rel, Fre, Scn, Obj, FObj)		\
{									\
  fprintf								\
    (stderr,								\
     "%s: Invoking Do_Compiled_Entry with no compiler support!\n",	\
     program_name);							\
  quit (1);								\
}

#endif /* HAS_COMPILER_SUPPORT */

/* Common Pointer Code */

#define Do_Pointer(Scn, Action)						\
{									\
  long the_datum;							\
									\
  Old_Address = (OBJECT_ADDRESS (This));				\
  the_datum = (OBJECT_DATUM (This));					\
  if ((the_datum >= Heap_Base) &&					\
      (the_datum < Dumped_Heap_Top))					\
    {									\
      Action								\
	(HEAP_CODE, Heap_Relocation, Free,				\
	 Scn, Objects, Free_Objects);					\
    }									\
  /* Currently constant space is not supported				\
  else if ((the_datum >= Const_Base) &&					\
	   (the_datum < Dumped_Constant_Top))				\
    {									\
      Action								\
	(CONSTANT_CODE, Constant_Relocation, Free_Constant,		\
	 Scn, Constant_Objects, Free_Cobjects);				\
    }									\
    */									\
  else									\
    {									\
      out_of_range_pointer (This);					\
    }									\
  (Scn) += 1;								\
  break;								\
}

void
DEFUN (out_of_range_pointer, (ptr),
       SCHEME_OBJECT ptr)
{
  fprintf(stderr,
	  "%s: The input file is not portable: Out of range pointer.\n",
	  program_name);
  fprintf(stderr, "Heap_Base =  0x%lx;\tHeap_Top = 0x%lx\n",
	  Heap_Base, Dumped_Heap_Top);
  fprintf(stderr, "Const_Base = 0x%lx;\tConst_Top = 0x%lx\n",
	  Const_Base, Dumped_Constant_Top);
  fprintf(stderr, "ptr = 0x%02x|0x%lx\n",
	  OBJECT_TYPE (ptr), OBJECT_DATUM (ptr));
  quit(1);
}

SCHEME_OBJECT *
DEFUN (relocate, (object),
       SCHEME_OBJECT object)
{
  long the_datum;
  SCHEME_OBJECT *result;

  result = OBJECT_ADDRESS (object);
  the_datum = OBJECT_DATUM (object);

  if ((the_datum >= Heap_Base) &&
      (the_datum < Dumped_Heap_Top))
  {
    result += Heap_Relocation;
  }

#if FALSE

  /* Currently constant space is not supported */

  else if (( the_datum >= Const_Base) &&
	   (the_datum < Dumped_Constant_Top))
  {
    result += Constant_Relocation;
  }

#endif /* false */

  else
  {
    out_of_range_pointer(object);
  }
  return (result);
}

/* Primitive upgrading code. */

#define PRIMITIVE_UPGRADE_SPACE 2048

static SCHEME_OBJECT
  *internal_renumber_table,
  *external_renumber_table,
  *external_prim_name_table;

static Boolean
  found_ext_prims = false;

SCHEME_OBJECT
DEFUN (upgrade_primitive, (prim),
       SCHEME_OBJECT prim)
{
  long the_datum, the_type, new_type, code;
  SCHEME_OBJECT new;

  the_datum = OBJECT_DATUM (prim);
  the_type = OBJECT_TYPE (prim);
  if (the_type != TC_PRIMITIVE_EXTERNAL)
  {
    code = the_datum;
    new_type = the_type;
  }
  else
  {
    found_ext_prims = true;
    code = (the_datum + (MAX_BUILTIN_PRIMITIVE + 1));
    new_type = TC_PRIMITIVE;
  }

  new = internal_renumber_table[code];
  if (new == SHARP_F)
  {
    /*
      This does not need to check for overflow because the worst case
      was checked in setup_primitive_upgrade;
     */

    new = (MAKE_OBJECT (new_type, Primitive_Table_Length));
    internal_renumber_table[code] = new;
    external_renumber_table[Primitive_Table_Length] = prim;
    Primitive_Table_Length += 1;
    if (the_type == TC_PRIMITIVE_EXTERNAL)
    {
      NPChars +=
	STRING_LENGTH_TO_LONG((((SCHEME_OBJECT *)
				(external_prim_name_table[the_datum]))
			       [STRING_LENGTH_INDEX]));
    }
    else
    {
      NPChars += strlen(builtin_prim_name_table[the_datum]);
    }
    return (new);
  }
  else
  {
    return (OBJECT_NEW_TYPE (new_type, new));
  }
}

SCHEME_OBJECT *
DEFUN (setup_primitive_upgrade, (Heap),
       SCHEME_OBJECT *Heap)
{
  fast long count, length;
  SCHEME_OBJECT *old_prims_vector;

  internal_renumber_table = &Heap[0];
  external_renumber_table =
    &internal_renumber_table[PRIMITIVE_UPGRADE_SPACE];
  external_prim_name_table =
    &external_renumber_table[PRIMITIVE_UPGRADE_SPACE];

  old_prims_vector = relocate(Ext_Prim_Vector);
  if (*old_prims_vector == SHARP_F)
  {
    length = 0;
  }
  else
  {
    old_prims_vector = relocate(*old_prims_vector);
    length = OBJECT_DATUM (*old_prims_vector);
    old_prims_vector += VECTOR_DATA;
    for (count = 0; count < length; count += 1)
    {
      SCHEME_OBJECT *temp;

      /* symbol */
      temp = relocate(old_prims_vector[count]);
      /* string */
      temp = relocate(temp[SYMBOL_NAME]);
      external_prim_name_table[count] = ((SCHEME_OBJECT) temp);
    }
  }
  length += (MAX_BUILTIN_PRIMITIVE + 1);
  if (length > PRIMITIVE_UPGRADE_SPACE)
  {
    fprintf(stderr, "%s: Too many primitives.\n", program_name);
    fprintf(stderr,
	    "Increase PRIMITIVE_UPGRADE_SPACE and recompile %s.\n",
	    program_name);
    quit(1);
  }
  for (count = 0; count < length; count += 1)
  {
    internal_renumber_table[count] = SHARP_F;
  }
  NPChars = 0;
  return (&external_prim_name_table[PRIMITIVE_UPGRADE_SPACE]);
}

/* Processing of a single area */

#define Do_Area(Code, Area, Bound, Obj, FObj)		\
  Process_Area (Code, &Area, &Bound, &Obj, &FObj)

void
DEFUN (Process_Area, (Code, Area, Bound, Obj, FObj),
       int Code AND
       fast long *Area AND
       fast long *Bound AND
       fast long *Obj AND
       fast SCHEME_OBJECT **FObj)
{
  fast SCHEME_OBJECT This, *Old_Address, Old_Contents;

  while(*Area != *Bound)
  {
    This = Mem_Base[*Area];

#ifdef PRIMITIVE_EXTERNAL_REUSED
    if (upgrade_primitives_p &&
	(OBJECT_TYPE (This) == TC_PRIMITIVE_EXTERNAL))
    {
      Mem_Base[*Area] = upgrade_primitive(This);
      *Area += 1;
      continue;
    }
#endif /* PRIMITIVE_EXTERNAL_REUSED */

    Switch_by_GC_Type(This)
    {

#ifndef PRIMITIVE_EXTERNAL_REUSED

      case TC_PRIMITIVE_EXTERNAL:

#endif /* PRIMITIVE_EXTERNAL_REUSED */

      case TC_PRIMITIVE:
      case TC_PCOMB0:
	if (upgrade_primitives_p)
	{
	  Mem_Base[*Area] = upgrade_primitive(This);
	}
	*Area += 1;
	break;

      case TC_MANIFEST_NM_VECTOR:
	nmv_p = true;
        if (null_nmv_p)
	{
	  fast int i;

	  i = OBJECT_DATUM (This);
	  *Area += 1;
	  for ( ; --i >= 0; *Area += 1)
	  {
	    Mem_Base[*Area] = SHARP_F;
	  }
	  break;
	}
	else if (!allow_nmv_p)
	{
	  fprintf(stderr, "%s: File is not portable: NMH found\n",
		  program_name);
	}
	*Area += (1 + OBJECT_DATUM (This));
	break;

      case TC_BROKEN_HEART:
	/* [Broken Heart 0] is the cdr of fasdumped symbols. */
	if (OBJECT_DATUM (This) != 0)
	{
	  fprintf(stderr, "%s: Broken Heart found in scan.\n",
		  program_name);
	  quit(1);
	}
	*Area += 1;
	break;

      case TC_MANIFEST_CLOSURE:
      case TC_LINKAGE_SECTION:
      {
	fprintf(stderr,
		"%s: File contains linked compiled code.\n",
		program_name);
	quit(1);
      }


      case TC_COMPILED_CODE_BLOCK:
	compiled_p = true;
	if (vax_invert_p)
	{
	  Do_Pointer(*Area, Do_Inverted_Block);
	}
	else if (allow_compiled_p)
	{
	  Do_Pointer(*Area, Do_Vector);
	}
	else
	{
	  fprintf(stderr,
		  "%s: File contains compiled code.\n",
		  program_name);
	  quit(1);
	}

      case_compiled_entry_point:
	compiled_p = true;
	if (!allow_compiled_p)
	{
	  fprintf(stderr,
		  "%s: File contains compiled code.\n",
		  program_name);
	  quit(1);
	}
	Do_Pointer(*Area, Do_Compiled_Entry);

      case TC_STACK_ENVIRONMENT:
	fprintf(stderr,
		"%s: File contains stack environments.\n",
		program_name);
	quit(1);

      case TC_FIXNUM:
	NIntegers += 1;
	NBits += fixnum_to_bits;
	/* Fall Through */

      case TC_CHARACTER:
      Process_Character:
        Mem_Base[*Area] = (MAKE_OBJECT (Code, *Obj));
        *Obj += 1;
        **FObj = This;
        *FObj += 1;
	/* Fall through */

      case TC_MANIFEST_SPECIAL_NM_VECTOR:
      case_simple_Non_Pointer:
	*Area += 1;
	break;

      case TC_REFERENCE_TRAP:
      {
	long kind;

	kind = OBJECT_DATUM (This);

	if (upgrade_traps_p)
	{
	  /* It is an old UNASSIGNED object. */
	  if (kind == 0)
	  {
	    Mem_Base[*Area] = UNASSIGNED_OBJECT;
	    *Area += 1;
	    break;
	  }
	  if (kind == 1)
	  {
	    Mem_Base[*Area] = UNBOUND_OBJECT;
	    *Area += 1;
	    break;
	  }
	  fprintf(stderr,
		  "%s: Bad old unassigned object. 0x%x.\n",
		  program_name, This);
	  quit(1);
	}
	if (kind <= TRAP_MAX_IMMEDIATE)
	{
	  /* It is a non pointer. */

	  *Area += 1;
	  break;
	}
      }
      /* Fall through */

      case TC_WEAK_CONS:
      case_Pair:
	Do_Pointer(*Area, Do_Pair);

      case_Cell:
	Do_Pointer(*Area, Do_Cell);

      case TC_VARIABLE:
      case_Triple:
	Do_Pointer(*Area, Do_Triple);

      case TC_BIG_FLONUM:
	Do_Pointer(*Area, Do_Flonum);

      case TC_BIG_FIXNUM:
	Do_Pointer(*Area, Do_Bignum);

      case TC_CHARACTER_STRING:
	Do_Pointer(*Area, Do_String);

      case TC_ENVIRONMENT:
	if (upgrade_traps_p)
	{
	  fprintf(stderr,
		  "%s: Cannot upgrade environments.\n",
		  program_name);
	  quit(1);
	}
	/* Fall through */

      case TC_FUTURE:
      case_simple_Vector:
	if (BIT_STRING_P (This))
	{
	  Do_Pointer(*Area, Do_Bit_String);
	}
	else
	{
	  Do_Pointer(*Area, Do_Vector);
	}

      default:
      Bad_Type:
	fprintf(stderr, "%s: Unknown Type Code 0x%x found.\n",
		program_name, OBJECT_TYPE (This));
	quit(1);
      }
  }
}

/* Output procedures */

void
DEFUN (print_external_objects, (from, count),
       fast SCHEME_OBJECT *from AND
       fast long count)
{
  while (--count >= 0)
  {
    switch(OBJECT_TYPE (*from))
    {
      case TC_FIXNUM:
	print_a_fixnum (FIXNUM_TO_LONG (*from));
	from += 1;
	break;

      case TC_BIT_STRING:
	print_a_bit_string (++from);
	from += (1 + (OBJECT_DATUM (*from)));
	break;

      case TC_BIG_FIXNUM:
	print_a_bignum (++from);
	from += (1 + (OBJECT_DATUM (*from)));
	break;

      case TC_CHARACTER_STRING:
	print_a_string (++from);
	from += (1 + (OBJECT_DATUM (*from)));
	break;

      case TC_BIG_FLONUM:
	print_a_flonum (*((double *) (from + 1)));
	from += (1 + float_to_pointer);
	break;

      case TC_CHARACTER:
	fprintf (portable_file, "%02x %03x\n",
		 TC_CHARACTER, ((*from) & MASK_MIT_ASCII));
	from += 1;
	break;

#ifdef FLOATING_ALIGNMENT

      case TC_MANIFEST_NM_VECTOR:
        if ((OBJECT_DATUM (*from)) == 0)
	{
	  from += 1;
	  count += 1;
	  break;
	}
        /* fall through */

#endif /* FLOATING_ALIGNMENT */

      default:
	fprintf(stderr,
		"%s: Bad Object to print externally %lx\n",
		program_name, *from);
	quit(1);
    }
  }
  return;
}

void
DEFUN (print_objects, (from, to),
       fast SCHEME_OBJECT *from AND
       fast SCHEME_OBJECT *to)
{
  fast long the_datum, the_type;

  while(from < to)
  {

    the_type = OBJECT_TYPE (*from);
    the_datum = OBJECT_DATUM (*from);
    from += 1;

    if (the_type == TC_MANIFEST_NM_VECTOR)
    {
      fprintf(portable_file, "%02x %lx\n", the_type, the_datum);
      while (--the_datum >= 0)
      {
	fprintf(portable_file, "%lx\n", ((unsigned long) *from++));
      }
    }
    else if (the_type == TC_COMPILED_ENTRY)
    {
      SCHEME_OBJECT base;
      long offset;

      offset = (FIXNUM_TO_LONG (compiled_entry_table [the_datum]));
      base = compiled_entry_table[the_datum + 1];

      fprintf(portable_file, "%02x %lx %02x %lx\n",
	      TC_COMPILED_ENTRY, offset,
	      OBJECT_TYPE (base), OBJECT_DATUM (base));
    }
    else
    {
      fprintf(portable_file, "%02x %lx\n", the_type, the_datum);
    }
  }
  return;
}

/* Debugging Aids and Consistency Checks */

#ifdef DEBUG

#define DEBUGGING(action)		action

#define WHEN(condition, message)	when(condition, message)

void
DEFUN (when, (what, message),
       Boolean what AND
       char *message)
{
  if (what)
  {
    fprintf(stderr, "%s: Inconsistency: %s!\n",
	    program_name, (message));
    quit(1);
  }
  return;
}

#define WRITE_HEADER(name, format, obj)					\
{									\
  fprintf(portable_file, (format), (obj));				\
  fprintf(portable_file, "\n");						\
  fprintf(stderr, "%s: ", (name));					\
  fprintf(stderr, (format), (obj));					\
  fprintf(stderr, "\n");						\
}

#else /* not DEBUG */

#define DEBUGGING(action)

#define WHEN(what, message)

#define WRITE_HEADER(name, format, obj)					\
{									\
  fprintf(portable_file, (format), (obj));				\
  fprintf(portable_file, "\n");						\
}

#endif /* DEBUG */

/* The main program */

void
DEFUN_VOID (do_it)
{
  while (true)
  {
    /* Load the Data */

    SCHEME_OBJECT *Heap, *Storage;
    long Initial_Free;

    switch (Read_Header ())
    {
      /* There should really be a difference between no header
	 and a short header.
       */

      case FASL_FILE_TOO_SHORT:
	return;

      case FASL_FILE_FINE:
        break;

      default:
        fprintf (stderr,
		 "%s: Input is not a Scheme binary file.\n",
		 program_name);
	quit (1);
	/* NOTREACHED */
    }

    if ((Version > FASL_READ_VERSION) ||
	(Version < FASL_OLDEST_VERSION) ||
	(Sub_Version > FASL_READ_SUBVERSION) ||
	(Sub_Version < FASL_OLDEST_SUBVERSION) ||
	((Machine_Type != FASL_INTERNAL_FORMAT) &&
	 (!swap_bytes_p)))
    {
      fprintf (stderr, "%s:\n", program_name);
      fprintf (stderr,
	       "FASL File Version %ld Subversion %ld Machine Type %ld\n",
	       Version, Sub_Version , Machine_Type);
      fprintf (stderr,
	       "Expected: Version %d Subversion %d Machine Type %d\n",
	       FASL_READ_VERSION, FASL_READ_SUBVERSION, FASL_INTERNAL_FORMAT);
      quit (1);
    }

    if ((((compiler_processor_type != 0) &&
	  (dumped_processor_type != 0) &&
	  (compiler_processor_type != dumped_processor_type)) ||
	 ((compiler_interface_version != 0) &&
	  (dumped_interface_version != 0) &&
	  (compiler_interface_version != dumped_interface_version))) &&
	(!upgrade_compiled_p))
    {
      fprintf (stderr, "\nread_file:\n");
      fprintf (stderr,
	       "FASL File: compiled code interface %4d; processor %4d.\n",
	       dumped_interface_version, dumped_processor_type);
      fprintf (stderr,
	       "Expected:  compiled code interface %4d; processor %4d.\n",
	       compiler_interface_version, compiler_processor_type);
      quit (1);
    }
    if (compiler_processor_type != 0)
    {
      dumped_processor_type = compiler_processor_type;
    }
    if (compiler_interface_version != 0)
    {
      dumped_interface_version = compiler_interface_version;
    }

    /* Constant Space and bands not currently supported */

    if (band_p)
    {
      fprintf (stderr, "%s: Input file is a band.\n", program_name);
      quit (1);
    }

    if (Const_Count != 0)
    {
      fprintf (stderr,
	       "%s: Input file has a constant space area.\n",
	       program_name);
      quit (1);
    }

    shuffle_bytes_p = swap_bytes_p;
    if (Machine_Type == FASL_INTERNAL_FORMAT)
    {
      shuffle_bytes_p = false;
    }

    upgrade_traps_p = (Sub_Version < FASL_REFERENCE_TRAP);
    upgrade_primitives_p = (Sub_Version < FASL_MERGED_PRIMITIVES);
    upgrade_lengths_p = upgrade_primitives_p;

    DEBUGGING (fprintf (stderr,
			"Dumped Heap Base = 0x%08x\n",
			Heap_Base));

    DEBUGGING (fprintf (stderr,
			"Dumped Constant Base = 0x%08x\n",
			Const_Base));

    DEBUGGING (fprintf (stderr,
			"Dumped Constant Top = 0x%08x\n",
			Dumped_Constant_Top));

    DEBUGGING (fprintf (stderr,
			"Heap Count = %6d\n",
			Heap_Count));

    DEBUGGING (fprintf (stderr,
			"Constant Count = %6d\n",
			Const_Count));

    {
      long Size;

      /* This is way larger than needed, but... what the hell? */

      Size = ((3 * (Heap_Count + Const_Count)) +
	      (NROOTS + 1) +
	      (upgrade_primitives_p ?
	       (3 * PRIMITIVE_UPGRADE_SPACE) :
	       Primitive_Table_Size) +
	      (allow_compiled_p ?
	       (2 * (Heap_Count + Const_Count)) :
	       0));

      ALLOCATE_HEAP_SPACE (Size + HEAP_BUFFER_SPACE);

      if (Heap == ((SCHEME_OBJECT *) 0))
      {
	fprintf (stderr,
		 "%s: Memory Allocation Failed.  Size = %ld Scheme Objects\n",
		 program_name, Size);
	quit (1);
      }
    }

    Storage = Heap;
    Heap += HEAP_BUFFER_SPACE;
    INITIAL_ALIGN_FLOAT (Heap);
    if ((Load_Data (Heap_Count, Heap)) != Heap_Count)
    {
      fprintf (stderr, "%s: Could not load the heap's contents.\n",
	       program_name);
      quit (1);
    }
    if ((Load_Data (Const_Count, (Heap + Heap_Count))) != Const_Count)
    {
      fprintf (stderr, "%s: Could not load constant space.\n",
	       program_name);
      quit (1);
    }
    Heap_Relocation = ((&Heap[0]) - (OBJECT_ADDRESS (Heap_Base)));
    Constant_Relocation = ((&Heap[Heap_Count]) -
			   (OBJECT_ADDRESS (Const_Base)));

    /* Setup compiled code and primitive tables. */

    compiled_entry_table = &Heap[Heap_Count + Const_Count];
    compiled_entry_pointer = compiled_entry_table;
    compiled_entry_table_end = compiled_entry_table;

    if (allow_compiled_p)
    {
      compiled_entry_table_end += (2 * (Heap_Count + Const_Count));
    }

    primitive_table = compiled_entry_table_end;
    if (upgrade_primitives_p)
    {
      primitive_table_end = (setup_primitive_upgrade (primitive_table));
    }
    else
    {
      fast SCHEME_OBJECT *table;
      fast long count, char_count;

      if ((Load_Data (Primitive_Table_Size, primitive_table)) !=
	  Primitive_Table_Size)
      {
	fprintf (stderr, "%s: Could not load the primitive table.\n",
		 program_name);
	quit (1);
      }
      for (char_count = 0,
	   count = Primitive_Table_Length,
	   table = primitive_table;
	   --count >= 0;)
      {
	char_count += (STRING_LENGTH_TO_LONG (table[1 + STRING_LENGTH_INDEX]));
	table += (2 + (OBJECT_DATUM (table[1 + STRING_HEADER])));
      }
      NPChars = char_count;
      primitive_table_end = (&primitive_table[Primitive_Table_Size]);
    }
    Mem_Base = primitive_table_end;

    /* Reformat the data */

    NFlonums = NIntegers = NStrings = 0;
    NBits = NBBits = NChars = 0;

    Mem_Base[0] = (OBJECT_NEW_TYPE (TC_CELL, Dumped_Object));
    Initial_Free = NROOTS;
    Scan = 0;

    Free = Initial_Free;
    Free_Objects = &Mem_Base[Heap_Count + Initial_Free];
    Objects = 0;

    Free_Constant = (2 * Heap_Count) + Initial_Free;
    Scan_Constant = Free_Constant;
    Free_Cobjects = &Mem_Base[Const_Count + Free_Constant];
    Constant_Objects = 0;

#if TRUE

    Do_Area (HEAP_CODE, Scan, Free, Objects, Free_Objects);

#else

    /*
      When Constant Space finally becomes supported,
      something like this must be done.
      */

    while (true)
    {
      Do_Area (HEAP_CODE, Scan, Free,
	       Objects, Free_Objects);
      Do_Area (CONSTANT_CODE, Scan_Constant, Free_Constant,
	       Constant_Objects, Free_Cobjects);
      Do_Area (PURE_CODE, Scan_Pure, Free_Pure,
	       Pure_Objects, Free_Pobjects);
      if (Scan == Free)
      {
	break;
      }
    }

#endif

    /* Consistency checks */

    WHEN (((Free - Initial_Free) > Heap_Count), "Free overran Heap");

    WHEN (((Free_Objects - &Mem_Base[Initial_Free + Heap_Count]) >
	   Heap_Count),
	  "Free_Objects overran Heap Object Space");

    WHEN (((Free_Constant - (Initial_Free + (2 * Heap_Count))) > Const_Count),
	  "Free_Constant overran Constant Space");

    WHEN (((Free_Cobjects - &Mem_Base[Initial_Free +
				      (2 * Heap_Count) + Const_Count]) >
	   Const_Count),
	  "Free_Cobjects overran Constant Object Space");

    /* Output the data */

    if (found_ext_prims)
    {
      fprintf (stderr, "%s:\n", program_name);
      fprintf (stderr, "NOTE: The arity of some primitives is not known.\n");
      fprintf (stderr, "      The portable file has %ld as their arity.\n",
	       UNKNOWN_PRIMITIVE_ARITY);
      fprintf (stderr, "      You may want to fix this by hand.\n");
    }

    /* Header */

    WRITE_HEADER ("Portable Version", "%ld", PORTABLE_VERSION);
    WRITE_HEADER ("Machine", "%ld", FASL_INTERNAL_FORMAT);
    WRITE_HEADER ("Version", "%ld", FASL_FORMAT_VERSION);
    WRITE_HEADER ("Sub Version", "%ld", FASL_SUBVERSION);
    WRITE_HEADER ("Flags", "%ld", (MAKE_FLAGS ()));

    WRITE_HEADER ("Heap Count", "%ld", (Free - NROOTS));
    WRITE_HEADER ("Heap Base", "%ld", NROOTS);
    WRITE_HEADER ("Heap Objects", "%ld", Objects);

    /* Currently Constant and Pure not supported, but the header is ready */

    WRITE_HEADER ("Pure Count", "%ld", 0);
    WRITE_HEADER ("Pure Base", "%ld", Free_Constant);
    WRITE_HEADER ("Pure Objects", "%ld", 0);

    WRITE_HEADER ("Constant Count", "%ld", 0);
    WRITE_HEADER ("Constant Base", "%ld", Free_Constant);
    WRITE_HEADER ("Constant Objects", "%ld", 0);

    WRITE_HEADER ("& Dumped Object", "%ld", (OBJECT_DATUM (Mem_Base[0])));

    WRITE_HEADER ("Number of flonums", "%ld", NFlonums);
    WRITE_HEADER ("Number of integers", "%ld", NIntegers);
    WRITE_HEADER ("Number of bits in integers", "%ld", NBits);
    WRITE_HEADER ("Number of bit strings", "%ld", NBitstrs);
    WRITE_HEADER ("Number of bits in bit strings", "%ld", NBBits);
    WRITE_HEADER ("Number of character strings", "%ld", NStrings);
    WRITE_HEADER ("Number of characters in strings", "%ld", NChars);

    WRITE_HEADER ("Number of primitives", "%ld", Primitive_Table_Length);
    WRITE_HEADER ("Number of characters in primitives", "%ld", NPChars);

    if (!compiled_p)
    {
      dumped_processor_type = 0;
      dumped_interface_version = 0;
    }

    WRITE_HEADER ("CPU type", "%ld", dumped_processor_type);
    WRITE_HEADER ("Compiled code interface version", "%ld",
		  dumped_interface_version);
#if FALSE
    WRITE_HEADER ("Compiler utilities vector", "%ld",
		  (OBJECT_DATUM (dumped_utilities)));
#endif

    /* External Objects */

    print_external_objects (&Mem_Base[Initial_Free + Heap_Count],
			    Objects);

#if FALSE

    print_external_objects (&Mem_Base[Pure_Objects_Start],
			    Pure_Objects);
    print_external_objects (&Mem_Base[Constant_Objects_Start],
			    Constant_Objects);

#endif

    /* Pointer Objects */

    print_objects (&Mem_Base[NROOTS], &Mem_Base[Free]);

#if FALSE
    print_objects (&Mem_Base[Pure_Start], &Mem_Base[Free_Pure]);
    print_objects (&Mem_Base[Constant_Start], &Mem_Base[Free_Constant]);
#endif

    /* Primitives */

    if (upgrade_primitives_p)
    {
      SCHEME_OBJECT obj;
      fast SCHEME_OBJECT *table;
      fast long count, the_datum;

      for (count = Primitive_Table_Length,
	   table = external_renumber_table;
	   --count >= 0;)
      {
	obj = *table++;
	the_datum = (OBJECT_DATUM (obj));
	if ((OBJECT_TYPE (obj)) == TC_PRIMITIVE_EXTERNAL)
	{
	  SCHEME_OBJECT *strobj;

	  strobj = ((SCHEME_OBJECT *) (external_prim_name_table[the_datum]));
	  print_a_primitive (((long) UNKNOWN_PRIMITIVE_ARITY),
			     (STRING_LENGTH_TO_LONG
			      (strobj[STRING_LENGTH_INDEX])),
			     ((char *) &strobj[STRING_CHARS]));
	}
	else
	{
	  char *str;

	  str = builtin_prim_name_table[the_datum];
	  print_a_primitive (((long) builtin_prim_arity_table[the_datum]),
			     ((long) strlen(str)),
			     str);
	}
      }
    }
    else
    {
      fast SCHEME_OBJECT *table;
      fast long count;
      long arity;

      for (count = Primitive_Table_Length, table = primitive_table;
	   --count >= 0;)
      {
	arity = (FIXNUM_TO_LONG (*table));
	table += 1;
	print_a_primitive (arity,
			   (STRING_LENGTH_TO_LONG(table[STRING_LENGTH_INDEX])),
			   ((char *) &table[STRING_CHARS]));
	table += (1 + OBJECT_DATUM (table[STRING_HEADER]));
      }
    }
    fflush (portable_file);
    free ((char *) Storage);
  }
}

/* Top Level */

static Boolean
  help_p = false,
  help_sup_p,
  ci_version_sup_p,
  ci_processor_sup_p;

/* The boolean value here is what value to store when the option is present. */

static struct keyword_struct
  options[] = {
    KEYWORD ("swap_bytes", &swap_bytes_p, BOOLEAN_KYWRD, BFRMT, NULL),
    KEYWORD ("compact", &compact_p, BOOLEAN_KYWRD, BFRMT, NULL),
    KEYWORD ("null_nmv", &null_nmv_p, BOOLEAN_KYWRD, BFRMT, NULL),
    KEYWORD ("allow_nmv", &allow_nmv_p, BOOLEAN_KYWRD, BFRMT, NULL),
    KEYWORD ("allow_cc", &allow_compiled_p, BOOLEAN_KYWRD, BFRMT, NULL),
    KEYWORD ("upgrade_cc", &upgrade_compiled_p, BOOLEAN_KYWRD, BFRMT, NULL),
    KEYWORD ("ci_version", &compiler_interface_version, INT_KYWRD, "%ld",
	     &ci_version_sup_p),
    KEYWORD ("ci_processor", &compiler_processor_type, INT_KYWRD, "%ld",
	     &ci_processor_sup_p),
    KEYWORD ("vax_invert", &vax_invert_p, BOOLEAN_KYWRD, BFRMT, NULL),
    KEYWORD ("help", &help_p, BOOLEAN_KYWRD, BFRMT, &help_sup_p),
    OUTPUT_KEYWORD (),
    INPUT_KEYWORD (),
    END_KEYWORD ()
    };

void
DEFUN (main, (argc, argv),
       int argc AND
       char **argv)
{
  parse_keywords (argc, argv, options, false);

  if (help_sup_p && help_p)
  {
    print_usage_and_exit(options, 0);
    /*NOTREACHED*/
  }

  upgrade_compiled_p =
    (upgrade_compiled_p || ci_version_sup_p || ci_processor_sup_p);
  allow_compiled_p = (allow_compiled_p || upgrade_compiled_p);
  allow_nmv_p = (allow_nmv_p || allow_compiled_p || vax_invert_p);
  if (null_nmv_p && allow_nmv_p)
  {
    fprintf (stderr,
	     "%s: NMVs are both allowed and to be nulled out!\n",
	     program_name);
    quit (1);
  }

  setup_io ("rb", "w");
  do_it ();
  quit (0);
}
