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
#todo: get a fix for https://github.com/msteveb/jimtcl/issues/146  which corrupts version numbers here.

# ################  DLR SYSTEM DATA STRUCTURES  #################
# for these, dlr script package extracts as much dimensional information as possible
# from the host platform where dlrNative was actually compiled, helping portability.

# fundamentals
set ::dlr::endian               le
set ::dlr::intEndian            -int$::dlr::endian
set ::dlr::floatEndian          -float$::dlr::endian
set ::dlr::libs                 [dict create]
set ::dlr::sizeOfSimpleTypes    [::dlr::native::sizeOfTypes]
set ::dlr::simpleTypeNames      [dict keys $::dlr::sizeOfSimpleTypes]

# bit and byte lengths of simple types, for use in converters.
foreach typ $::dlr::simpleTypeNames {
    set ::dlr::size::$typ       $::dlr::sizeOfSimpleTypes($typ)
    set ::dlr::bits::$typ       $(8 * [set ::dlr::size::$typ])
}

# ffi type codes map.  certain types are deleted for being too vague etc.
set ::dlr::ffiType::void        0
set ::dlr::ffiType::float       2
set ::dlr::ffiType::double      3
set ::dlr::ffiType::longdouble  4
set ::dlr::ffiType::uint8       5
set ::dlr::ffiType::sint8       6
set ::dlr::ffiType::uint16      7
set ::dlr::ffiType::sint16      8
set ::dlr::ffiType::uint32      9
set ::dlr::ffiType::sint32      10
set ::dlr::ffiType::uint64      11
set ::dlr::ffiType::sint64      12
set ::dlr::ffiType::ptr         14

# ... and an extended map also, including those plus additional aliases 
# corresponding to C language types on the host platform.
# we assume unsigned ints are the same length as the signed ints.
set ::dlr::type::int            [set ::dlr::ffiType::sint$::dlr::bits::int       ]
set ::dlr::type::short          [set ::dlr::ffiType::sint$::dlr::bits::short     ]
set ::dlr::type::long           [set ::dlr::ffiType::sint$::dlr::bits::long      ]
set ::dlr::type::longLong       [set ::dlr::ffiType::sint$::dlr::bits::longLong  ]
set ::dlr::type::sSizeT         [set ::dlr::ffiType::sint$::dlr::bits::sizeT     ]
set ::dlr::type::uInt           [set ::dlr::ffiType::uint$::dlr::bits::int       ]
set ::dlr::type::uShort         [set ::dlr::ffiType::uint$::dlr::bits::short     ]
set ::dlr::type::uLong          [set ::dlr::ffiType::uint$::dlr::bits::long      ]
set ::dlr::type::uLongLong      [set ::dlr::ffiType::uint$::dlr::bits::longLong  ]
set ::dlr::type::sizeT          [set ::dlr::ffiType::uint$::dlr::bits::sizeT     ]
foreach v [info vars ::dlr::ffiType::*] {
    set  ::dlr::type::[namespace tail $v]  [set $v]
}

# aliases to pass through to native implementations of certain dlr system commands.
foreach cmd {prepStructType prepMetaBlob callToNative createBufferVar addrOf allocHeap freeHeap} {
    alias  ::dlr::$cmd  ::dlr::native::$cmd
}

# converter aliases for certain types.  aliases add speed by avoiding a dispatch step in script.
# types with length unspecified in C use converters for fixed-size types.
foreach conversion {pack unpack} {
    # signed ints.
    alias  ::dlr::${conversion}::int        ::dlr::${conversion}::i$::dlr::bits::int
    alias  ::dlr::${conversion}::short      ::dlr::${conversion}::i$::dlr::bits::short
    alias  ::dlr::${conversion}::long       ::dlr::${conversion}::i$::dlr::bits::long
    alias  ::dlr::${conversion}::longLong   ::dlr::${conversion}::i$::dlr::bits::longLong
    alias  ::dlr::${conversion}::sSizeT     ::dlr::${conversion}::i$::dlr::bits::sizeT
    
    # unsigned ints.  we assume these are the same length as the signed ints.
    alias  ::dlr::${conversion}::uInt       ::dlr::${conversion}::u$::dlr::bits::int
    alias  ::dlr::${conversion}::uShort     ::dlr::${conversion}::u$::dlr::bits::short
    alias  ::dlr::${conversion}::uLong      ::dlr::${conversion}::u$::dlr::bits::long
    alias  ::dlr::${conversion}::uLongLong  ::dlr::${conversion}::u$::dlr::bits::longLong
    alias  ::dlr::${conversion}::sizeT      ::dlr::${conversion}::u$::dlr::bits::sizeT

    # pointer
    alias  ::dlr::${conversion}::ptr        ::dlr::${conversion}::u$::dlr::bits::ptr
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

#todo: make all packers take a reference parm 
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
set ::dlr::ptrFmt               0x%0$($::dlr::bits::ptr / 4)X
# scripts should use $::dlr::null instead of packing their own nulls.
::dlr::pack::ptr  ::dlr::null  0 
