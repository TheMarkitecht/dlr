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

set version [package require dlr]
puts version=$version

puts bitsOfInt=$::dlr::bitsOfInt
puts bitsOfPtr=$::dlr::bitsOfPtr

::dlr::loadLib  testLib  ./dlrTestLib.so

# strtol test
set ::dlr::lib::testLib::strtolWrap::parmOrder {
    ::dlr::lib::testLib::strtolWrap::parm::strP
    ::dlr::lib::testLib::strtolWrap::parm::endPP
    ::dlr::lib::testLib::strtolWrap::parm::radix
}
::dlr::prepMetaBlob  meta  [::dlr::fnAddr  strtolWrap  testLib]  \
    ::dlr::lib::testLib::strtolWrap::result  12  \
    $::dlr::lib::testLib::strtolWrap::parmOrder  {14 14 10}
loop attempt 0 5 {
    set myNum $(550 + $attempt * 3)
    # addrOf requires a string, so it will implicitly use the string representation of myNum.
    puts strP=[format $::dlr::ptrFmt [::dlr::addrOf myNum]]
    ::dlr::pack::ptr  ::dlr::lib::testLib::strtolWrap::parm::strP  [::dlr::addrOf myNum]
    set endP $::dlr::null
    ::dlr::pack::ptr  ::dlr::lib::testLib::strtolWrap::parm::endPP  [::dlr::addrOf endP]
    ::dlr::pack::int  ::dlr::lib::testLib::strtolWrap::parm::radix  10
    
    set resultUnpack [::dlr::unpack::int [::dlr::callToNative  meta]]
    puts $myNum=$resultUnpack
    assert {$resultUnpack == $myNum}
    
    set endPUnpack [unpack $endP -intle 0 $::dlr::bitsOfPtr]
    set len $($endPUnpack - [::dlr::addrOf myNum])
    puts endP=[format $::dlr::ptrFmt $endPUnpack]
    puts len=$len
    assert {$len == [string length $myNum]}
    
    set chunk [::dlr::allocHeap 0x400000]
    puts chunk=[format $::dlr::ptrFmt $chunk]
    # todo: call memcpy() from dlr-libc
    ::dlr::freeHeap $chunk
}
