/* -*-C-*-

$Id: none.h,v 1.1.2.2 2006/10/04 02:33:56 cph Exp $

Copyright 2006 Massachusetts Institute of Technology

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

*/

/* Compiled code interface stub.  */

#ifndef SCM_CMPINTMD_H_INCLUDED
#define SCM_CMPINTMD_H_INCLUDED 1

typedef byte_t insn_t;

#define compiler_interface_version (0UL)
#define compiler_processor_type COMPILER_PROCESSOR_TYPE
#define compiler_utilities SHARP_F

#define return_to_interpreter SHARP_F
#define reflect_to_interface SHARP_F

#define compiler_initialize(faslp) do {} while (false)
#define guarantee_interp_return() do {} while (false)

#define CC_ENTRY_P(object) (false)

#endif /* !SCM_CMPINTMD_H_INCLUDED */