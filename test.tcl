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

set ::appDir [file dirname [info script]]

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

# test local vars in pack api.
::dlr::pack::int  myLocal  89
assert {[::dlr::unpack::int $myLocal] == 89}

# test extracting type metadata from C.
# normally this would be done by including a .h file, but in this test we include 
# a .c file instead, and from a specific path.
set inc "
    #include \"[file join $::appDir testLib-src testLib.c]\"
"
set dic [::dlr::getStructLayout  testLib  mulByValueT  $inc  $::dlr::defaultCompiler {a b c d}]
puts "name=$dic(name)  size=$dic(size)  cOfs=[dict get $dic members c ofs]"
assert {[dict get $dic members a ofs] == 0} ;# all the other offsets depend on the compiler's word size and structure packing behavior.
assert {[dict get $dic members c size] == $::dlr::size::int}

# load the library binding that was generated just now.
::dlr::loadLib  testLib  [file join $::appDir testLib-src testLib.so]

# strtolWrap test
alias  strtol  ::dlr::lib::testLib::strtolWrap::call
loop attempt 0 3 {
    set myNum $(550 + $attempt * 3)
    # addrOf requires a string, so it will implicitly use the string representation of myNum.
    puts strP=[format $::dlr::ptrFmt [::dlr::addrOf myNum]]
    set endP $::dlr::null
    set resultUnpacked [strtol  $myNum  endP  10]
    puts $myNum=$resultUnpacked
    assert {$resultUnpacked == $myNum}
    set len $($endP - [::dlr::addrOf myNum])
    puts endP=[format $::dlr::ptrFmt $endP]
    puts len=$len
    assert {$len == [string length $myNum]}
}

# speed benchmark.  test conditions very comparable to bench-0.1.tcl.  
# difference is under 1%, far less than the background noise from the OS multitasking.
if {$::argc == 1} {
    set reps $(int([lindex $::argv 0]))
    if {$reps > 0} {
        set str 905
        set endP $::dlr::null
        bench fullWrap $reps {
            strtol  $str  endP  10
        }
        bench pack3 $($reps / 10) {   
            ::dlr::pack::ptr  ::dlr::lib::testLib::strtolWrap::parm::strP  [::dlr::addrOf str]
            ::dlr::pack::ptr  ::dlr::lib::testLib::strtolWrap::parm::endP  [::dlr::addrOf endP]
            ::dlr::pack::ptr  ::dlr::lib::testLib::strtolWrap::parm::endPP [::dlr::addrOf ::dlr::lib::testLib::strtolWrap::parm::endP]
            ::dlr::pack::int  ::dlr::lib::testLib::strtolWrap::parm::radix  $radix
        }
        bench callToNative $reps {
            ::dlr::callToNative  ::dlr::lib::testLib::strtolWrap::meta  
        }
        exit 0
    }
}

exit 0 ;# todo

# mulByValue test
loop attempt 2 5 {
    #todo: fetch sizeof arbitrary type, and offsetof, to allow for padding here.  for now it just allocates oversize.
    ::dlr::createBufferVar  ::dlr::lib::testLib::mulByValue::parm::st  32
    
    set ofs [::dlr::pack::int  ::dlr::lib::testLib::mulByValue::parm::st  10]
    set ofs [::dlr::pack::int  ::dlr::lib::testLib::mulByValue::parm::st  11  $ofs]
    set ofs [::dlr::pack::int  ::dlr::lib::testLib::mulByValue::parm::st  12  $ofs]
    set ofs [::dlr::pack::int  ::dlr::lib::testLib::mulByValue::parm::st  13  $ofs]
    ::dlr::pack::int  ::dlr::lib::testLib::mulByValue::parm::factor  $attempt
    
    set resultBuf [::dlr::lib::testLib::mulByValue::call]
    set ofs 0
    assert {[::dlr::unpack::int $resultBuf ofs] == 10 * $attempt}
    assert {[::dlr::unpack::int $resultBuf ofs] == 11 * $attempt}
    assert {[::dlr::unpack::int $resultBuf ofs] == 12 * $attempt}
    assert {[::dlr::unpack::int $resultBuf ofs] == 13 * $attempt}
}

# allocHeap test
loop attempt 0 3 {
    set chunk [::dlr::allocHeap 0x400000]
    puts chunk=[format $::dlr::ptrFmt $chunk]
    # todo: call memcpy() from dlr-libc
    ::dlr::freeHeap $chunk
}


