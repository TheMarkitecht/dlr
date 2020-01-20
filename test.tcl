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

set ::appDir [file join [pwd] [file dirname [info script]]]

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

lassign  $::argv  metaAction  benchReps

puts "int::bits=$::dlr::simple::int::bits  long::bits=$::dlr::simple::long::bits  ptr::bits=$::dlr::simple::ptr::bits"

# test local vars in pack api.
::dlr::simple::int::pack-byVal-asInt   myLocal  89
assert {[::dlr::simple::int::unpack-byVal-asInt  $myLocal] == 89}

# load the library binding for testLib.  
set metaAction [lindex $::argv 0]
assert {[llength [::dlr::allLibAliases]] == 0}
::dlr::loadLib  $metaAction  testLib  [file join $::appDir testLib-src testLib.so]
assert {[llength [::dlr::allLibAliases]] == 1}
assert {[lindex [::dlr::allLibAliases] 0] eq {testLib}}
if [::dlr::refreshMeta] {
    set sQal ::dlr::lib::testLib::struct::quadT::
    set mQal ${sQal}member::
    puts "detected:  name=quadT  size=[set ${sQal}size]  cOfs=[set ${mQal}c::offset]"
    assert {[set ${mQal}a::offset] == 0} ;# all the other offsets beyond this first one depend on the compiler's word size and structure packing behavior.
    assert {[set ${mQal}c::type] == {::dlr::simple::int}}
}
# dump the metadata structure in ram.  this is big.
#puts [join [lsort [info vars ::dlr::*]] \n]

# speed benchmark.  test conditions very comparable to bench-0.1.tcl.  
# difference is under 1%, far less than the background noise from the OS multitasking.
if {$benchReps ne {}} {
    set benchReps $(int($benchReps))
    alias  strtol  ::dlr::lib::testLib::strtolTest::call
    set str 905
    set endP 0
    bench fullWrap $($benchReps / 10) {
        strtol  $str  endP  10
    }
    set endP $::dlr::null
    ::dlr::simple::ptr::pack-byVal-asInt  ::dlr::lib::testLib::strtolTest::parm::endP  [::dlr::addrOf endP]
    bench pack3 $($benchReps / 10) {   
        ::dlr::simple::ptr::pack-byVal-asInt  ::dlr::lib::testLib::strtolTest::parm::strP  [::dlr::addrOf str]
        ::dlr::simple::ptr::pack-byVal-asInt  ::dlr::lib::testLib::strtolTest::parm::endPP [::dlr::addrOf ::dlr::lib::testLib::strtolTest::parm::endP]
        ::dlr::simple::int::pack-byVal-asInt  ::dlr::lib::testLib::strtolTest::parm::radix  10
    }
    bench callToNative $benchReps {
        ::dlr::callToNative  ::dlr::lib::testLib::strtolTest::meta  
    }
    exit 0
}

# strtolTest test
alias  strtol  ::dlr::lib::testLib::strtolTest::call
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
    assert {[::dlr::simple::ptr::unpack-byVal-asInt $::dlr::null] == 0}
}

# mulByValue test
alias  mulByValue  ::dlr::lib::testLib::mulByValue::call
loop attempt 2 5 {
    lassign [mulByValue {10 11 12 13} $attempt] a b c d
    assert {$a == 10 * $attempt}
    assert {$b == 11 * $attempt}
    assert {$c == 12 * $attempt}
    assert {$d == 13 * $attempt}
    puts quadT.d=$d
}
alias  mulDict  ::dlr::lib::testLib::mulDict::call
loop attempt 2 5 {
    set d [mulDict [dict create a 10 b 11 c 12 d 13] $attempt]
    assert {$d(a) == 10 * $attempt}
    assert {$d(b) == 11 * $attempt}
    assert {$d(c) == 12 * $attempt}
    assert {$d(d) == 13 * $attempt}
}

# allocHeap test
loop attempt 0 3 {
    set chunk [::dlr::allocHeap 0x400000]
    puts chunk=[format $::dlr::ptrFmt $chunk]
    # todo: call memcpy() from dlr-libc
    ::dlr::freeHeap $chunk
}

# dataHandler test
alias  dataHandler  ::dlr::lib::testLib::dataHandler::call
loop attempt 2 5 {
    set handle [dataHandler $attempt]
    puts "attempt=$attempt  handle=[format 0x%x $handle]"
    assert {$handle == $attempt << 4}
}

alias  dataHandlerPtr  ::dlr::lib::testLib::dataHandlerPtr::call
loop attempt 2 5 {
    set h $attempt
    set handle [dataHandlerPtr h]
    assert {$handle == $attempt << 4}
    assert {$h == $attempt << 4}
}

alias  dataHandlerVoid  ::dlr::lib::testLib::dataHandlerVoid::call
loop attempt 2 5 {
    set h $attempt
    dataHandlerVoid h
    assert {$h == $attempt << 4}
}

# floatSquare test
alias  floatSquare  ::dlr::lib::testLib::floatSquare::call
loop attempt 2 5 {
    set stuff $($attempt + 0.1)
    set correct $($stuff * $stuff)
    set sqr [floatSquare $stuff $stuff]
    puts [format {stuff=%0.2f  sqr=%0.2f} $stuff $sqr]
    assert {abs( $sqr - $correct) < 0.01}
}

alias  floatSquarePtr  ::dlr::lib::testLib::floatSquarePtr::call
loop attempt 2 5 {
    set stuff $($attempt + 0.1)
    set old $stuff
    set correct $($stuff * $stuff)
    floatSquarePtr stuff
    #puts [format {stuff=%0.2f  sqr=%0.2f} $old $stuff]
    assert {abs( $stuff - $correct) < 0.1}
}


puts "*** ALL TESTS PASS ***"

