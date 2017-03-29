#| -*-Scheme-*-

Copyright (C) 1986, 1987, 1988, 1989, 1990, 1991, 1992, 1993, 1994,
    1995, 1996, 1997, 1998, 1999, 2000, 2001, 2002, 2003, 2004, 2005,
    2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014, 2015, 2016,
    2017 Massachusetts Institute of Technology

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

|#

;;;; UCD property: canonical-cm-second

;;; Generated from Unicode 9.0.0

(declare (usual-integrations))

(define-deferred ucd-canonical-cm-second-keys
  (vector-map
   vector->string
   #(#(#\u+338)
     #(#\u+338)
     #(#\u+338)
     #(#\u+300 #\u+301 #\u+302 #\u+303 #\u+304 #\u+306 #\u+307 #\u+308 #\u+309 #\u+30a #\u+30c #\u+30f #\u+311 #\u+323 #\u+325 #\u+328)
     #(#\u+307 #\u+323 #\u+331)
     #(#\u+301 #\u+302 #\u+307 #\u+30c #\u+327)
     #(#\u+307 #\u+30c #\u+323 #\u+327 #\u+32d #\u+331)
     #(#\u+300 #\u+301 #\u+302 #\u+303 #\u+304 #\u+306 #\u+307 #\u+308 #\u+309 #\u+30c #\u+30f #\u+311 #\u+323 #\u+327 #\u+328 #\u+32d #\u+330)
     #(#\u+307)
     #(#\u+301 #\u+302 #\u+304 #\u+306 #\u+307 #\u+30c #\u+327)
     #(#\u+302 #\u+307 #\u+308 #\u+30c #\u+323 #\u+327 #\u+32e)
     #(#\u+300 #\u+301 #\u+302 #\u+303 #\u+304 #\u+306 #\u+307 #\u+308 #\u+309 #\u+30c #\u+30f #\u+311 #\u+323 #\u+328 #\u+330)
     #(#\u+302)
     #(#\u+301 #\u+30c #\u+323 #\u+327 #\u+331)
     #(#\u+301 #\u+30c #\u+323 #\u+327 #\u+32d #\u+331)
     #(#\u+301 #\u+307 #\u+323)
     #(#\u+300 #\u+301 #\u+303 #\u+307 #\u+30c #\u+323 #\u+327 #\u+32d #\u+331)
     #(#\u+300 #\u+301 #\u+302 #\u+303 #\u+304 #\u+306 #\u+307 #\u+308 #\u+309 #\u+30b #\u+30c #\u+30f #\u+311 #\u+31b #\u+323 #\u+328)
     #(#\u+301 #\u+307)
     #(#\u+301 #\u+307 #\u+30c #\u+30f #\u+311 #\u+323 #\u+327 #\u+331)
     #(#\u+301 #\u+302 #\u+307 #\u+30c #\u+323 #\u+326 #\u+327)
     #(#\u+307 #\u+30c #\u+323 #\u+326 #\u+327 #\u+32d #\u+331)
     #(#\u+300 #\u+301 #\u+302 #\u+303 #\u+304 #\u+306 #\u+308 #\u+309 #\u+30a #\u+30b #\u+30c #\u+30f #\u+311 #\u+31b #\u+323 #\u+324 #\u+328 #\u+32d #\u+330)
     #(#\u+303 #\u+323)
     #(#\u+300 #\u+301 #\u+302 #\u+307 #\u+308 #\u+323)
     #(#\u+307 #\u+308)
     #(#\u+300 #\u+301 #\u+302 #\u+303 #\u+304 #\u+307 #\u+308 #\u+309 #\u+323)
     #(#\u+301 #\u+302 #\u+307 #\u+30c #\u+323 #\u+331)
     #(#\u+300 #\u+301 #\u+302 #\u+303 #\u+304 #\u+306 #\u+307 #\u+308 #\u+309 #\u+30a #\u+30c #\u+30f #\u+311 #\u+323 #\u+325 #\u+328)
     #(#\u+307 #\u+323 #\u+331)
     #(#\u+301 #\u+302 #\u+307 #\u+30c #\u+327)
     #(#\u+307 #\u+30c #\u+323 #\u+327 #\u+32d #\u+331)
     #(#\u+300 #\u+301 #\u+302 #\u+303 #\u+304 #\u+306 #\u+307 #\u+308 #\u+309 #\u+30c #\u+30f #\u+311 #\u+323 #\u+327 #\u+328 #\u+32d #\u+330)
     #(#\u+307)
     #(#\u+301 #\u+302 #\u+304 #\u+306 #\u+307 #\u+30c #\u+327)
     #(#\u+302 #\u+307 #\u+308 #\u+30c #\u+323 #\u+327 #\u+32e #\u+331)
     #(#\u+300 #\u+301 #\u+302 #\u+303 #\u+304 #\u+306 #\u+308 #\u+309 #\u+30c #\u+30f #\u+311 #\u+323 #\u+328 #\u+330)
     #(#\u+302 #\u+30c)
     #(#\u+301 #\u+30c #\u+323 #\u+327 #\u+331)
     #(#\u+301 #\u+30c #\u+323 #\u+327 #\u+32d #\u+331)
     #(#\u+301 #\u+307 #\u+323)
     #(#\u+300 #\u+301 #\u+303 #\u+307 #\u+30c #\u+323 #\u+327 #\u+32d #\u+331)
     #(#\u+300 #\u+301 #\u+302 #\u+303 #\u+304 #\u+306 #\u+307 #\u+308 #\u+309 #\u+30b #\u+30c #\u+30f #\u+311 #\u+31b #\u+323 #\u+328)
     #(#\u+301 #\u+307)
     #(#\u+301 #\u+307 #\u+30c #\u+30f #\u+311 #\u+323 #\u+327 #\u+331)
     #(#\u+301 #\u+302 #\u+307 #\u+30c #\u+323 #\u+326 #\u+327)
     #(#\u+307 #\u+308 #\u+30c #\u+323 #\u+326 #\u+327 #\u+32d #\u+331)
     #(#\u+300 #\u+301 #\u+302 #\u+303 #\u+304 #\u+306 #\u+308 #\u+309 #\u+30a #\u+30b #\u+30c #\u+30f #\u+311 #\u+31b #\u+323 #\u+324 #\u+328 #\u+32d #\u+330)
     #(#\u+303 #\u+323)
     #(#\u+300 #\u+301 #\u+302 #\u+307 #\u+308 #\u+30a #\u+323)
     #(#\u+307 #\u+308)
     #(#\u+300 #\u+301 #\u+302 #\u+303 #\u+304 #\u+307 #\u+308 #\u+309 #\u+30a #\u+323)
     #(#\u+301 #\u+302 #\u+307 #\u+30c #\u+323 #\u+331)
     #(#\u+300 #\u+301 #\u+342)
     #(#\u+300 #\u+301 #\u+303 #\u+309)
     #(#\u+304)
     #(#\u+301)
     #(#\u+301 #\u+304)
     #(#\u+301)
     #(#\u+300 #\u+301 #\u+303 #\u+309)
     #(#\u+301)
     #(#\u+300 #\u+301 #\u+303 #\u+309)
     #(#\u+301 #\u+304 #\u+308)
     #(#\u+304)
     #(#\u+301)
     #(#\u+300 #\u+301 #\u+304 #\u+30c)
     #(#\u+300 #\u+301 #\u+303 #\u+309)
     #(#\u+304)
     #(#\u+301)
     #(#\u+301 #\u+304)
     #(#\u+301)
     #(#\u+300 #\u+301 #\u+303 #\u+309)
     #(#\u+301)
     #(#\u+300 #\u+301 #\u+303 #\u+309)
     #(#\u+301 #\u+304 #\u+308)
     #(#\u+304)
     #(#\u+301)
     #(#\u+300 #\u+301 #\u+304 #\u+30c)
     #(#\u+300 #\u+301 #\u+303 #\u+309)
     #(#\u+300 #\u+301 #\u+303 #\u+309)
     #(#\u+300 #\u+301)
     #(#\u+300 #\u+301)
     #(#\u+300 #\u+301)
     #(#\u+300 #\u+301)
     #(#\u+307)
     #(#\u+307)
     #(#\u+307)
     #(#\u+307)
     #(#\u+301)
     #(#\u+301)
     #(#\u+308)
     #(#\u+308)
     #(#\u+307)
     #(#\u+300 #\u+301 #\u+303 #\u+309 #\u+323)
     #(#\u+300 #\u+301 #\u+303 #\u+309 #\u+323)
     #(#\u+300 #\u+301 #\u+303 #\u+309 #\u+323)
     #(#\u+300 #\u+301 #\u+303 #\u+309 #\u+323)
     #(#\u+30c)
     #(#\u+304)
     #(#\u+304)
     #(#\u+304)
     #(#\u+304)
     #(#\u+306)
     #(#\u+306)
     #(#\u+304)
     #(#\u+304)
     #(#\u+30c)
     #(#\u+300 #\u+301 #\u+304 #\u+306 #\u+313 #\u+314 #\u+345)
     #(#\u+300 #\u+301 #\u+313 #\u+314)
     #(#\u+300 #\u+301 #\u+313 #\u+314 #\u+345)
     #(#\u+300 #\u+301 #\u+304 #\u+306 #\u+308 #\u+313 #\u+314)
     #(#\u+300 #\u+301 #\u+313 #\u+314)
     #(#\u+314)
     #(#\u+300 #\u+301 #\u+304 #\u+306 #\u+308 #\u+314)
     #(#\u+300 #\u+301 #\u+313 #\u+314 #\u+345)
     #(#\u+345)
     #(#\u+345)
     #(#\u+300 #\u+301 #\u+304 #\u+306 #\u+313 #\u+314 #\u+342 #\u+345)
     #(#\u+300 #\u+301 #\u+313 #\u+314)
     #(#\u+300 #\u+301 #\u+313 #\u+314 #\u+342 #\u+345)
     #(#\u+300 #\u+301 #\u+304 #\u+306 #\u+308 #\u+313 #\u+314 #\u+342)
     #(#\u+300 #\u+301 #\u+313 #\u+314)
     #(#\u+313 #\u+314)
     #(#\u+300 #\u+301 #\u+304 #\u+306 #\u+308 #\u+313 #\u+314 #\u+342)
     #(#\u+300 #\u+301 #\u+313 #\u+314 #\u+342 #\u+345)
     #(#\u+300 #\u+301 #\u+342)
     #(#\u+300 #\u+301 #\u+342)
     #(#\u+345)
     #(#\u+301 #\u+308)
     #(#\u+308)
     #(#\u+306 #\u+308)
     #(#\u+301)
     #(#\u+300 #\u+306 #\u+308)
     #(#\u+306 #\u+308)
     #(#\u+308)
     #(#\u+300 #\u+304 #\u+306 #\u+308)
     #(#\u+301)
     #(#\u+308)
     #(#\u+304 #\u+306 #\u+308 #\u+30b)
     #(#\u+308)
     #(#\u+308)
     #(#\u+308)
     #(#\u+306 #\u+308)
     #(#\u+301)
     #(#\u+300 #\u+306 #\u+308)
     #(#\u+306 #\u+308)
     #(#\u+308)
     #(#\u+300 #\u+304 #\u+306 #\u+308)
     #(#\u+301)
     #(#\u+308)
     #(#\u+304 #\u+306 #\u+308 #\u+30b)
     #(#\u+308)
     #(#\u+308)
     #(#\u+308)
     #(#\u+308)
     #(#\u+30f)
     #(#\u+30f)
     #(#\u+308)
     #(#\u+308)
     #(#\u+308)
     #(#\u+308)
     #(#\u+653 #\u+654 #\u+655)
     #(#\u+654)
     #(#\u+654)
     #(#\u+654)
     #(#\u+654)
     #(#\u+654)
     #(#\u+93c)
     #(#\u+93c)
     #(#\u+93c)
     #(#\u+9be #\u+9d7)
     #(#\u+b3e #\u+b56 #\u+b57)
     #(#\u+bd7)
     #(#\u+bbe #\u+bd7)
     #(#\u+bbe)
     #(#\u+c56)
     #(#\u+cd5)
     #(#\u+cc2 #\u+cd5 #\u+cd6)
     #(#\u+cd5)
     #(#\u+d3e #\u+d57)
     #(#\u+d3e)
     #(#\u+dca #\u+dcf #\u+ddf)
     #(#\u+dca)
     #(#\u+102e)
     #(#\u+1b35)
     #(#\u+1b35)
     #(#\u+1b35)
     #(#\u+1b35)
     #(#\u+1b35)
     #(#\u+1b35)
     #(#\u+1b35)
     #(#\u+1b35)
     #(#\u+1b35)
     #(#\u+1b35)
     #(#\u+1b35)
     #(#\u+304)
     #(#\u+304)
     #(#\u+304)
     #(#\u+304)
     #(#\u+307)
     #(#\u+307)
     #(#\u+302 #\u+306)
     #(#\u+302 #\u+306)
     #(#\u+302)
     #(#\u+302)
     #(#\u+302)
     #(#\u+302)
     #(#\u+300 #\u+301 #\u+342 #\u+345)
     #(#\u+300 #\u+301 #\u+342 #\u+345)
     #(#\u+345)
     #(#\u+345)
     #(#\u+345)
     #(#\u+345)
     #(#\u+345)
     #(#\u+345)
     #(#\u+300 #\u+301 #\u+342 #\u+345)
     #(#\u+300 #\u+301 #\u+342 #\u+345)
     #(#\u+345)
     #(#\u+345)
     #(#\u+345)
     #(#\u+345)
     #(#\u+345)
     #(#\u+345)
     #(#\u+300 #\u+301)
     #(#\u+300 #\u+301)
     #(#\u+300 #\u+301)
     #(#\u+300 #\u+301)
     #(#\u+300 #\u+301 #\u+342 #\u+345)
     #(#\u+300 #\u+301 #\u+342 #\u+345)
     #(#\u+345)
     #(#\u+345)
     #(#\u+345)
     #(#\u+345)
     #(#\u+345)
     #(#\u+345)
     #(#\u+300 #\u+301 #\u+342 #\u+345)
     #(#\u+300 #\u+301 #\u+342 #\u+345)
     #(#\u+345)
     #(#\u+345)
     #(#\u+345)
     #(#\u+345)
     #(#\u+345)
     #(#\u+345)
     #(#\u+300 #\u+301 #\u+342)
     #(#\u+300 #\u+301 #\u+342)
     #(#\u+300 #\u+301 #\u+342)
     #(#\u+300 #\u+301 #\u+342)
     #(#\u+300 #\u+301)
     #(#\u+300 #\u+301)
     #(#\u+300 #\u+301)
     #(#\u+300 #\u+301)
     #(#\u+300 #\u+301 #\u+342)
     #(#\u+300 #\u+301 #\u+342)
     #(#\u+300 #\u+301 #\u+342)
     #(#\u+300 #\u+301 #\u+342 #\u+345)
     #(#\u+300 #\u+301 #\u+342 #\u+345)
     #(#\u+345)
     #(#\u+345)
     #(#\u+345)
     #(#\u+345)
     #(#\u+345)
     #(#\u+345)
     #(#\u+300 #\u+301 #\u+342 #\u+345)
     #(#\u+300 #\u+301 #\u+342 #\u+345)
     #(#\u+345)
     #(#\u+345)
     #(#\u+345)
     #(#\u+345)
     #(#\u+345)
     #(#\u+345)
     #(#\u+345)
     #(#\u+345)
     #(#\u+345)
     #(#\u+345)
     #(#\u+300 #\u+301 #\u+342)
     #(#\u+345)
     #(#\u+345)
     #(#\u+300 #\u+301 #\u+342)
     #(#\u+338)
     #(#\u+338)
     #(#\u+338)
     #(#\u+338)
     #(#\u+338)
     #(#\u+338)
     #(#\u+338)
     #(#\u+338)
     #(#\u+338)
     #(#\u+338)
     #(#\u+338)
     #(#\u+338)
     #(#\u+338)
     #(#\u+338)
     #(#\u+338)
     #(#\u+338)
     #(#\u+338)
     #(#\u+338)
     #(#\u+338)
     #(#\u+338)
     #(#\u+338)
     #(#\u+338)
     #(#\u+338)
     #(#\u+338)
     #(#\u+338)
     #(#\u+338)
     #(#\u+338)
     #(#\u+338)
     #(#\u+338)
     #(#\u+338)
     #(#\u+338)
     #(#\u+338)
     #(#\u+338)
     #(#\u+338)
     #(#\u+338)
     #(#\u+338)
     #(#\u+338)
     #(#\u+338)
     #(#\u+338)
     #(#\u+338)
     #(#\u+338)
     #(#\u+3099)
     #(#\u+3099)
     #(#\u+3099)
     #(#\u+3099)
     #(#\u+3099)
     #(#\u+3099)
     #(#\u+3099)
     #(#\u+3099)
     #(#\u+3099)
     #(#\u+3099)
     #(#\u+3099)
     #(#\u+3099)
     #(#\u+3099)
     #(#\u+3099)
     #(#\u+3099)
     #(#\u+3099)
     #(#\u+3099 #\u+309a)
     #(#\u+3099 #\u+309a)
     #(#\u+3099 #\u+309a)
     #(#\u+3099 #\u+309a)
     #(#\u+3099 #\u+309a)
     #(#\u+3099)
     #(#\u+3099)
     #(#\u+3099)
     #(#\u+3099)
     #(#\u+3099)
     #(#\u+3099)
     #(#\u+3099)
     #(#\u+3099)
     #(#\u+3099)
     #(#\u+3099)
     #(#\u+3099)
     #(#\u+3099)
     #(#\u+3099)
     #(#\u+3099)
     #(#\u+3099)
     #(#\u+3099)
     #(#\u+3099)
     #(#\u+3099 #\u+309a)
     #(#\u+3099 #\u+309a)
     #(#\u+3099 #\u+309a)
     #(#\u+3099 #\u+309a)
     #(#\u+3099 #\u+309a)
     #(#\u+3099)
     #(#\u+3099)
     #(#\u+3099)
     #(#\u+3099)
     #(#\u+3099)
     #(#\u+110ba)
     #(#\u+110ba)
     #(#\u+110ba)
     #(#\u+11127)
     #(#\u+11127)
     #(#\u+1133e #\u+11357)
     #(#\u+114b0 #\u+114ba #\u+114bd)
     #(#\u+115af)
     #(#\u+115af))))

(define-deferred ucd-canonical-cm-second-values
  (vector-map
   vector->string
   #(#(#\u+226e)
     #(#\u+2260)
     #(#\u+226f)
     #(#\u+c0 #\u+c1 #\u+c2 #\u+c3 #\u+100 #\u+102 #\u+226 #\u+c4 #\u+1ea2 #\u+c5 #\u+1cd #\u+200 #\u+202 #\u+1ea0 #\u+1e00 #\u+104)
     #(#\u+1e02 #\u+1e04 #\u+1e06)
     #(#\u+106 #\u+108 #\u+10a #\u+10c #\u+c7)
     #(#\u+1e0a #\u+10e #\u+1e0c #\u+1e10 #\u+1e12 #\u+1e0e)
     #(#\u+c8 #\u+c9 #\u+ca #\u+1ebc #\u+112 #\u+114 #\u+116 #\u+cb #\u+1eba #\u+11a #\u+204 #\u+206 #\u+1eb8 #\u+228 #\u+118 #\u+1e18 #\u+1e1a)
     #(#\u+1e1e)
     #(#\u+1f4 #\u+11c #\u+1e20 #\u+11e #\u+120 #\u+1e6 #\u+122)
     #(#\u+124 #\u+1e22 #\u+1e26 #\u+21e #\u+1e24 #\u+1e28 #\u+1e2a)
     #(#\u+cc #\u+cd #\u+ce #\u+128 #\u+12a #\u+12c #\u+130 #\u+cf #\u+1ec8 #\u+1cf #\u+208 #\u+20a #\u+1eca #\u+12e #\u+1e2c)
     #(#\u+134)
     #(#\u+1e30 #\u+1e8 #\u+1e32 #\u+136 #\u+1e34)
     #(#\u+139 #\u+13d #\u+1e36 #\u+13b #\u+1e3c #\u+1e3a)
     #(#\u+1e3e #\u+1e40 #\u+1e42)
     #(#\u+1f8 #\u+143 #\u+d1 #\u+1e44 #\u+147 #\u+1e46 #\u+145 #\u+1e4a #\u+1e48)
     #(#\u+d2 #\u+d3 #\u+d4 #\u+d5 #\u+14c #\u+14e #\u+22e #\u+d6 #\u+1ece #\u+150 #\u+1d1 #\u+20c #\u+20e #\u+1a0 #\u+1ecc #\u+1ea)
     #(#\u+1e54 #\u+1e56)
     #(#\u+154 #\u+1e58 #\u+158 #\u+210 #\u+212 #\u+1e5a #\u+156 #\u+1e5e)
     #(#\u+15a #\u+15c #\u+1e60 #\u+160 #\u+1e62 #\u+218 #\u+15e)
     #(#\u+1e6a #\u+164 #\u+1e6c #\u+21a #\u+162 #\u+1e70 #\u+1e6e)
     #(#\u+d9 #\u+da #\u+db #\u+168 #\u+16a #\u+16c #\u+dc #\u+1ee6 #\u+16e #\u+170 #\u+1d3 #\u+214 #\u+216 #\u+1af #\u+1ee4 #\u+1e72 #\u+172 #\u+1e76 #\u+1e74)
     #(#\u+1e7c #\u+1e7e)
     #(#\u+1e80 #\u+1e82 #\u+174 #\u+1e86 #\u+1e84 #\u+1e88)
     #(#\u+1e8a #\u+1e8c)
     #(#\u+1ef2 #\u+dd #\u+176 #\u+1ef8 #\u+232 #\u+1e8e #\u+178 #\u+1ef6 #\u+1ef4)
     #(#\u+179 #\u+1e90 #\u+17b #\u+17d #\u+1e92 #\u+1e94)
     #(#\u+e0 #\u+e1 #\u+e2 #\u+e3 #\u+101 #\u+103 #\u+227 #\u+e4 #\u+1ea3 #\u+e5 #\u+1ce #\u+201 #\u+203 #\u+1ea1 #\u+1e01 #\u+105)
     #(#\u+1e03 #\u+1e05 #\u+1e07)
     #(#\u+107 #\u+109 #\u+10b #\u+10d #\u+e7)
     #(#\u+1e0b #\u+10f #\u+1e0d #\u+1e11 #\u+1e13 #\u+1e0f)
     #(#\u+e8 #\u+e9 #\u+ea #\u+1ebd #\u+113 #\u+115 #\u+117 #\u+eb #\u+1ebb #\u+11b #\u+205 #\u+207 #\u+1eb9 #\u+229 #\u+119 #\u+1e19 #\u+1e1b)
     #(#\u+1e1f)
     #(#\u+1f5 #\u+11d #\u+1e21 #\u+11f #\u+121 #\u+1e7 #\u+123)
     #(#\u+125 #\u+1e23 #\u+1e27 #\u+21f #\u+1e25 #\u+1e29 #\u+1e2b #\u+1e96)
     #(#\u+ec #\u+ed #\u+ee #\u+129 #\u+12b #\u+12d #\u+ef #\u+1ec9 #\u+1d0 #\u+209 #\u+20b #\u+1ecb #\u+12f #\u+1e2d)
     #(#\u+135 #\u+1f0)
     #(#\u+1e31 #\u+1e9 #\u+1e33 #\u+137 #\u+1e35)
     #(#\u+13a #\u+13e #\u+1e37 #\u+13c #\u+1e3d #\u+1e3b)
     #(#\u+1e3f #\u+1e41 #\u+1e43)
     #(#\u+1f9 #\u+144 #\u+f1 #\u+1e45 #\u+148 #\u+1e47 #\u+146 #\u+1e4b #\u+1e49)
     #(#\u+f2 #\u+f3 #\u+f4 #\u+f5 #\u+14d #\u+14f #\u+22f #\u+f6 #\u+1ecf #\u+151 #\u+1d2 #\u+20d #\u+20f #\u+1a1 #\u+1ecd #\u+1eb)
     #(#\u+1e55 #\u+1e57)
     #(#\u+155 #\u+1e59 #\u+159 #\u+211 #\u+213 #\u+1e5b #\u+157 #\u+1e5f)
     #(#\u+15b #\u+15d #\u+1e61 #\u+161 #\u+1e63 #\u+219 #\u+15f)
     #(#\u+1e6b #\u+1e97 #\u+165 #\u+1e6d #\u+21b #\u+163 #\u+1e71 #\u+1e6f)
     #(#\u+f9 #\u+fa #\u+fb #\u+169 #\u+16b #\u+16d #\u+fc #\u+1ee7 #\u+16f #\u+171 #\u+1d4 #\u+215 #\u+217 #\u+1b0 #\u+1ee5 #\u+1e73 #\u+173 #\u+1e77 #\u+1e75)
     #(#\u+1e7d #\u+1e7f)
     #(#\u+1e81 #\u+1e83 #\u+175 #\u+1e87 #\u+1e85 #\u+1e98 #\u+1e89)
     #(#\u+1e8b #\u+1e8d)
     #(#\u+1ef3 #\u+fd #\u+177 #\u+1ef9 #\u+233 #\u+1e8f #\u+ff #\u+1ef7 #\u+1e99 #\u+1ef5)
     #(#\u+17a #\u+1e91 #\u+17c #\u+17e #\u+1e93 #\u+1e95)
     #(#\u+1fed #\u+385 #\u+1fc1)
     #(#\u+1ea6 #\u+1ea4 #\u+1eaa #\u+1ea8)
     #(#\u+1de)
     #(#\u+1fa)
     #(#\u+1fc #\u+1e2)
     #(#\u+1e08)
     #(#\u+1ec0 #\u+1ebe #\u+1ec4 #\u+1ec2)
     #(#\u+1e2e)
     #(#\u+1ed2 #\u+1ed0 #\u+1ed6 #\u+1ed4)
     #(#\u+1e4c #\u+22c #\u+1e4e)
     #(#\u+22a)
     #(#\u+1fe)
     #(#\u+1db #\u+1d7 #\u+1d5 #\u+1d9)
     #(#\u+1ea7 #\u+1ea5 #\u+1eab #\u+1ea9)
     #(#\u+1df)
     #(#\u+1fb)
     #(#\u+1fd #\u+1e3)
     #(#\u+1e09)
     #(#\u+1ec1 #\u+1ebf #\u+1ec5 #\u+1ec3)
     #(#\u+1e2f)
     #(#\u+1ed3 #\u+1ed1 #\u+1ed7 #\u+1ed5)
     #(#\u+1e4d #\u+22d #\u+1e4f)
     #(#\u+22b)
     #(#\u+1ff)
     #(#\u+1dc #\u+1d8 #\u+1d6 #\u+1da)
     #(#\u+1eb0 #\u+1eae #\u+1eb4 #\u+1eb2)
     #(#\u+1eb1 #\u+1eaf #\u+1eb5 #\u+1eb3)
     #(#\u+1e14 #\u+1e16)
     #(#\u+1e15 #\u+1e17)
     #(#\u+1e50 #\u+1e52)
     #(#\u+1e51 #\u+1e53)
     #(#\u+1e64)
     #(#\u+1e65)
     #(#\u+1e66)
     #(#\u+1e67)
     #(#\u+1e78)
     #(#\u+1e79)
     #(#\u+1e7a)
     #(#\u+1e7b)
     #(#\u+1e9b)
     #(#\u+1edc #\u+1eda #\u+1ee0 #\u+1ede #\u+1ee2)
     #(#\u+1edd #\u+1edb #\u+1ee1 #\u+1edf #\u+1ee3)
     #(#\u+1eea #\u+1ee8 #\u+1eee #\u+1eec #\u+1ef0)
     #(#\u+1eeb #\u+1ee9 #\u+1eef #\u+1eed #\u+1ef1)
     #(#\u+1ee)
     #(#\u+1ec)
     #(#\u+1ed)
     #(#\u+1e0)
     #(#\u+1e1)
     #(#\u+1e1c)
     #(#\u+1e1d)
     #(#\u+230)
     #(#\u+231)
     #(#\u+1ef)
     #(#\u+1fba #\u+386 #\u+1fb9 #\u+1fb8 #\u+1f08 #\u+1f09 #\u+1fbc)
     #(#\u+1fc8 #\u+388 #\u+1f18 #\u+1f19)
     #(#\u+1fca #\u+389 #\u+1f28 #\u+1f29 #\u+1fcc)
     #(#\u+1fda #\u+38a #\u+1fd9 #\u+1fd8 #\u+3aa #\u+1f38 #\u+1f39)
     #(#\u+1ff8 #\u+38c #\u+1f48 #\u+1f49)
     #(#\u+1fec)
     #(#\u+1fea #\u+38e #\u+1fe9 #\u+1fe8 #\u+3ab #\u+1f59)
     #(#\u+1ffa #\u+38f #\u+1f68 #\u+1f69 #\u+1ffc)
     #(#\u+1fb4)
     #(#\u+1fc4)
     #(#\u+1f70 #\u+3ac #\u+1fb1 #\u+1fb0 #\u+1f00 #\u+1f01 #\u+1fb6 #\u+1fb3)
     #(#\u+1f72 #\u+3ad #\u+1f10 #\u+1f11)
     #(#\u+1f74 #\u+3ae #\u+1f20 #\u+1f21 #\u+1fc6 #\u+1fc3)
     #(#\u+1f76 #\u+3af #\u+1fd1 #\u+1fd0 #\u+3ca #\u+1f30 #\u+1f31 #\u+1fd6)
     #(#\u+1f78 #\u+3cc #\u+1f40 #\u+1f41)
     #(#\u+1fe4 #\u+1fe5)
     #(#\u+1f7a #\u+3cd #\u+1fe1 #\u+1fe0 #\u+3cb #\u+1f50 #\u+1f51 #\u+1fe6)
     #(#\u+1f7c #\u+3ce #\u+1f60 #\u+1f61 #\u+1ff6 #\u+1ff3)
     #(#\u+1fd2 #\u+390 #\u+1fd7)
     #(#\u+1fe2 #\u+3b0 #\u+1fe7)
     #(#\u+1ff4)
     #(#\u+3d3 #\u+3d4)
     #(#\u+407)
     #(#\u+4d0 #\u+4d2)
     #(#\u+403)
     #(#\u+400 #\u+4d6 #\u+401)
     #(#\u+4c1 #\u+4dc)
     #(#\u+4de)
     #(#\u+40d #\u+4e2 #\u+419 #\u+4e4)
     #(#\u+40c)
     #(#\u+4e6)
     #(#\u+4ee #\u+40e #\u+4f0 #\u+4f2)
     #(#\u+4f4)
     #(#\u+4f8)
     #(#\u+4ec)
     #(#\u+4d1 #\u+4d3)
     #(#\u+453)
     #(#\u+450 #\u+4d7 #\u+451)
     #(#\u+4c2 #\u+4dd)
     #(#\u+4df)
     #(#\u+45d #\u+4e3 #\u+439 #\u+4e5)
     #(#\u+45c)
     #(#\u+4e7)
     #(#\u+4ef #\u+45e #\u+4f1 #\u+4f3)
     #(#\u+4f5)
     #(#\u+4f9)
     #(#\u+4ed)
     #(#\u+457)
     #(#\u+476)
     #(#\u+477)
     #(#\u+4da)
     #(#\u+4db)
     #(#\u+4ea)
     #(#\u+4eb)
     #(#\u+622 #\u+623 #\u+625)
     #(#\u+624)
     #(#\u+626)
     #(#\u+6c2)
     #(#\u+6d3)
     #(#\u+6c0)
     #(#\u+929)
     #(#\u+931)
     #(#\u+934)
     #(#\u+9cb #\u+9cc)
     #(#\u+b4b #\u+b48 #\u+b4c)
     #(#\u+b94)
     #(#\u+bca #\u+bcc)
     #(#\u+bcb)
     #(#\u+c48)
     #(#\u+cc0)
     #(#\u+cca #\u+cc7 #\u+cc8)
     #(#\u+ccb)
     #(#\u+d4a #\u+d4c)
     #(#\u+d4b)
     #(#\u+dda #\u+ddc #\u+dde)
     #(#\u+ddd)
     #(#\u+1026)
     #(#\u+1b06)
     #(#\u+1b08)
     #(#\u+1b0a)
     #(#\u+1b0c)
     #(#\u+1b0e)
     #(#\u+1b12)
     #(#\u+1b3b)
     #(#\u+1b3d)
     #(#\u+1b40)
     #(#\u+1b41)
     #(#\u+1b43)
     #(#\u+1e38)
     #(#\u+1e39)
     #(#\u+1e5c)
     #(#\u+1e5d)
     #(#\u+1e68)
     #(#\u+1e69)
     #(#\u+1eac #\u+1eb6)
     #(#\u+1ead #\u+1eb7)
     #(#\u+1ec6)
     #(#\u+1ec7)
     #(#\u+1ed8)
     #(#\u+1ed9)
     #(#\u+1f02 #\u+1f04 #\u+1f06 #\u+1f80)
     #(#\u+1f03 #\u+1f05 #\u+1f07 #\u+1f81)
     #(#\u+1f82)
     #(#\u+1f83)
     #(#\u+1f84)
     #(#\u+1f85)
     #(#\u+1f86)
     #(#\u+1f87)
     #(#\u+1f0a #\u+1f0c #\u+1f0e #\u+1f88)
     #(#\u+1f0b #\u+1f0d #\u+1f0f #\u+1f89)
     #(#\u+1f8a)
     #(#\u+1f8b)
     #(#\u+1f8c)
     #(#\u+1f8d)
     #(#\u+1f8e)
     #(#\u+1f8f)
     #(#\u+1f12 #\u+1f14)
     #(#\u+1f13 #\u+1f15)
     #(#\u+1f1a #\u+1f1c)
     #(#\u+1f1b #\u+1f1d)
     #(#\u+1f22 #\u+1f24 #\u+1f26 #\u+1f90)
     #(#\u+1f23 #\u+1f25 #\u+1f27 #\u+1f91)
     #(#\u+1f92)
     #(#\u+1f93)
     #(#\u+1f94)
     #(#\u+1f95)
     #(#\u+1f96)
     #(#\u+1f97)
     #(#\u+1f2a #\u+1f2c #\u+1f2e #\u+1f98)
     #(#\u+1f2b #\u+1f2d #\u+1f2f #\u+1f99)
     #(#\u+1f9a)
     #(#\u+1f9b)
     #(#\u+1f9c)
     #(#\u+1f9d)
     #(#\u+1f9e)
     #(#\u+1f9f)
     #(#\u+1f32 #\u+1f34 #\u+1f36)
     #(#\u+1f33 #\u+1f35 #\u+1f37)
     #(#\u+1f3a #\u+1f3c #\u+1f3e)
     #(#\u+1f3b #\u+1f3d #\u+1f3f)
     #(#\u+1f42 #\u+1f44)
     #(#\u+1f43 #\u+1f45)
     #(#\u+1f4a #\u+1f4c)
     #(#\u+1f4b #\u+1f4d)
     #(#\u+1f52 #\u+1f54 #\u+1f56)
     #(#\u+1f53 #\u+1f55 #\u+1f57)
     #(#\u+1f5b #\u+1f5d #\u+1f5f)
     #(#\u+1f62 #\u+1f64 #\u+1f66 #\u+1fa0)
     #(#\u+1f63 #\u+1f65 #\u+1f67 #\u+1fa1)
     #(#\u+1fa2)
     #(#\u+1fa3)
     #(#\u+1fa4)
     #(#\u+1fa5)
     #(#\u+1fa6)
     #(#\u+1fa7)
     #(#\u+1f6a #\u+1f6c #\u+1f6e #\u+1fa8)
     #(#\u+1f6b #\u+1f6d #\u+1f6f #\u+1fa9)
     #(#\u+1faa)
     #(#\u+1fab)
     #(#\u+1fac)
     #(#\u+1fad)
     #(#\u+1fae)
     #(#\u+1faf)
     #(#\u+1fb2)
     #(#\u+1fc2)
     #(#\u+1ff2)
     #(#\u+1fb7)
     #(#\u+1fcd #\u+1fce #\u+1fcf)
     #(#\u+1fc7)
     #(#\u+1ff7)
     #(#\u+1fdd #\u+1fde #\u+1fdf)
     #(#\u+219a)
     #(#\u+219b)
     #(#\u+21ae)
     #(#\u+21cd)
     #(#\u+21cf)
     #(#\u+21ce)
     #(#\u+2204)
     #(#\u+2209)
     #(#\u+220c)
     #(#\u+2224)
     #(#\u+2226)
     #(#\u+2241)
     #(#\u+2244)
     #(#\u+2247)
     #(#\u+2249)
     #(#\u+226d)
     #(#\u+2262)
     #(#\u+2270)
     #(#\u+2271)
     #(#\u+2274)
     #(#\u+2275)
     #(#\u+2278)
     #(#\u+2279)
     #(#\u+2280)
     #(#\u+2281)
     #(#\u+22e0)
     #(#\u+22e1)
     #(#\u+2284)
     #(#\u+2285)
     #(#\u+2288)
     #(#\u+2289)
     #(#\u+22e2)
     #(#\u+22e3)
     #(#\u+22ac)
     #(#\u+22ad)
     #(#\u+22ae)
     #(#\u+22af)
     #(#\u+22ea)
     #(#\u+22eb)
     #(#\u+22ec)
     #(#\u+22ed)
     #(#\u+3094)
     #(#\u+304c)
     #(#\u+304e)
     #(#\u+3050)
     #(#\u+3052)
     #(#\u+3054)
     #(#\u+3056)
     #(#\u+3058)
     #(#\u+305a)
     #(#\u+305c)
     #(#\u+305e)
     #(#\u+3060)
     #(#\u+3062)
     #(#\u+3065)
     #(#\u+3067)
     #(#\u+3069)
     #(#\u+3070 #\u+3071)
     #(#\u+3073 #\u+3074)
     #(#\u+3076 #\u+3077)
     #(#\u+3079 #\u+307a)
     #(#\u+307c #\u+307d)
     #(#\u+309e)
     #(#\u+30f4)
     #(#\u+30ac)
     #(#\u+30ae)
     #(#\u+30b0)
     #(#\u+30b2)
     #(#\u+30b4)
     #(#\u+30b6)
     #(#\u+30b8)
     #(#\u+30ba)
     #(#\u+30bc)
     #(#\u+30be)
     #(#\u+30c0)
     #(#\u+30c2)
     #(#\u+30c5)
     #(#\u+30c7)
     #(#\u+30c9)
     #(#\u+30d0 #\u+30d1)
     #(#\u+30d3 #\u+30d4)
     #(#\u+30d6 #\u+30d7)
     #(#\u+30d9 #\u+30da)
     #(#\u+30dc #\u+30dd)
     #(#\u+30f7)
     #(#\u+30f8)
     #(#\u+30f9)
     #(#\u+30fa)
     #(#\u+30fe)
     #(#\u+1109a)
     #(#\u+1109c)
     #(#\u+110ab)
     #(#\u+1112e)
     #(#\u+1112f)
     #(#\u+1134b #\u+1134c)
     #(#\u+114bc #\u+114bb #\u+114be)
     #(#\u+115ba)
     #(#\u+115bb))))
