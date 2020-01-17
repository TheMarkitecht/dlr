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

set ::dlr::scriptPkg [info script]

set ::dlr::version [package require dlrNative]
package provide dlr $::dlr::version
#todo: get a fix for https://github.com/msteveb/jimtcl/issues/146  which corrupts version numbers here.

# this is already called when the package is sourced.
proc ::dlr::initDlr {} {

    # ################  DLR SYSTEM DATA STRUCTURES  #################
    # for these, dlr script package extracts as much dimensional information as possible
    # from the host platform where dlrNative was actually compiled, helping portability.

    # fundamentals
    set ::dlr::endian               le
    set ::dlr::intEndian            -int$::dlr::endian  ;# for use with Jim's pack/unpack commands.
    set ::dlr::floatEndian          -float$::dlr::endian
    set ::dlr::bindingDir           [file join [file dirname $::dlr::scriptPkg] dlr-binding]
    #todo: document in readme etc. how generated code is placed in auto/ and handwritten code in script/
    set ::dlr::sizeOfSimpleTypes    [::dlr::native::sizeOfTypes]
    set ::dlr::directions           [list in out inOut]
    ::dlr::refreshMeta              0

    # bit and byte lengths of simple types, for use in converters.
    foreach typ [dict keys $::dlr::sizeOfSimpleTypes] {
        set ::dlr::size::$typ       $::dlr::sizeOfSimpleTypes($typ)
        set ::dlr::bits::$typ       $(8 * [set ::dlr::size::$typ])
    }

    # ffi type codes map.  certain types are deleted for being too vague etc.
    #todo: support functions returning void.
    set ::dlr::ffiType::void        0
    set ::dlr::ffiType::float       2
    set ::dlr::ffiType::double      3
    set ::dlr::ffiType::longDouble  4
    set ::dlr::ffiType::uInt8       5
    set ::dlr::ffiType::sInt8       6
    set ::dlr::ffiType::uInt16      7
    set ::dlr::ffiType::sInt16      8
    set ::dlr::ffiType::uInt32      9
    set ::dlr::ffiType::sInt32      10
    set ::dlr::ffiType::uInt64      11
    set ::dlr::ffiType::sInt64      12
    set ::dlr::ffiType::ptr         14

    # ... and an extended map also, including those plus additional aliases 
    # corresponding to C language types on the host platform.
    # we assume unsigned ints are the same length as the signed ints.
    set ::dlr::type::int            [set ::dlr::ffiType::sInt$::dlr::bits::int       ]
    set ::dlr::type::short          [set ::dlr::ffiType::sInt$::dlr::bits::short     ]
    set ::dlr::type::long           [set ::dlr::ffiType::sInt$::dlr::bits::long      ]
    set ::dlr::type::longLong       [set ::dlr::ffiType::sInt$::dlr::bits::longLong  ]
    set ::dlr::type::sSizeT         [set ::dlr::ffiType::sInt$::dlr::bits::sizeT     ]
    set ::dlr::type::uInt           [set ::dlr::ffiType::uInt$::dlr::bits::int       ]
    set ::dlr::type::uShort         [set ::dlr::ffiType::uInt$::dlr::bits::short     ]
    set ::dlr::type::uLong          [set ::dlr::ffiType::uInt$::dlr::bits::long      ]
    set ::dlr::type::uLongLong      [set ::dlr::ffiType::uInt$::dlr::bits::longLong  ]
    set ::dlr::type::sizeT          [set ::dlr::ffiType::uInt$::dlr::bits::sizeT     ]
    set ::dlr::type::char           {}
    foreach v [info vars ::dlr::ffiType::*] {
        set  ::dlr::type::[namespace tail $v]  [set $v]
    }

    # aliases to pass through to native implementations of certain dlr system commands.
    foreach cmd {prepStructType prepMetaBlob callToNative createBufferVar addrOf allocHeap freeHeap} {
        alias  ::dlr::$cmd  ::dlr::native::$cmd
    }

    # passMethod's.  these are the different ways a native function might expect to receive its actual arguments.
    # these help determine which converter will be called, and how.
    set ::dlr::passMethods [list byVal byPtr]
    
    # scriptForms.  these are the different ways a script app might want to represent a given type
    # for easy handling in script.  
    # these help determine which converter will be called, and how.
    # each scriptForm is prefixed with the word "as" to prevent confusion with native data types,
    # to increase their mnemonic value to the script developer, and to clarify the meaning of type descriptions.
    # here each type offers a list of scriptForms.  the first scriptForm in each list tends to 
    # be the most useful scriptForm for that data type.
    # the scriptForm "asNative" means a binary blob, having the same layout the native function uses.
    # those tend to be opaque to script, so not very useful there.  but they can be passed directly
    # to another native function, without any intermediate conversions, increasing speed.
    #
    # most simple types are integer scalars, so blanket all types with asInt.
    foreach v [info vars ::dlr::type::*] {
        set ::dlr::scriptForms::[namespace tail $v]  [list asInt asNative]
    }
    # overwrite that with a few special cases such as floating point and struct.
    set ::dlr::scriptForms::struct      [list asList asDict asNative]
    foreach typ {float double longdouble} {
        set ::dlr::scriptForms::$typ  [list asDouble asNative]
    }
    #todo: asString implies some automatic encoding/decoding as needed.  this really could say "asNative" instead, for now, until encoding features are available.  but "asNative" implies you can't directly use it in scripts.  but in fact you can.
    set ::dlr::scriptForms::char        [list asString]

    # converter aliases for certain types.  aliases add speed by avoiding a dispatch step in script.
    # types with length unspecified in C use converters for fixed-size types.
    foreach conversion {pack unpack} {
        # signed ints.
        alias  ::dlr::${conversion}::int-byVal-asInt        ::dlr::${conversion}::i${::dlr::bits::int}-byVal-asInt
        alias  ::dlr::${conversion}::short-byVal-asInt      ::dlr::${conversion}::i${::dlr::bits::short}-byVal-asInt
        alias  ::dlr::${conversion}::long-byVal-asInt       ::dlr::${conversion}::i${::dlr::bits::long}-byVal-asInt
        alias  ::dlr::${conversion}::longLong-byVal-asInt   ::dlr::${conversion}::i${::dlr::bits::longLong}-byVal-asInt
        alias  ::dlr::${conversion}::sSizeT-byVal-asInt     ::dlr::${conversion}::i${::dlr::bits::sizeT}-byVal-asInt
                                                                                  
        # unsigned ints.  we assume these are the same length as the signed ints. 
        alias  ::dlr::${conversion}::uInt-byVal-asInt       ::dlr::${conversion}::u${::dlr::bits::int}-byVal-asInt
        alias  ::dlr::${conversion}::uShort-byVal-asInt     ::dlr::${conversion}::u${::dlr::bits::short}-byVal-asInt
        alias  ::dlr::${conversion}::uLong-byVal-asInt      ::dlr::${conversion}::u${::dlr::bits::long}-byVal-asInt
        alias  ::dlr::${conversion}::uLongLong-byVal-asInt  ::dlr::${conversion}::u${::dlr::bits::longLong}-byVal-asInt
        alias  ::dlr::${conversion}::sizeT-byVal-asInt      ::dlr::${conversion}::u${::dlr::bits::sizeT}-byVal-asInt

        # pointer
        alias  ::dlr::${conversion}::ptr-byVal-asInt        ::dlr::${conversion}::u${::dlr::bits::ptr}-byVal-asInt
    }

    # aliases for converters written in C and provided by dlrNative by default.
    foreach conversion {pack unpack} {
        foreach size {8 16 32 64} {
            # these work the same for both signed and unsigned due to machines using 2's complement representation.
            #todo: verify with negative numbers.
            foreach sign {u i} {
                alias  ::dlr::${conversion}::${sign}${size}-byVal-asInt  ::dlr::native::${conversion}-${size}-byVal-asInt
            }
        }
        alias  ::dlr::${conversion}::char-byVal-asString      ::dlr::native::${conversion}-char-byVal-asString
    }

    # pointer support
    set ::dlr::ptrFmt               0x%0$($::dlr::bits::ptr / 4)X
    # scripts can use $::dlr::null instead of packing their own nulls.
    # this is typically not needed, but might be useful to speed up handwritten converters.
    ::dlr::pack::ptr-byVal-asInt  ::dlr::null  0 
    # any asString data might contain this flag string, to represent a null pointer in the native data.
    #todo: test that, for passing a null char* in and out of native func.
    set ::dlr::nullPtrFlag          ::dlr::nullPtrFlag

    # compiler support
    set ::dlr::defaultCompiler [list  gcc  --std=c11  -O0  -I. ]    
}

