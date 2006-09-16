/* Emacs: this is -*- C -*- code. */

#ifndef STACKOPS_H
#define STACKOPS_H

/*

$Id: stackops.h,v 11.1 2006/09/16 11:19:09 gjr Exp $

Copyright (c) 2006 Massachusetts Institute of Technology

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

*/

/* C code produced
   Thursday August 24, 2006 at 6:20:11 PM
 */

typedef enum
{
	stackify_opcode_illegal = 0,
	stackify_opcode_escape = 01,
	stackify_opcode_push_Pfixnum = 02,
	stackify_opcode_push__fixnum = 03,
	stackify_opcode_push_Pinteger = 04,
	stackify_opcode_push__integer = 05,
	stackify_opcode_push_false = 06,
	stackify_opcode_push_true = 07,
	stackify_opcode_push_nil = 010,
	stackify_opcode_push_flonum = 011,
	stackify_opcode_push_cons_ratnum = 012,
	stackify_opcode_push_cons_recnum = 013,
	stackify_opcode_push_string = 014,
	stackify_opcode_push_symbol = 015,
	stackify_opcode_push_uninterned_symbol = 016,
	stackify_opcode_push_char = 017,
	stackify_opcode_push_bit_string = 020,
	stackify_opcode_push_empty_cons = 021,
	stackify_opcode_pop_and_set_car = 022,
	stackify_opcode_pop_and_set_cdr = 023,
	stackify_opcode_push_consS = 024,
	stackify_opcode_push_empty_vector = 025,
	stackify_opcode_pop_and_vector_set = 026,
	stackify_opcode_push_vector = 027,
	stackify_opcode_push_empty_record = 030,
	stackify_opcode_pop_and_record_set = 031,
	stackify_opcode_push_record = 032,
	stackify_opcode_push_lookup = 033,
	stackify_opcode_store = 034,
	stackify_opcode_push_constant = 035,
	stackify_opcode_push_unassigned = 036,
	stackify_opcode_push_primitive = 037,
	stackify_opcode_push_primitive_lexpr = 040,
	stackify_opcode_push_nm_header = 041,
	stackify_opcode_push_label_entry = 042,
	stackify_opcode_push_linkage_header_operator = 043,
	stackify_opcode_push_linkage_header_reference = 044,
	stackify_opcode_push_linkage_header_assignment = 045,
	stackify_opcode_push_linkage_header_global = 046,
	stackify_opcode_push_linkage_header_closure = 047,
	stackify_opcode_push_ulong = 050,
	stackify_opcode_push_label_descriptor = 051,
	stackify_opcode_cc_block_to_entry = 052,
	stackify_opcode_retag_cc_block = 053,
	stackify_opcode_push_return_code = 054,
	stackify_opcode_push_0 = 0200,
	stackify_opcode_push_1 = 0201,
	stackify_opcode_push_2 = 0202,
	stackify_opcode_push_3 = 0203,
	stackify_opcode_push_4 = 0204,
	stackify_opcode_push_5 = 0205,
	stackify_opcode_push_6 = 0206,
	stackify_opcode_push__1 = 0207,
	stackify_opcode_push_consS_0 = 0210,
	stackify_opcode_push_consS_1 = 0211,
	stackify_opcode_push_consS_2 = 0212,
	stackify_opcode_push_consS_3 = 0213,
	stackify_opcode_push_consS_4 = 0214,
	stackify_opcode_push_consS_5 = 0215,
	stackify_opcode_push_consS_6 = 0216,
	stackify_opcode_push_consS_7 = 0217,
	stackify_opcode_pop_and_vector_set_0 = 0220,
	stackify_opcode_pop_and_vector_set_1 = 0221,
	stackify_opcode_pop_and_vector_set_2 = 0222,
	stackify_opcode_pop_and_vector_set_3 = 0223,
	stackify_opcode_pop_and_vector_set_4 = 0224,
	stackify_opcode_pop_and_vector_set_5 = 0225,
	stackify_opcode_pop_and_vector_set_6 = 0226,
	stackify_opcode_pop_and_vector_set_7 = 0227,
	stackify_opcode_push_vector_1 = 0230,
	stackify_opcode_push_vector_2 = 0231,
	stackify_opcode_push_vector_3 = 0232,
	stackify_opcode_push_vector_4 = 0233,
	stackify_opcode_push_vector_5 = 0234,
	stackify_opcode_push_vector_6 = 0235,
	stackify_opcode_push_vector_7 = 0236,
	stackify_opcode_push_vector_8 = 0237,
	stackify_opcode_pop_and_record_set_0 = 0240,
	stackify_opcode_pop_and_record_set_1 = 0241,
	stackify_opcode_pop_and_record_set_2 = 0242,
	stackify_opcode_pop_and_record_set_3 = 0243,
	stackify_opcode_pop_and_record_set_4 = 0244,
	stackify_opcode_pop_and_record_set_5 = 0245,
	stackify_opcode_pop_and_record_set_6 = 0246,
	stackify_opcode_pop_and_record_set_7 = 0247,
	stackify_opcode_push_record_1 = 0250,
	stackify_opcode_push_record_2 = 0251,
	stackify_opcode_push_record_3 = 0252,
	stackify_opcode_push_record_4 = 0253,
	stackify_opcode_push_record_5 = 0254,
	stackify_opcode_push_record_6 = 0255,
	stackify_opcode_push_record_7 = 0256,
	stackify_opcode_push_record_8 = 0257,
	stackify_opcode_push_lookup_0 = 0260,
	stackify_opcode_push_lookup_1 = 0261,
	stackify_opcode_push_lookup_2 = 0262,
	stackify_opcode_push_lookup_3 = 0263,
	stackify_opcode_push_lookup_4 = 0264,
	stackify_opcode_push_lookup_5 = 0265,
	stackify_opcode_push_lookup_6 = 0266,
	stackify_opcode_push_lookup_7 = 0267,
	stackify_opcode_store_0 = 0270,
	stackify_opcode_store_1 = 0271,
	stackify_opcode_store_2 = 0272,
	stackify_opcode_store_3 = 0273,
	stackify_opcode_store_4 = 0274,
	stackify_opcode_store_5 = 0275,
	stackify_opcode_store_6 = 0276,
	stackify_opcode_store_7 = 0277,
	stackify_opcode_push_primitive_0 = 0300,
	stackify_opcode_push_primitive_1 = 0301,
	stackify_opcode_push_primitive_2 = 0302,
	stackify_opcode_push_primitive_3 = 0303,
	stackify_opcode_push_primitive_4 = 0304,
	stackify_opcode_push_primitive_5 = 0305,
	stackify_opcode_push_primitive_6 = 0306,
	stackify_opcode_push_primitive_7 = 0307,
	N_STACKIFY_OPCODE = 200
} stackify_opcode_t;

#endif /* STACKOPS_H */
