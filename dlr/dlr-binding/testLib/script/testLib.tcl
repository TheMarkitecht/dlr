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


# this script sets up all metdata required to use the library "testLib" in a script app.

# ############ strtolWrap and its types ######################################

#todo: upgrade with better passMethod's and scriptForm's.  native, int, float, list (for structs), dict (for structs).
::dlr::declareCallToNative  testLib  {long asInt}  strtolWrap  {
    {in     byPtr   char        str             asString}
    {out    byPtr   ptr         endP            asInt}
    {in     byVal   int         radix           asInt}
}
if [::dlr::refreshMeta] {
    ::dlr::generateCallProc  testLib  strtolWrap
}
source [callWrapperPath  testLib  strtolWrap]

# ############ mulByValue and its types ######################################

# extract type metadata from C.
set members {
    {int  a  asInt}
    {int  b  asInt}
    {int  c  asInt}
    {int  d  asInt}
}
if [::dlr::refreshMeta] {
    # normally this would be done by including a .h file, but in this test we include 
    # a .c file instead, and from a specific path.
    #todo: move this to a .h file in script/ and always include just that one.  eliminate this code snippet here.
    set inc "
        #include \"[file join $::appDir testLib-src testLib.c]\"
    "
    set ::test::mulByValueT [::dlr::detectStructLayout  testLib  mulByValueT  \
        $inc  $::dlr::defaultCompiler $members]
    # capturing the result there in ::test is for testing only; normally that's not needed.
}
::dlr::declareStructType  testLib  mulByValueT  $members
#todo: refactor struct extraction and validation so it can all happen in one call, with the members list appearing just once, at declareStructType.
if [::dlr::refreshMeta] {
    ::dlr::generateStructConverters  testLib  mulByValueT
}
source [structConverterPath  testLib  mulByValueT]

::dlr::declareCallToNative  testLib  {mulByValueT asList}  mulByValue  {
    {in     byVal   mulByValueT     st              asList}
    {in     byVal   int             factor          asInt}
}
if [::dlr::refreshMeta] {
    ::dlr::generateCallProc  testLib  mulByValue
}
source [callWrapperPath  testLib  mulByValue]
