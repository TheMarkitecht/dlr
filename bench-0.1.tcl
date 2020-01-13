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


puts $::auto_path

package require dlr

puts sizeOfInt=[::dlr::sizeOfInt]
puts sizeOfPtr=[::dlr::sizeOfPtr]

::dlr::loadLib  testLib  ./dlrTestLib.so

# strtol test
::dlr::prepMetaBlob  meta  [::dlr::fnAddr  test_strtol  testLib]  \
    result  12  {strP endPP radix}  {14 14 10}
set myText $(550)
set strPUnpack [::dlr::addrOf myText]
puts strP=[format $::dlr::ptrFmt $strPUnpack]
# pack varName value -intle|-intbe|-floatle|-floatbe|-str bitwidth ?bitoffset?
pack strP $strPUnpack -intle $::dlr::sizeOfPtrBits

set endP $::dlr::nullPtr
pack endPP [::dlr::addrOf endP] -intle $::dlr::sizeOfPtrBits

pack radix 10 -intle $(8 * [::dlr::sizeOfInt])

set reps $(int([lindex $::argv 0]))
bench callToNative $reps {
    ::dlr::callToNative  meta  
}
bench pack3 $($reps / 10) {   
    pack strP $strPUnpack -intle $::dlr::sizeOfPtrBits
    set endP $::dlr::nullPtr
    pack endPP [::dlr::addrOf endP] -intle $::dlr::sizeOfPtrBits
    pack radix 10 -intle $(8 * [::dlr::sizeOfInt])
}
bench pack3-and-call $($reps / 10) {   
    pack strP $strPUnpack -intle $::dlr::sizeOfPtrBits
    set endP $::dlr::nullPtr
    pack endPP [::dlr::addrOf endP] -intle $::dlr::sizeOfPtrBits
    pack radix 10 -intle $(8 * [::dlr::sizeOfInt])
    ::dlr::callToNative  meta  
}

# unpack binvalue -intbe|-intle|-uintbe|-uintle|-floatbe|-floatle|-str bitpos bitwidth
set resultUnpack [unpack $result -intle 0 $(8 * [::dlr::sizeOfInt])]
puts $myText=$resultUnpack

set endPUnpack [unpack $endP -intle 0 $::dlr::sizeOfPtrBits]
puts endP=[format $::dlr::ptrFmt $endPUnpack]
puts len=$($endPUnpack - $strPUnpack)
