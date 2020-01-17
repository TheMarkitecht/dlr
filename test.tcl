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

set do_bench $($::argc == 1)
if {$do_bench} { 
    set bench_reps $(int([lindex $::argv 0])) 
}

puts bits::int=$::dlr::bits::int
puts bits::ptr=$::dlr::bits::ptr

# test local vars in pack api.
::dlr::pack::int-byVal-asInt   myLocal  89
assert {[::dlr::unpack::int-byVal-asInt  $myLocal] == 89}

# test extracting type metadata from C, and generating wrapper scripts.
# normally this would be done only after changing the shared library's source code, 
# not on each run of the script app.
::dlr::refreshMeta $( ! $do_bench)

# load the library binding that was generated just now.
assert {[llength [::dlr::allLibAliases]] == 0}
::dlr::loadLib  testLib  [file join $::appDir testLib-src testLib.so]
assert {[llength [::dlr::allLibAliases]] == 1}
assert {[lindex [::dlr::allLibAliases] 0] eq {testLib}}
if [::dlr::refreshMeta] {
    set dic $::test::mulByValueT
    puts "detected: name=$dic(name)  size=$dic(size)  cOfs=[dict get $dic members c offset]"
    assert {[dict get $dic members a offset] == 0} ;# all the other offsets beyond this first one depend on the compiler's word size and structure packing behavior.
    assert {[dict get $dic members c size] == $::dlr::size::int}
}

# strtolWrap test
alias  strtol  ::dlr::lib::testLib::strtolWrap::call
loop attempt 0 3 {
    set myNum $(550 + $attempt * 3)
    # addrOf requires a string, so it will implicitly use the string representation of myNum.
    puts strP=[format $::dlr::ptrFmt [::dlr::addrOf myNum]]
    set endP 0
    set resultUnpacked [strtol  $myNum  endP  10]
    puts $myNum=$resultUnpacked
    assert {$resultUnpacked == $myNum}
    # can't do reliable pointer arithmetic to verify new value of endP, 
    # due to copies being made during packing.
    # instead just verify it's not zero, and it's within about 100 MB of strP, meaning
    # it's somewhere on the same heap as strP.
    puts endP=[format $::dlr::ptrFmt $endP]
    assert {$endP != 0}
    set strPmasked $( [::dlr::addrOf myNum] & 0xfffffffff0000000 )
    set endPmasked $(                 $endP & 0xfffffffff0000000 )
    assert {$endPmasked == $strPmasked}

    # verify "constant" dlr::null was not overwritten.  that could have happened in older versions of this test.
    assert {[::dlr::unpack::ptr-byVal-asInt $::dlr::null] == 0}
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

# speed benchmark.  test conditions very comparable to bench-0.1.tcl.  
# difference is under 1%, far less than the background noise from the OS multitasking.
if {$do_bench} {
    set str 905
    set endP 0
    bench fullWrap $($bench_reps / 10) {
        strtol  $str  endP  10
    }
    set endP $::dlr::null
    ::dlr::pack::ptr-byVal-asInt  ::dlr::lib::testLib::strtolWrap::parm::endP  [::dlr::addrOf endP]
    bench pack3 $($bench_reps / 10) {   
        ::dlr::pack::ptr-byVal-asInt  ::dlr::lib::testLib::strtolWrap::parm::strP  [::dlr::addrOf str]
        ::dlr::pack::ptr-byVal-asInt  ::dlr::lib::testLib::strtolWrap::parm::endPP [::dlr::addrOf ::dlr::lib::testLib::strtolWrap::parm::endP]
        ::dlr::pack::int-byVal-asInt  ::dlr::lib::testLib::strtolWrap::parm::radix  10
    }
    bench callToNative $bench_reps {
        ::dlr::callToNative  ::dlr::lib::testLib::strtolWrap::meta  
    }
}

puts "*** ALL TESTS PASS ***"