# ##########  DLR SYSTEM COMMANDS IMPLEMENTED IN SCRIPT  #############

proc ::dlr::loadLib {libAlias fileNamePath} {
    set handle [native::loadLib $fileNamePath]
    set ::dlr::libHandle::$libAlias $handle
    #todo: remove this first one
    source [file join $::dlr::bindingDir $libAlias auto   $libAlias.tcl]
    source [file join $::dlr::bindingDir $libAlias script $libAlias.tcl]
    return {}
}

proc ::dlr::allLibAliases {} {
    return [lmap ns [info vars ::dlr::libHandle::*] {namespace tail $ns}]
}

# getter/setter for the refreshMeta boolean flag.
# this determines whether metadata and wrapper scripts will be regenerated (and cached again)
# on this particular startup of the script app.
proc ::dlr::refreshMeta {args} {
    return [set ::dlr::refreshMetaFlag {*}$args]
}

proc ::dlr::fnAddr {fnName libAlias} {
    return [native::fnAddr $fnName [set ::dlr::libHandle::$libAlias]]
}

proc ::dlr::isStructType {typeVarName} {
    return [string match *::struct::* $typeVarName]
}

# qualify any unqualified type name.
# a name already qualified is returned as-is.
# others are tested to see if they exist in the given library.  if so, return that one.
# others are tested to see if they're one of the simple types in ::dlr::type.  if so, return that one.
# otherwise, notFoundAction is implemented.  that can be "error" (the default),
# or an empty string to ignore the problem and return an empty string instead.
# structs are always resolved to the name of their metablob variable, ready for passing to dlrNative.
proc ::dlr::qualifyTypeName {typeVarName  libAlias  {notFoundAction error}} {
    if {[string match *::* $typeVarName]} {
        return $typeVarName
    } 
    # here we assume that libs describe only structs, never simple types.
    set meta ::dlr::lib::${libAlias}::struct::${typeVarName}::meta
    if {[info exists $meta]} {
        return $meta
    }
    if {[info exists ::dlr::type::$typeVarName]} {
        return ::dlr::type::$typeVarName
    }
    if {$notFoundAction eq {error}} {
        error "Unqualified type name could not be resolved: $typeVarName"
    }
    return {}
}

