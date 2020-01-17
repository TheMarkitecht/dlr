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

# ############ strtolTest and its types ######################################

#todo: upgrade with better passMethod's and scriptForm's.  native, int, float, list (for structs), dict (for structs).
::dlr::declareCallToNative  testLib  {long asInt}  strtolTest  {
    {in     byPtr   char        str             asString}
    {out    byPtr   ptr         endP            asInt}
    {in     byVal   int         radix           asInt}
}
if [::dlr::refreshMeta] {
    ::dlr::generateCallProc  testLib  strtolTest
}
source [callWrapperPath  testLib  strtolTest]

# ############ mulByValue and its types ######################################

# extract type metadata from C.
::dlr::declareStructType  testLib  quadT  {
    {int  a  asInt}
    {int  b  asInt}
    {int  c  asInt}
    {int  d  asInt}
}
if [::dlr::refreshMeta] {
    set ::test::quadT [::dlr::detectStructLayout  testLib  quadT]
    # capturing the result there in ::test is for testing only; normally that's not needed.
}
validateStructType  testLib  quadT
if [::dlr::refreshMeta] {
    ::dlr::generateStructConverters  testLib  quadT
}
source [structConverterPath  testLib  quadT]

::dlr::declareCallToNative  testLib  {quadT asList}  mulByValue  {
    {in     byVal   quadT     st              asList}
    {in     byVal   int             factor          asInt}
}
if [::dlr::refreshMeta] {
    ::dlr::generateCallProc  testLib  mulByValue
}
source [callWrapperPath  testLib  mulByValue]
