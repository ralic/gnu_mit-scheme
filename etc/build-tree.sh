#!/bin/sh
#
# $Id: build-tree.sh,v 1.2 2000/03/21 05:10:57 cph Exp $
#
# Program to finish setting up the Scheme source tree after it is
# checked out.  Adds required links, builds TAGS files, etc.
#
if [ ! -d 6001 ]
then
  echo "This must be run from the top-level Scheme source directory."
  exit 1
fi
for directory in 6001 cref edwin rcs runtime sf sos win32
do
  (cd $directory; ln -s ../Makefile.std Makefile)
done
for directory in 6001 compiler cref edwin rcs runtime sf sos swat win32
do
  (cd $directory; make TAGS)
done
for directory in edwin runtime sos
do
  (cd $directory; ln -s ed-ffi.scm .edwin-ffi)
done
(cd microcode; etags *.[ch])
(cd microcode; scheme -load os2pm.scm < /dev/null)
(cd microcode/cmpauxmd; make all)
(cd pcsample; etags *.scm *.c)
(cd compiler/machines/vax;
 for n in 1 2 3
 do
   ln -s instr${n}.scm dinstr${n}.scm
 done)
