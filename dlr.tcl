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

set ::dlr::version [package require dlrNative]
package provide dlr $::dlr::version


# ################  DLR SYSTEM DATA STRUCTURES  #################
set ::dlr::endian               le
set ::dlr::intEndian            -int$::dlr::endian
set ::dlr::floatEndian          -float$::dlr::endian
set ::dlr::libs                 [dict create]
set ::dlr::sizeOfTypes          [::dlr::native::sizeOfTypes]
set ::dlr::simpleTypeNames      [dict keys $::dlr::sizeOfTypes]
    
# bit and byte lengths of simple types, for use in converters.
foreach typ $::dlr::simpleTypeNames {
    set ::dlr::sizeOf$typ       $::dlr::sizeOfTypes($typ)
    set ::dlr::bitsOf$typ       $(8 * [set ::dlr::sizeOf$typ])
}

# aliases to pass through to native implementations of certain dlr system commands.
foreach cmd {prepMetaBlob callToNative createBufferVar addrOf allocHeap freeHeap} {
    alias  ::dlr::$cmd  ::dlr::native::$cmd
}

# converter aliases for certain types.  aliases add speed by avoiding a dispatch step in script.
# types with length unspecified in C use converters for fixed-size types.
foreach conversion {pack unpack} {
    # signed ints.
    alias  ::dlr::${conversion}::int        ::dlr::${conversion}::i$::dlr::bitsOfInt
    alias  ::dlr::${conversion}::short      ::dlr::${conversion}::i$::dlr::bitsOfShort
    alias  ::dlr::${conversion}::long       ::dlr::${conversion}::i$::dlr::bitsOfLong
    alias  ::dlr::${conversion}::longLong   ::dlr::${conversion}::i$::dlr::bitsOfLongLong
    alias  ::dlr::${conversion}::sSizeT     ::dlr::${conversion}::i$::dlr::bitsOfSizeT
    
    # unsigned ints.  we assume these are the same length as the signed ints.
    alias  ::dlr::${conversion}::uInt       ::dlr::${conversion}::u$::dlr::bitsOfInt
    alias  ::dlr::${conversion}::uShort     ::dlr::${conversion}::u$::dlr::bitsOfShort
    alias  ::dlr::${conversion}::uLong      ::dlr::${conversion}::u$::dlr::bitsOfLong
    alias  ::dlr::${conversion}::uLongLong  ::dlr::${conversion}::u$::dlr::bitsOfLongLong
    alias  ::dlr::${conversion}::sizeT      ::dlr::${conversion}::u$::dlr::bitsOfSizeT

    # pointer
    alias  ::dlr::${conversion}::ptr        ::dlr::${conversion}::u$::dlr::bitsOfPtr
}

# ##########  DLR SYSTEM COMMANDS IMPLEMENTED IN SCRIPT  #############
proc ::dlr::loadLib {libAlias fileNamePath} {
    set handle [native::loadLib $fileNamePath]
    set ::dlr::libs($libAlias) $handle
    return {}
}

proc ::dlr::fnAddr {fnName libAlias} {
    return [native::fnAddr $fnName $::dlr::libs($libAlias)]
}

# #################  CONVERTERS  ####################################
# converters are broken out into individual commands by data type.
# that supports fast dispatch, and selective implementation of 
# certain type conversions entirely in C.
# those converters that are implemented in script should often rely on
# Jim's built-in pack feature.  from the Jim manual:
#   pack varName value -intle|-intbe|-floatle|-floatbe|-str bitwidth ?bitoffset?
#   unpack binvalue -intbe|-intle|-uintbe|-uintle|-floatbe|-floatle|-str bitpos bitwidth

proc    ::dlr::pack::i8 {packVarName  unpackedData  {offsetBits 0}} {
    pack  $packVarName  $unpackedData  $::dlr::intEndian  8  $offsetBits
}

proc  ::dlr::unpack::i8 {packedData  {offsetBits 0}} {
    unpack $packedData $::dlr::intEndian $offsetBits 8
}

proc    ::dlr::pack::u8 {packVarName  unpackedData  {offsetBits 0}} {
    pack  $packVarName  $unpackedData  $::dlr::intEndian  8  $offsetBits
}

proc  ::dlr::unpack::u8 {packedData  {offsetBits 0}} {
    unpack $packedData $::dlr::intEndian $offsetBits 8
}

proc   ::dlr::pack::i16 {packVarName  unpackedData  {offsetBits 0}} {
    pack  $packVarName  $unpackedData  $::dlr::intEndian  16  $offsetBits
}

proc ::dlr::unpack::i16 {packedData  {offsetBits 0}} {
    unpack $packedData $::dlr::intEndian $offsetBits 16
}

proc   ::dlr::pack::u16 {packVarName  unpackedData  {offsetBits 0}} {
    pack  $packVarName  $unpackedData  $::dlr::intEndian  16  $offsetBits
}

proc ::dlr::unpack::u16 {packedData  {offsetBits 0}} {
    unpack $packedData $::dlr::intEndian $offsetBits 16
}

proc   ::dlr::pack::i32 {packVarName  unpackedData  {offsetBits 0}} {
    pack  $packVarName  $unpackedData  $::dlr::intEndian  32  $offsetBits
}

proc ::dlr::unpack::i32 {packedData  {offsetBits 0}} {
    unpack $packedData $::dlr::intEndian $offsetBits 32
}

proc   ::dlr::pack::u32 {packVarName  unpackedData  {offsetBits 0}} {
    pack  $packVarName  $unpackedData  $::dlr::intEndian  32  $offsetBits
}

proc ::dlr::unpack::u32 {packedData  {offsetBits 0}} {
    unpack $packedData $::dlr::intEndian $offsetBits 32
}

proc   ::dlr::pack::i64 {packVarName  unpackedData  {offsetBits 0}} {
    pack  $packVarName  $unpackedData  $::dlr::intEndian  64  $offsetBits
}

proc ::dlr::unpack::i64 {packedData  {offsetBits 0}} {
    unpack $packedData $::dlr::intEndian $offsetBits 64
}

proc   ::dlr::pack::u64 {packVarName  unpackedData  {offsetBits 0}} {
    pack  $packVarName  $unpackedData  $::dlr::intEndian  64  $offsetBits
}

proc ::dlr::unpack::u64 {packedData  {offsetBits 0}} {
    unpack $packedData $::dlr::intEndian $offsetBits 64
}

# ################  MORE DLR SYSTEM DATA STRUCTURES  ############
# pointer support
set ::dlr::ptrFmt               0x%0$($::dlr::bitsOfPtr / 4)X
# scripts should use $::dlr::null instead of packing their own nulls.
::dlr::pack::ptr  ::dlr::null  0 
