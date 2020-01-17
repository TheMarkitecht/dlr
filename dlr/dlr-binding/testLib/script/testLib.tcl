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


# this binding script sets up all metdata required to use the library "testLib" in a script app.

# after each declaration, this binding script source's the generated support scripts.
# per the app's needs, it could instead define its own support procs.
# or it could source the generated ones, and then modify or further wrap certain ones.

# ############ strtolTest and its types ######################################

#todo: upgrade with better passMethod's and scriptForm's.  native, int, float, list (for structs), dict (for structs).
declareCallToNative  testLib  {long asInt}  strtolTest  {
    {in     byPtr   char    str     asString}
    {out    byPtr   ptr     endP    asInt}
    {in     byVal   int     radix   asInt}
}
source [callWrapperPath  testLib  strtolTest]

# ############ mulByValue and its types ######################################

# extract type metadata from C.
declareStructType  testLib  quadT  {
    {int  a  asInt}
    {int  b  asInt}
    {int  c  asInt}
    {int  d  asInt}
}
source [structConverterPath  testLib  quadT]

declareCallToNative  testLib  {quadT asList}  mulByValue  {
    {in     byVal   quadT   st      asList}
    {in     byVal   int     factor  asInt}
}
source [callWrapperPath  testLib  mulByValue]
