puts $::auto_path

package require invoke

# system data structures
puts sizeOfInt=[invoke::sizeOfInt]
puts sizeOfPtr=[invoke::sizeOfPtr]
set sizeOfPtrBits $(8 * [invoke::sizeOfPtr])
set ptrFmt 0x%0$($sizeOfPtrBits / 4)X
pack nullPtr 0 -intle $sizeOfPtrBits

# strtol test
invoke::prepMetaBlob  meta  [invoke::getFnAddr]  result  12  {strP endPP radix}  {14 14 10}
loop attempt 0 5 {
    set myText $(550 + $attempt * 3)
    set strPUnpack [invoke::addressOf myText]
    puts strP=[format $ptrFmt $strPUnpack]
    # pack varName value -intle|-intbe|-floatle|-floatbe|-str bitwidth ?bitoffset?
    pack strP $strPUnpack -intle $sizeOfPtrBits
    
    set endP $nullPtr
    pack endPP [invoke::addressOf endP] -intle $sizeOfPtrBits
    
    pack radix 10 -intle $(8 * [invoke::sizeOfInt])
    
    invoke::callToNative  meta
    
    # unpack binvalue -intbe|-intle|-uintbe|-uintle|-floatbe|-floatle|-str bitpos bitwidth
    set resultUnpack [unpack $result -intle 0 $(8 * [invoke::sizeOfInt])]
    puts $myText=$resultUnpack
    
    set endPUnpack [unpack $endP -intle 0 $sizeOfPtrBits]
    puts endP=[format $ptrFmt $endPUnpack]
    puts len=$($endPUnpack - $strPUnpack)
}