proc ::dlr::validateScriptForm {type fullType scriptForm} {
    if {[isStructType $fullType]} {
        set type struct
    }
    if {$scriptForm ni [set ::dlr::scriptForms::$type]} {
        error "Invalid scriptForm was given."
    }        
}

# return the first portion of structTypeName, which is the qualifier for the 
# structure's metadata namespace.
proc ::dlr::structQal {structTypeName} {
    return ::[nsJoin [lrange [nsSplit $structTypeName] 0 4]]
}

proc ::dlr::nsSplit {ns} {
    return [regexp -all -inline {[^:]+} $ns]    
}

proc ::dlr::nsJoin {parts} {
    return [join $parts :: ]
}

proc ::dlr::converterName {conversion fullType passMethod scriptForm} {
    if {[isStructType $fullType]} {
        return [structQal $fullType]::${conversion}-${passMethod}-$scriptForm
    }
    return ::dlr::${conversion}::[namespace tail $fullType]-${passMethod}-$scriptForm
}

proc ::dlr::declareCallToNative {libAlias  returnTypeDescrip  fnName  parmsDescrip} {
    set fQal ::dlr::lib::${libAlias}::${fnName}::
    
    # memorize metadata for parms.
    set order [list]
    set orderNative [list]
    set types [list] 
    foreach parmDesc $parmsDescrip {
        lassign $parmDesc  dir  passMethod  type  name  scriptForm
        set pQal ${fQal}parm::${name}::
        
        lappend order $name
        lappend orderNative ${pQal}native
                
        if {$dir ni $::dlr::directions} {
            error "Invalid direction of flow was given."
        }
        set ${pQal}dir  $dir
        
        if {$passMethod ni $::dlr::passMethods} {
            error "Invalid passMethod was given."
        }
        set ${pQal}passMethod  $passMethod
        
        set fullType [qualifyTypeName $type $libAlias]
        set ${pQal}type  $fullType
        lappend types $( $passMethod eq {byPtr} ? {::dlr::type::ptr} : $fullType )

        validateScriptForm $type $fullType $scriptForm
        set ${pQal}scriptForm  $scriptForm

        # this version uses only byVal converters, and wraps them in script for byPtr.
        # in future, the converters might be allowed to implement byPtr also, for more speed etc.
        set ${pQal}packer   [converterName   pack $fullType byVal $scriptForm]
        set ${pQal}unpacker [converterName unpack $fullType byVal $scriptForm]

        if {$passMethod eq {byPtr}} {
            set ${pQal}targetNativeName  ${pQal}targetNative
        }
    }
    set ${fQal}parmOrder        $order
    set ${fQal}parmOrderNative  $orderNative
    # parmOrderNative is also derived and memorized here, along with the rest, 
    # in case the app needs to change it before using generateCallProc.
    
    # memorize metadata for return value.
    # it's always "out byVal" but does support different types and scriptForms.
    # it does not support other variable names for the native value, since that's generally hidden from scripts anyway.
    set rQal ${fQal}return::
    lassign $returnTypeDescrip  type scriptForm
    set fullType [qualifyTypeName $type $libAlias]
    set ${rQal}type  $fullType
    validateScriptForm $type $fullType $scriptForm
    set ${rQal}scriptForm  $scriptForm
    set ${rQal}unpacker  [converterName unpack $fullType byVal $scriptForm]
    
    # prepare a metaBlob to hold dlrNative and FFI data structures.  
    # do this last, to prevent an ill-advised callToNative using half-baked metadata
    # after an error preparing the metadata.  callToNative can't happen without this metaBlob.
    prepMetaBlob  ${fQal}meta  [::dlr::fnAddr  $fnName  $libAlias]  \
        ${rQal}native  [set ${rQal}type]  $orderNative  $types  
}

