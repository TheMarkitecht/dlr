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

proc bench {label  reps  script} {
    puts "$label:  reps=$reps"
    flush stdout
    set beginMs [clock milliseconds]
    uplevel 1 loop attempt 0 $reps \{ $script \}
    set elapse $([clock milliseconds] - $beginMs)
    set each $(double($elapse) / double($reps) * 1000000.0)
    puts [format "    time=%0.3fs  each=%0.1fus" $elapse $each]
    flush stdout
}

puts paths=$::auto_path

set version [package require dlr]
puts version=$version

puts bits::int=$::dlr::bits::int
puts bits::ptr=$::dlr::bits::ptr

::dlr::loadLib  testLib  ./dlrTestLib.so

# strtol test
set ::dlr::lib::testLib::strtolWrap::parmOrder {
    ::dlr::lib::testLib::strtolWrap::parm::strP
    ::dlr::lib::testLib::strtolWrap::parm::endPP
    ::dlr::lib::testLib::strtolWrap::parm::radix
}
::dlr::prepMetaBlob  meta  [::dlr::fnAddr  strtolWrap  testLib]  \
    ::dlr::lib::testLib::strtolWrap::result  ::dlr::type::long  \
    $::dlr::lib::testLib::strtolWrap::parmOrder  \
    [list  ::dlr::type::ptr  ::dlr::type::ptr  ::dlr::type::int]
loop attempt 0 3 {
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
    
    set endPUnpack [unpack $endP -intle 0 $::dlr::bits::ptr]
    set len $($endPUnpack - [::dlr::addrOf myNum])
    puts endP=[format $::dlr::ptrFmt $endPUnpack]
    puts len=$len
    assert {$len == [string length $myNum]}
}

# speed benchmark.  test conditions very comparable to bench-0.1.tcl.  
# difference is under 1%, far less than the background noise from the OS multitasking.
if {$::argc == 1} {
    set reps $(int([lindex $::argv 0]))
    if {$reps > 0} {
        bench callToNative $reps {
            ::dlr::callToNative  meta  
        }
        bench pack3 $($reps / 10) {   
            ::dlr::pack::ptr  ::dlr::lib::testLib::strtolWrap::parm::strP  [::dlr::addrOf myNum]
            set endP $::dlr::null
            ::dlr::pack::ptr  ::dlr::lib::testLib::strtolWrap::parm::endPP  [::dlr::addrOf endP]
            ::dlr::pack::int  ::dlr::lib::testLib::strtolWrap::parm::radix  10
        }
        bench pack3-and-call $($reps / 10) {   
            ::dlr::pack::ptr  ::dlr::lib::testLib::strtolWrap::parm::strP  [::dlr::addrOf myNum]
            set endP $::dlr::null
            ::dlr::pack::ptr  ::dlr::lib::testLib::strtolWrap::parm::endPP  [::dlr::addrOf endP]
            ::dlr::pack::int  ::dlr::lib::testLib::strtolWrap::parm::radix  10
            ::dlr::callToNative  meta  
        }
        exit 0
    }
}

# allocHeap test
loop attempt 0 3 {
    set chunk [::dlr::allocHeap 0x400000]
    puts chunk=[format $::dlr::ptrFmt $chunk]
    # todo: call memcpy() from dlr-libc
    ::dlr::freeHeap $chunk
}

# mulByValue test
::dlr::prepStructType  ::dlr::lib::testLib::mulByValueT  [list  \
    ::dlr::type::int  ::dlr::type::int  ::dlr::type::int  ::dlr::type::int]
set ::dlr::lib::testLib::mulByValue::parmOrder {
    ::dlr::lib::testLib::mulByValue::parm::st
    ::dlr::lib::testLib::mulByValue::parm::factor
}
::dlr::prepMetaBlob  meta2  [::dlr::fnAddr  mulByValue  testLib]  \
    ::dlr::lib::testLib::mulByValue::result  ::dlr::lib::testLib::mulByValueT  \
    $::dlr::lib::testLib::mulByValue::parmOrder  \
    [list  ::dlr::lib::testLib::mulByValueT  ::dlr::type::int]
loop attempt 2 5 {
    #todo: fetch sizeof arbitrary type, and offsetof, to allow for padding here.  for now it just allocates oversize.
    ::dlr::createBufferVar  ::dlr::lib::testLib::mulByValue::parm::st  32
    
    set ofs [::dlr::pack::int  ::dlr::lib::testLib::mulByValue::parm::st  10]
    set ofs [::dlr::pack::int  ::dlr::lib::testLib::mulByValue::parm::st  11  $ofs]
    set ofs [::dlr::pack::int  ::dlr::lib::testLib::mulByValue::parm::st  12  $ofs]
    set ofs [::dlr::pack::int  ::dlr::lib::testLib::mulByValue::parm::st  13  $ofs]
    ::dlr::pack::int  ::dlr::lib::testLib::mulByValue::parm::factor  $attempt
    
    set resultBuf [::dlr::callToNative  meta2]
    set ofs 0
    assert {[::dlr::unpack::int $resultBuf ofs] == 10 * $attempt}
    assert {[::dlr::unpack::int $resultBuf ofs] == 11 * $attempt}
    assert {[::dlr::unpack::int $resultBuf ofs] == 12 * $attempt}
    assert {[::dlr::unpack::int $resultBuf ofs] == 13 * $attempt}
}

# test local vars in pack api.
::dlr::pack::int  myLocal  89
assert {[::dlr::unpack::int $myLocal] == 89}

# test extracting type metadata from C.
set inc {
    #include "dlrTestLib.c"
}
set dic [::dlr::compileType  mulByValueT  $inc  $::dlr::defaultCompiler {a b c d}]
puts "name=$dic(name)  size=$dic(size)  cOfs=[dict get $dic members c ofs]"
assert {[dict get $dic members a ofs] == 0} ;# all the other offsets depend on the compiler's word size and structure packing behavior.
assert {[dict get $dic members c size] == $::dlr::size::int}
