#  "dlr" - Dynamic Library Redux
#  Copyright 2020 Mark Hubbard, a.k.a. "TheMarkitecht"
#  http://www.TheMarkitecht.com
#
#  Project home:  http://github.com/TheMarkitecht/dlr
#  dlr is an extension for Jim Tcl (http://jim.tcl.tk/)
#  dlr may be easily pronounced as "dealer".
#
#  This file is part of dlr.
#
#  dlr is free software: you can redistribute it and/or modify
#  it under the terms of the GNU Lesser General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  dlr is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU Lesser General Public License for more details.
#
#  You should have received a copy of the GNU Lesser General Public License
#  along with dlr.  If not, see <https://www.gnu.org/licenses/>.


# this binding script sets up all metadata required to use the library "testLib" in a script app.

# ############ strtolTest and its types ######################################

declareCallToNative  applyScript  testLib  {byVal long asInt}  strtolTest  {
    {in     byPtr   ascii   str     asString            }
    {out    byPtr   ptr     endP    asInt       ignore  }
    {in     byVal   int     radix   asInt               }
}
# according to its C header, the endP parameter is 'byPtrPtr ascii'.  but here,
# endP is declared 'byPtr ptr' instead, because we don't want to automatically
# unpack a string from it.  instead we'll just pass back to app script the
# char * pointer asInt instead.
# memAction 'ignore' skips any automatic memory management on endP also.

# ############ mulByValue and its types ######################################

# extract type metadata from C.
declareStructType  applyScript  testLib  quadT  {
    {int  a  asInt}
    {int  b  asInt}
    {int  c  asInt}
    {int  d  asInt}
}

declareCallToNative  applyScript  testLib  {byVal quadT asList}  mulByValue  {
    {in     byVal   quadT   st      asList}
    {in     byVal   int     factor  asInt}
}

declareCallToNative  applyScript  testLib  {byVal quadT asDict}  mulDict  {
    {in     byVal   quadT   st      asDict}
    {in     byVal   int     factor  asInt}
}

# ############ dataHandler and its types ######################################
typedef  u32  dataHandleT
declareCallToNative  applyScript  testLib  {byVal dataHandleT asInt}  dataHandler  {
    {in     byVal   dataHandleT    handle     asInt}
}

declareCallToNative  applyScript  testLib  {byVal dataHandleT asInt}  dataHandlerPtr  {
    {inOut     byPtr   dataHandleT    handleP     asInt     ignore  }
}

declareCallToNative  applyScript  testLib  {void}  dataHandlerVoid  {
    {inOut     byPtr   dataHandleT    handleP     asInt     ignore  }
}

# ############ floatSquare and its types ######################################
declareCallToNative  applyScript  testLib  {byVal float asDouble}  floatSquare  {
    {in     byVal   double      stuff       asDouble}
    {in     byVal   longDouble  longStuff   asDouble}
}

declareCallToNative  applyScript  testLib  {void}  floatSquarePtr  {
    {inOut     byPtr   double    stuff     asDouble     ignore }
}

# ############ cryptAscii and its types ######################################
declareCallToNative  applyScript  testLib  {void}  cryptAscii  {
    {inOut  byPtr   ascii   clear   asString    ignore  }
    {in     byVal   int     step    asInt               }
}

declareCallToNative  applyScript  testLib  {void}  cryptAsciiMalloc  {
    {in     byPtr       ascii   clear   asString        }
    {out    byPtrPtr    ascii   crypted asString    free}
    {in     byVal       int     step    asInt           }
}

declareCallToNative  applyScript  testLib  {byPtr ascii asString free}  cryptAsciiRtn  {
    {in     byPtr   ascii   clear   asString}
    {in     byVal   int     step    asInt}
}

# ############ mulPtr and its types ######################################

declareCallToNative  applyScript  testLib  {void}  mulPtr  {
    {inOut  byPtr   quadT   st      asList  ignore  }
    {in     byVal   int     factor  asInt           }
}

declareCallToNative  applyScript  testLib  {void}  mulMalloc  {
    {out    byPtrPtr    quadT   st      asList    free  }
    {in     byVal       int     factor  asInt           }
}

declareCallToNative  applyScript  testLib  {byPtr quadT asList free}  mulMallocRtn  {
    {in     byVal   quadT   st      asList}
    {in     byVal   int     factor  asInt}
}

declareCallToNative  applyScript  testLib  {void}  mulPtrNat  {
    {inOut  byPtr   quadT   st      asNative  ignore  }
    {in     byVal   int     factor  asInt             }
}

declareCallToNative  applyScript  testLib  {byPtr quadT asNative free}  mulMallocRtnNat  {
    {in     byVal   int     factor  asInt}
}

