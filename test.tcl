puts $::auto_path

package require dlr

puts sizeOfInt=[::dlr::sizeOfInt]
puts sizeOfPtr=[::dlr::sizeOfPtr]

::dlr::loadLib  testLib  ./dlrTestLib.so

# strtol test
::dlr::prepMetaBlob  meta  [::dlr::fnAddr  test_strtol  testLib]  \
    result  12  {strP endPP radix}  {14 14 10}
loop attempt 0 5 {
    set myText $(550 + $attempt * 3)
    set strPUnpack [::dlr::addrOf myText]
    puts strP=[format $::dlr::ptrFmt $strPUnpack]
    # pack varName value -intle|-intbe|-floatle|-floatbe|-str bitwidth ?bitoffset?
    pack strP $strPUnpack -intle $::dlr::sizeOfPtrBits
    
    set endP $::dlr::nullPtr
    pack endPP [::dlr::addrOf endP] -intle $::dlr::sizeOfPtrBits
    
    pack radix 10 -intle $(8 * [::dlr::sizeOfInt])
    
    ::dlr::callToNative  meta
    
    # unpack binvalue -intbe|-intle|-uintbe|-uintle|-floatbe|-floatle|-str bitpos bitwidth
    set resultUnpack [unpack $result -intle 0 $(8 * [::dlr::sizeOfInt])]
    puts $myText=$resultUnpack
    
    set endPUnpack [unpack $endP -intle 0 $::dlr::sizeOfPtrBits]
    puts endP=[format $::dlr::ptrFmt $endPUnpack]
    puts len=$($endPUnpack - $strPUnpack)
}
