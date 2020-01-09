puts $::auto_path

package require invoke

puts sizeOfInt=[::invoke::sizeOfInt]
puts sizeOfPtr=[::invoke::sizeOfPtr]

::invoke::loadLib  testLib  ./invokeTestLib.so

# strtol test
::invoke::prepMetaBlob  meta  [::invoke::fnAddr  test_strtol  testLib]  \
    result  12  {strP endPP radix}  {14 14 10}
loop attempt 0 5 {
    set myText $(550 + $attempt * 3)
    set strPUnpack [::invoke::addrOf myText]
    puts strP=[format $::invoke::ptrFmt $strPUnpack]
    # pack varName value -intle|-intbe|-floatle|-floatbe|-str bitwidth ?bitoffset?
    pack strP $strPUnpack -intle $::invoke::sizeOfPtrBits
    
    set endP $::invoke::nullPtr
    pack endPP [::invoke::addrOf endP] -intle $::invoke::sizeOfPtrBits
    
    pack radix 10 -intle $(8 * [::invoke::sizeOfInt])
    
    ::invoke::callToNative  meta
    
    # unpack binvalue -intbe|-intle|-uintbe|-uintle|-floatbe|-floatle|-str bitpos bitwidth
    set resultUnpack [unpack $result -intle 0 $(8 * [::invoke::sizeOfInt])]
    puts $myText=$resultUnpack
    
    set endPUnpack [unpack $endP -intle 0 $::invoke::sizeOfPtrBits]
    puts endP=[format $::invoke::ptrFmt $endPUnpack]
    puts len=$($endPUnpack - $strPUnpack)
}
