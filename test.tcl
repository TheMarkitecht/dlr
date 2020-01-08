puts $::auto_path

package require invoke

# system data structures
puts sizeOfInt=[invoke::sizeOfInt]
puts sizeOfPtr=[invoke::sizeOfPtr]
set sizeOfPtrBits $(8 * [invoke::sizeOfPtr])
set ptrFmt 0x%0$($sizeOfPtrBits / 4)X
pack nullPtr 0 -intle $sizeOfPtrBits

# strtol test
set invoke::parms {strP endPP radix}
set invoke::atype0 14 ;# FFI_TYPE_POINTER
set invoke::atype1 14 ;# FFI_TYPE_POINTER
set invoke::atype2 10 ;# FFI_TYPE_SINT32
set invoke::rtype  12 ;# FFI_TYPE_SINT64
# pack varName value -intle|-intbe|-floatle|-floatbe|-str bitwidth ?bitoffset?
set myText 556
pack strP [invoke::addressOfContent myText] -intle $sizeOfPtrBits
puts strP=[format $ptrFmt [invoke::addressOfContent myText]]
#set endP 0
#pack endPP [invoke::addressOfContent endP] -intle $sizeOfPtrBits
set endPP $nullPtr
pack radix 10 -intle $(8 * [invoke::sizeOfInt])
puts $myText=[invoke::callToNative [invoke::getFnAddr]]
# unpack binvalue -intbe|-intle|-uintbe|-uintle|-floatbe|-floatle|-str bitpos bitwidth
#set endPUnpack [unpack $endP -intle 0 $sizeOfPtrBits]
#puts endP=[format $ptrFmt $endPUnpack]
#puts len=$($endPUnpack - $strP)
