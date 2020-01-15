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
    set elapseMs $([clock milliseconds] - $beginMs)
    set eachUs $(double($elapseMs) / double($reps) * 1000.0)
    puts [format "    time=%0.3fs  each=%0.1fus" $(double($elapseMs) / 1000.0) $eachUs]
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
# normally this would be done only after changing the shared library's source code, 
# not on each run of the script app.
# normally this would be done by including a .h file, but in this test we include 
# a .c file instead, and from a specific path.
set inc "
    #include \"[file join $::appDir testLib-src testLib.c]\"
"
set dic [::dlr::detectStructLayout  testLib  mulByValueT  $inc  $::dlr::defaultCompiler {a b c d}]
puts "detected: name=$dic(name)  size=$dic(size)  cOfs=[dict get $dic members c offset]"
assert {[dict get $dic members a offset] == 0} ;# all the other offsets depend on the compiler's word size and structure packing behavior.
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
    assert {[::dlr::unpack::ptr $::dlr::null] == 0}
}

# speed benchmark.  test conditions very comparable to bench-0.1.tcl.  
# difference is under 1%, far less than the background noise from the OS multitasking.
if {$::argc == 1} {
    set reps $(int([lindex $::argv 0]))
    if {$reps > 0} {
        set str 905
        set endP $::dlr::null
        ::dlr::pack::ptr  ::dlr::lib::testLib::strtolWrap::parm::endP  [::dlr::addrOf endP]
        bench fullWrap $($reps / 10) {
            strtol  $str  endP  10
        }
        bench pack3 $($reps / 10) {   
            ::dlr::pack::ptr  ::dlr::lib::testLib::strtolWrap::parm::strP  [::dlr::addrOf str]
            ::dlr::pack::ptr  ::dlr::lib::testLib::strtolWrap::parm::endPP [::dlr::addrOf ::dlr::lib::testLib::strtolWrap::parm::endP]
            ::dlr::pack::int  ::dlr::lib::testLib::strtolWrap::parm::radix  10
        }
        bench callToNative $reps {
            ::dlr::callToNative  ::dlr::lib::testLib::strtolWrap::meta  
        }
        exit 0
    }
}

# mulByValue test
alias  mulByValue  ::dlr::lib::testLib::mulByValue::call
loop attempt 2 5 {
    lassign [mulByValue {10 11 12 13} $attempt] a b c d
    assert {$a == 10 * $attempt}
    assert {$b == 11 * $attempt}
    assert {$c == 12 * $attempt}
    assert {$d == 13 * $attempt}
    puts mulByValueT.d=$d
}

# allocHeap test
loop attempt 0 3 {
    set chunk [::dlr::allocHeap 0x400000]
    puts chunk=[format $::dlr::ptrFmt $chunk]
    # todo: call memcpy() from dlr-libc
    ::dlr::freeHeap $chunk
}


