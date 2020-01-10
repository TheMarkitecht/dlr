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

proc assert {exp} {
    set truth [uplevel 1 [list expr $exp]]
    if { ! $truth} {
        error "ASSERT FAILED: $exp"
    }
}

puts paths=$::auto_path

package require dlr

puts bitsOfInt=$::dlr::bitsOfInt
puts bitsOfPtr=$::dlr::bitsOfPtr

::dlr::loadLib  testLib  ./dlrTestLib.so

# strtol speed test
#todo: see how many times the interp hashes these long strings.  need to shorten for speed??  or move to a dict or list?
set ::parmOrder {
    ::strP
    ::endPP
    ::radix
}
::dlr::prepMetaBlob  meta  [::dlr::fnAddr  test_strtol  testLib]  \
    ::result  12  \
    $::parmOrder  {14 14 10}
set myNum $(550)
::dlr::pack::ptr  ::strP  [::dlr::addrOf myNum]
set endP $::dlr::null
::dlr::pack::ptr  ::endPP  [::dlr::addrOf endP]
::dlr::pack::int  ::radix  10
loop attempt 0 30000000 {   
    ::dlr::callToNative  meta  strP  endPP  radix
}
set resultUnpack [::dlr::unpack::int $::result]
puts $myNum=$resultUnpack
assert {$resultUnpack == $myNum}
