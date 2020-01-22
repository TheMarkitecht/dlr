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

declareCallToNative  applyScript  testLib  {long asInt}  strtolTest  {
    {in     byPtr   ascii   str     asString}
    {out    byPtr   ptr     endP    asInt}
    {in     byVal   int     radix   asInt}
}

# ############ mulByValue and its types ######################################

# extract type metadata from C.
declareStructType  applyScript  testLib  quadT  {
    {int  a  asInt}
    {int  b  asInt}
    {int  c  asInt}
    {int  d  asInt}
}

declareCallToNative  applyScript  testLib  {quadT asList}  mulByValue  {
    {in     byVal   quadT   st      asList}
    {in     byVal   int     factor  asInt}
}

declareCallToNative  applyScript  testLib  {quadT asDict}  mulDict  {
    {in     byVal   quadT   st      asDict}
    {in     byVal   int     factor  asInt}
}

# ############ dataHandler and its types ######################################
typedef  u32  dataHandleT
declareCallToNative  applyScript  testLib  {dataHandleT asInt}  dataHandler  {
    {in     byVal   dataHandleT    handle     asInt}
}

declareCallToNative  applyScript  testLib  {dataHandleT asInt}  dataHandlerPtr  {
    {inOut     byPtr   dataHandleT    handleP     asInt}
}

declareCallToNative  applyScript  testLib  {void}  dataHandlerVoid  {
    {inOut     byPtr   dataHandleT    handleP     asInt}
}

# ############ floatSquare and its types ######################################
declareCallToNative  applyScript  testLib  {float asDouble}  floatSquare  {
    {in     byVal   double      stuff       asDouble}
    {in     byVal   longDouble  longStuff   asDouble}
}

declareCallToNative  applyScript  testLib  {void}  floatSquarePtr  {
    {inOut     byPtr   double    stuff     asDouble}
}

# ############ cryptAscii and its types ######################################
declareCallToNative  applyScript  testLib  {void}  cryptAscii  {
    {inOut  byPtr   ascii   clear   asString}
    {in     byVal   int     step    asInt}
}

declareCallToNative  applyScript  testLib  {void}  cryptAsciiMalloc  {
    {in     byPtr   ascii   clear   asString}
    {out    byPtr   ptr     crypted asInt}
    {in     byVal   int     step    asInt}
}
proc  ::dlr::lib::testLib::cryptAsciiMalloc::callManaged {clear cryptedVar step} {
    # this is an additional little wrapper proc to manage memory according to the app's needs.
    # it would run faster if we totally replaced ::dlr::lib::testLib::cryptAsciiMalloc::call
    # with this proc, but this way instead demonstrates the easiest binding development.
    upvar 1 $cryptedVar crypted
    set cryptedP 0
    ::dlr::lib::testLib::cryptAsciiMalloc::call $clear cryptedP $step
    set crypted [::dlr::simple::ascii::unpack-scriptPtr-asString $cryptedP]
    ::dlr::freeHeap $cryptedP
}

declareCallToNative  applyScript  testLib  {ptr asInt}  cryptAsciiRtn  {
    {in     byPtr   ascii   clear   asString}
    {in     byVal   int     step    asInt}
}
proc  ::dlr::lib::testLib::cryptAsciiRtn::callManaged {clear step} {
    # this is an additional little wrapper proc to manage memory according to the app's needs.
    set cryptedP [::dlr::lib::testLib::cryptAsciiRtn::call $clear $step]
    set crypted [::dlr::simple::ascii::unpack-scriptPtr-asString $cryptedP]
    ::dlr::freeHeap $cryptedP
    return $crypted
}

# ############ mulPtr and its types ######################################

declareCallToNative  applyScript  testLib  {void}  mulPtr  {
    {inOut  byPtr   quadT   st      asList}
    {in     byVal   int     factor  asInt}
}

declareCallToNative  applyScript  testLib  {ptr asInt}  mulMalloc  {
    {in     byVal   quadT   st      asList}
    {in     byVal   int     factor  asInt}
}
proc  ::dlr::lib::testLib::mulMalloc::callManaged {st factor} {
    # this is an additional little wrapper proc to manage memory according to the app's needs.
    set quadP [::dlr::lib::testLib::mulMalloc::call $st $factor]
    ::dlr::copyToBufferVar  quadNative  $::dlr::lib::testLib::struct::quadT::size  $quadP
    set quad [::dlr::lib::testLib::struct::quadT::unpack-byVal-asList $quadNative]
    ::dlr::freeHeap $quadP
    return $quad
}
#todo: factor out "copy from ptr" and "copy from ptr and free" for ascii and struct.