# dynamically create a "call wrapper" proc, with a complete executable body, ready to use.
#
# when called, the wrapper will pack all the native function's "in" parameter values,
# call the native function, and unpack its return value, and any "out" parameters it has.
#
# the proc is not immediately created in the live interpreter.  instead the "proc" command is
# returned, and can be applied to the interp with "eval" or similar.  however, Jim can't
# report error line numbers in that case, because there is no source file.
# the "proc" command is also written to a file at [callWrapperPath].  "source" that instead
# of using "eval", to allow Jim to report error line numbers when the proc is used.
# that also avoids time spent regenerating the proc body each time the app starts,
# and allows the developer to modify the proc too.
#
# the wrapper proc comes with a fully qualified command name:
#   ::dlr::lib::${libAlias}::${fnName}::call
# if needed, the script app can alias a more convenient local name to that.
# after that, a call to the wrapper looks just like any ordinary script command,
# but quietly uses the native function.
#
# the generated code uses fully qualified variable names throughout, for speed.
# they are never computed on the fly e.g. using fQal.
#
# before calling generateCallProc, the app can modify metadata kept under 
# ::dlr::lib::${libAlias}::${fnName}, to tailor the generated code for the app's needs.
#
# if needed, the script app can also supply its own call wrapper proc, or use none at all, 
# instead of using generateCallProc.  look to the generated wrapper procs for examples.
# sometimes more speed can be found with handwritten code.
proc ::dlr::generateCallProc {libAlias  fnName} {
    set fQal ::dlr::lib::${libAlias}::${fnName}::

    # call packers to pack "in" parms.
    set procArgs [list]
    set procFormalParms [list]
    set body {}
    foreach  parmBare [set ${fQal}parmOrder]  parmNative [set ${fQal}parmOrderNative] {
        # parmBare is the simple name of the parameter, such as "radix".
        # parmNative is the qualified name of the variable holding the parm's 
        # packed binary data for one call, such as "::dlr::lib::testLib::strtolWrap::parm::radix::native"
        # that qualified name stays the same across calls, but often it must hold
        # a different value for each call, so its content must be repacked for each call.
        
        # set up local names to access all the metadata for this parm.
        set pQal ${fQal}parm::${parmBare}::
        foreach v [info vars ${pQal}* ] {upvar  #0  $v  [namespace tail $v]}
        
        lappend procArgs $parmBare
        # Jim "reference arguments" are used to write to "out" and "inOut" parms in the caller's frame.
        lappend procFormalParms $( $dir in {out inOut} ? "&$parmBare" : "$parmBare" )
        
        #todo: support asNative by wrapping the following block in "if asNative" and emit a plain "set"
        
        # pack a parm to pass in to the native func.  this must be done, even for "out" parms,
        # to ensure buffer space is available before the call.  that makes sense because
        # ordinary C code always does that.
        if {$passMethod eq {byPtr}} {
            # pass by pointer requires 2 packed native vars:  one for the target type's data,
            # and another for the pointer to it.  both must be packed to native before the call.
            append body "$packer  $targetNativeName  \$$parmBare \n"
            append body "::dlr::pack::ptr-byVal-asInt  $parmNative  \[ ::dlr::addrOf  $targetNativeName \] \n"
        } else {
            append body "$packer  $parmNative  \$$parmBare \n"
        }
    }
    
    # call native function.
    set rQal ${fQal}return::
    append body "set  ${rQal}native  \[ ::dlr::callToNative  ${fQal}meta \] \n"
    
    # call unpackers to unpack "out" parms.
    foreach  \
        parmBare  [set ${fQal}parmOrder]  \
        parmNative  [set ${fQal}parmOrderNative]  \
        procArg  $procArgs  {
            
        # set up local names to access all the metadata for this parm.
        set pQal ${fQal}parm::${parmBare}::
        foreach v [info vars ${pQal}* ] {upvar  #0  $v  [namespace tail $v]}
        
        # unpack a parm passed back from the native func.
        if {$dir in {out inOut}} {
            if {$passMethod eq {byPtr}} {
                append body "set  $procArg  \[ $unpacker  \$$targetNativeName \] \n"
            } else {
                append body "set  $procArg  \[ $unpacker  \$$parmNative \] \n"
            }
        }
    }
    
    # unpack return value.
    append body "return  \[ [set ${rQal}unpacker] \$${rQal}native \] \n"

    # compose "proc" command.
    set procCmd "proc  ${fQal}call  { $procFormalParms }  { \n$body \n }"
    
    # save the generated code to a file.
    set f [open [callWrapperPath $libAlias $fnName] w]
    puts $f $procCmd
    close $f
    
    return $procCmd
}

proc ::dlr::declareStructType {libAlias  structTypeName  membersDescrip} {
    set sQal ::dlr::lib::${libAlias}::struct::${structTypeName}::
    
    # load up the type information previously detected and cached on disk.
    set layoutFn [file join $::dlr::bindingDir $libAlias auto $structTypeName.struct]
    if { ! [file readable $layoutFn]} {
        error "Structure layout metadata was not detected for library '$libAlias' type '$typeName'."
    }
    set f [open $layoutFn r]
    set sDic [read $f]
    close $f

    # unpack metadata from the given declaration and merge it with the cached detected info.
    #todo: support nested structs.
    #todo: factor out all the validation vs. detected info, and move that to another command like "validateStructType"
    set ${sQal}size $sDic(size)
    set membersRemain [dict keys $sDic(members)]
    set ${sQal}memberOrder $membersRemain
    set typeVars [list]
    foreach {mDescrip} $membersDescrip {
        lassign $mDescrip mType mName mScriptForm
        set mQal ${sQal}member::${mName}::
        
        set ix [lsearch $membersRemain $mName]
        if {$ix < 0} {
            error "Library '$libAlias' struct '$typ' member '$mName' is not found in the detected metadata."
        }
        set membersRemain [lreplace $membersRemain $ix $ix]    
            
        if {"::dlr::type::$mType" ni [info vars ::dlr::type::*]} {
            error "Library '$libAlias' struct '$typ' member '$mName' declared type is unknown."
        }
        set ${mQal}typeName $mType
        set mFullType ::dlr::type::$mType ;# qualifyTypeName should not be used here.  a simple type is required.
        set ${mQal}typeCode [set $mFullType]
        lappend typeVars $mFullType
        
        set mDic [dict get $sDic members $mName]
        set ${mQal}offset $mDic(offset)
        
        if {$mDic(size) != [set ::dlr::size::$mType]} {
            error "Library '$libAlias' struct '$typ' member '$mName' declared type does not match its size in the detected metadata."
        }
        
        validateScriptForm $mType $mFullType $mScriptForm        
        set ${mQal}scriptForm $mScriptForm
        
        set ${mQal}packer    [converterName   pack $mFullType byVal $mScriptForm]
        set ${mQal}unpacker  [converterName unpack $mFullType byVal $mScriptForm]
    }
    if {[llength $membersRemain] > 0} {
        error "Library '$libAlias' struct '$typ' member '[lindex $membersRemain 0]' is mentioned in the detected metadata but not in the given declaration."
    }
    
    # prep FFI type record for this structure.  do this last of all.
    ::dlr::prepStructType  ${sQal}meta  $typeVars   
}

#todo: documentation similar to generateCallProc
proc ::dlr::generateStructConverters {libAlias  structTypeName} {
    set sQal ::dlr::lib::${libAlias}::struct::${structTypeName}::
    set procs [list]
    set packerParms {packVarName unpackedData {offsetBytes 0} {nextOffsetVarName {}}}
    set unpackerParms {packedValue {offsetBytes 0} {nextOffsetVarName {}}}
    set memberTemps [lmap m [set ${sQal}memberOrder] {expr {"mv::$m"}}]

    #todo: support asNative by emitting a plain "set".  support for the struct and for its members.
    
    # generate pack-byVal-asList
    set body "
        lassign \$unpackedData  [join $memberTemps {  }] 
        ::dlr::createBufferVar  \$packVarName  \$${sQal}size \n"
    foreach  mName [set ${sQal}memberOrder]  mTemp $memberTemps  {
        set mQal ${sQal}member::${mName}::
        append body "[set ${mQal}packer]  \$packVarName  \$$mTemp  \$( \$offsetBytes + \$${mQal}offset ) \n"
        # that could run faster (maybe?) if it placed the offset integer into the script
        # instead of fetching it from metadata at run time.  then again, it might not.
        # it would definitely be harder to read and maintain with the magic numbers, 
        # and more likely to fail after the struct is recompiled.
    }
    append body "
        if { \$nextOffsetVarName ne {}} { 
            upvar \$nextOffsetVarName next 
            set next \$( \$offsetBytes + \$${sQal}size ) 
        } " \n
    # compose "proc" command.
    lappend procs "proc  ${sQal}pack-byVal-asList  { $packerParms }  { \n$body \n }"
    
    #todo:  generate pack-byVal-asDict
    
    # generate unpack-byVal-asList
    set body "
        if { \$nextOffsetVarName ne {}} { 
            upvar \$nextOffsetVarName next 
            set next \$( \$offsetBytes + \$${sQal}size ) 
        } \n"
    append body  "return  \[ list  " \\ \n
    foreach  mName [set ${sQal}memberOrder]  {
        set mQal ${sQal}member::${mName}::
        append body " \[ [set ${mQal}unpacker]  \$packedValue  \$( \$offsetBytes + \$${mQal}offset ) \]  " \\ \n
    }
    append body  \]  \n
    # compose "proc" command.
    lappend procs "proc  ${sQal}unpack-byVal-asList  { $unpackerParms }  { \n$body \n }"

    #todo:  generate unpack-byVal-asDict

    # save the generated code to a file.
    set script [join $procs \n\n]
    set f [open [structConverterPath $libAlias $structTypeName] w]
    puts $f $script
    close $f
    
    return $script
}

# works with either gcc or clang.
# struct layout metadata is returned, and also cached in the binding dir.
proc ::dlr::detectStructLayout {libAlias  typeName  includeCode  compilerOptions  membersDescrip} {
    # determine paths.
    set cFn [file join $::dlr::bindingDir $libAlias auto getStructLayout.c]
    set binFn [file join $::dlr::bindingDir $libAlias auto getStructLayout]
    set layoutFn [file join $::dlr::bindingDir $libAlias auto $typeName.struct]
    
    # generate C source code to extract metadata.
    foreach mDescrip $membersDescrip {
        lassign $mDescrip  mType  mName  mScriptForm
        append membCode "
            printf(\"    {$mName} {size %zu offset %zu }\\n\", 
                sizeof( a.$mName ), offsetof($typeName, $mName) );            
        "
    }
    set src [open $cFn w]
    puts $src "
        #include <stddef.h>
        #include <stdio.h>
        $includeCode
        
        int main (int argc, char **argv) {
            $typeName a;
            printf(\"name {$typeName} size %zu members {\\n\", sizeof($typeName));
            $membCode
            puts(\"}\\n\");
        }
    "
    close $src
    
    # compile and execute C code.
    exec {*}$compilerOptions  -o $binFn  $cFn
    set dic [exec $binFn]
    
    # cache metadata in binding dir.
    set lay [open $layoutFn w]
    puts $lay $dic
    close $lay
    
    return $dic
}


proc callWrapperPath {libAlias  fnName} {
    return [file join $::dlr::bindingDir $libAlias auto $fnName.call.tcl]
}

proc structConverterPath {libAlias  structTypeName} {
    return [file join $::dlr::bindingDir $libAlias auto $structTypeName.convert.tcl]
}

# #################  CONVERTERS  ####################################
# converters are broken out into individual commands by data type.
# that supports fast dispatch, and selective implementation of 
# certain type conversions entirely in C.
# those converters that are implemented in script should often rely on dlr packers, or 
# (slower) Jim's built-in pack feature.  from the Jim manual:
#   pack varName value -intle|-intbe|-floatle|-floatbe|-str bitwidth ?bitoffset?
#   unpack binvalue -intbe|-intle|-uintbe|-uintle|-floatbe|-floatle|-str bitpos bitwidth

#todo: supply example packers and unpackers.

#todo: more converters for passing by pointer etc.  assume existing ones are for pass-by-value.
#todo: more converters for list-as-struct, and for handling structs as blobs (no conversion, for speed).

::dlr::initDlr
