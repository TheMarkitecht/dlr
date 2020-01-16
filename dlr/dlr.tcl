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
    set ::dlr::sizeOfSimpleTypes    [::dlr::native::sizeOfTypes]
    set ::dlr::simpleTypeNames      [dict keys $::dlr::sizeOfSimpleTypes]

    # bit and byte lengths of simple types, for use in converters.
    foreach typ $::dlr::simpleTypeNames {
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
    # fetchers.  these extract the data necessary to pass into a packer, for a given passmethod.
    set ::dlr::fetcher::byVal  set
    set ::dlr::fetcher::byPtr  ::dlr::addrOf
    
    # scriptForms.  these are the different ways a script app might want to represent a given type.
    # these help determine which converter will be called, and how.
    # each scriptForm is prefixed with the word "as" to prevent confusion with native data types,
    # to increase their mnemonic value to the script developer, and to clarify the meaning of type descriptions.
    # here each type offers a list of scriptForms.  the first scriptForm in each list tends to 
    # be the most useful scriptForm for that data type.
    # the scriptForm "asNative" means a binary blob, the same one the native function uses.
    # those tend to be opaque to script, so not very useful there.  but they can be passed directly
    # to another native function, without any intermediate conversions, increasing speed.
    foreach v [info vars ::dlr::type::*] {
        set ::dlr::scriptForms::$typ  [list asInt asNative]
    }
    foreach typ {float double longdouble} {
        set ::dlr::scriptForms::$typ  [list asDouble asNative]
    }
    set ::dlr::scriptForms::struct  [list asList asDict asNative]

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

    # aliases for converters written in C and provided by dlr by default.
    # these work the same for both signed and unsigned.
    foreach size {8 16 32 64} {
        foreach sign {u i} {
            alias  ::dlr::pack::${sign}${size}-byVal-asInt      ::dlr::native::pack${size}-byVal-asInt
            alias  ::dlr::unpack::${sign}${size}-byVal-asInt    ::dlr::native::unpack${size}-byVal-asInt
        }
    }

    # pointer support
    set ::dlr::ptrFmt               0x%0$($::dlr::bits::ptr / 4)X
    # scripts should use $::dlr::null instead of packing their own nulls.
    ::dlr::pack::ptr-byVal-asInt  ::dlr::null  0 

    # compiler support
    set ::dlr::defaultCompiler [list  gcc  --std=c11  -O0  -I. ]    
}

# ##########  DLR SYSTEM COMMANDS IMPLEMENTED IN SCRIPT  #############

proc ::dlr::loadLib {libAlias fileNamePath} {
    set handle [native::loadLib $fileNamePath]
    set ::dlr::libHandle::$libAlias $handle
    source [file join $::dlr::bindingDir $libAlias auto   $libAlias.tcl]
    source [file join $::dlr::bindingDir $libAlias script $libAlias.tcl]
    return {}
}

proc ::dlr::allLibAliases {} {
    return [lmap ns [info vars ::dlr::libHandle::*] {namespace tail $ns}]
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
        set fullType [qualifyTypeName $type $libAlias]
        lappend types $fullType
        set ${pQal}dir  $dir
        set ${pQal}type  $fullType
        set ${pQal}passMethod  $passMethod
        set ${pQal}scriptForm  $scriptForm
        #todo: delete
        #set defaultForm $( [isStructType $fullType] ? list : [set ::dlr::defaultForm::$type]
        #set form $( $scriptForm eq {byVal} ? {} : $scriptForm )
        set packerBase  $( [isStructType $fullType]  ?  "${fullType}::pack"  :  "::dlr::pack::$type" )
        set ${pQal}packer  ${packerBase}-${passMethod}-${scriptForm}
        set unpackerBase  $( [isStructType $fullType]  ?  "${fullType}::unpack"  :  "::dlr::unpack::$type" )
        set ${pQal}unpacker  ${unpackerBase}-${passMethod}-${scriptForm}
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
    set ${rQal}scriptForm  $scriptForm
    set unpackerBase  $( [isStructType $fullType]  ?  "${fullType}::unpack"  :  "::dlr::unpack::$type" )
    set ${rQal}unpacker  ${unpackerBase}-${passMethod}-${scriptForm}
    
    # prepare dlrNative and FFI data structures.
    prepMetaBlob  ${fQal}meta  [::dlr::fnAddr  $fnName  $libAlias]  \
        ${rQal}native  [set ${rQal}type]  $orderNative  $types  
}

# dynamically create a "call wrapper" proc, with a complete executable body, ready to use.
#
# it is not immediately applied to the live interpreter.  instead the "proc" command is
# returned, and can be applied to the interp with "eval" or similar.  however, Jim can't
# report error line numbers in that case, because there is no source file.
# the "proc" command is also written to the given fileNamePath.  "source" that to allow
# Jim to report error line numbers when the proc is used.
#
# when called, the wrapper will pack all the native function's "in" parameter values,
# call the native function, and unpack its return value, and any "out" parameters it has.
#
# the wrapper proc comes with a fully qualified command name:
#   ::dlr::lib::${libAlias}::${fnName}::call
# if needed, the script app can alias a more convenient local name to that.
# after that, a call to the wrapper looks just like any ordinary script command,
# but quietly uses the native function.
#
# metadata kept under ::dlr::lib::${libAlias}::${fnName} can be modified if needed, before
# calling generateCallProc.
#
# if needed, the script app can also supply its own call wrapper proc, or none at all, 
# instead of using generateCallProc.  look to the generated wrapper procs for examples.
proc ::dlr::generateCallProc {libAlias  fnName  fileNamePath} {
    set fQal ::dlr::lib::${libAlias}::${fnName}::

    # pack "in" parms.
    set procArgs [list]
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
        
        #todo delete
        set junk {
            set packScript {}
            if {$dir in {in inOut}} {
                # pack a parm to pass in to the native func.
                if {$passMethod eq {byVal}} {
                    if {[isStructType $type]} {
                        #todo: call struct packer
                    } else {
                        set packScript "::dlr::pack::"
                    }
                }
            }
            if {$packScript eq {}} {
                error "Parameter configuration is not supported, while packing: $pQal"
            }
            append body $packScript
        }

        # pack a parm to pass in to the native func.  this must be done, even for "out" parms,
        # to ensure buffer space is available before the call.  that makes sense because
        # ordinary C code always does that.
        set fetcher [set ::dlr::fetcher::$passMethod]
        append body "$packer  $parmNative  \[ $fetcher  $parmBare \] \n"
    }
    
    # call native function.
    set rQal ${fQal}return::
    append body "set  ${rQal}native  \[ ::dlr::callToNative  ${fQal}meta \] \n"
    
    # unpack "out" parms.
    foreach  \
        parmBare  [set ${fQal}parmOrder]  \
        parmNative  [set ${fQal}parmOrderNative]  \
        procArg  procArgs  {
            
        # set up local names to access all the metadata for this parm.
        set pQal ${fQal}parm::${parmBare}::
        foreach v [info vars ${pQal}* ] {upvar  #0  $v  [namespace tail $v]}
        
        # unpack a parm passed back from the native func.
        if {$dir in {out inOut}} {
            append body "set  $procArg  \[ $unpacker  \$$parmNative \] \n"
        }
    }
    
    # unpack return value.
    append body "return  \[ [set ${rQal}unpacker] \$${rQal}native \] \n"

    # compose "proc" command.
    set procCmd "proc  ${fQal}call  { $procArgs }  { \n $body \n }"
    
    # save the generated code to a file.
    set f [open $fileNamePath w]
    puts $f $procCmd
    close $f
    
    return $procCmd
}

proc ::dlr::declareStructType {libAlias  structTypeName  membersDescrip} {
    set typ $structTypeName
    
    # load up the type information previously detected and cached on disk.
    set layoutFn [file join $::dlr::bindingDir $libAlias auto $typ.struct]
    if { ! [file readable $layoutFn]} {
        error "Structure layout metadata was not detected for library '$libAlias' type '$typeName'."
    }
    set f [open $layoutFn r]
    set sDic [read $f]
    close $f

    # unpack metadata from the given declaration and merge it with the cached detected info.
    #todo: support nested structs.
    #todo: support scriptForm for each struct member.
    set ::dlr::lib::${libAlias}::struct::${typ}::size $sDic(size)
    set membersRemain [dict keys $sDic(members)]
    set ::dlr::lib::${libAlias}::struct::${typ}::memberOrder $membersRemain
    set typeVars [list]
    foreach {mDescrip} $membersDescrip {
        lassign $mDescrip mTypeName mName
        set ix [lsearch $membersRemain $mName]
        if {$ix < 0} {
            error "Library '$libAlias' struct '$typ' member '$mName' is not found in the detected metadata."
        }
        set membersRemain [lreplace $membersRemain $ix $ix]        
        if {"::dlr::type::$mTypeName" ni [info vars ::dlr::type::*]} {
            error "Library '$libAlias' struct '$typ' member '$mName' declared type is unknown."
        }
        set ::dlr::lib::${libAlias}::struct::${typ}::member::${mName}::typeName $mTypeName
        set typeVar ::dlr::type::$mTypeName
        set ::dlr::lib::${libAlias}::struct::${typ}::member::${mName}::typeCode [set $typeVar]
        lappend typeVars $typeVar
        set mDic [dict get $sDic members $mName]
        if {$mDic(size) != [set ::dlr::size::$mTypeName]} {
            error "Library '$libAlias' struct '$typ' member '$mName' declared type does not match its size in the detected metadata."
        }
        set ::dlr::lib::${libAlias}::struct::${typ}::member::${mName}::offset $mDic(offset)
    }
    if {[llength $membersRemain] > 0} {
        error "Library '$libAlias' struct '$typ' member '[lindex $membersRemain 0]' is mentioned in the detected metadata but not in the given declaration."
    }
    
    # prep FFI type record for this structure.
    ::dlr::prepStructType  ::dlr::lib::${libAlias}::struct::${typ}::meta  $typeVars   
}

# works with either gcc or clang.
# struct layout metadata is returned, and also cached in the binding dir.
proc ::dlr::detectStructLayout {libAlias  typeName  includeCode  compilerOptions  members} {
    # determine paths.
    set cFn [file join $::dlr::bindingDir $libAlias auto getStructLayout.c]
    set binFn [file join $::dlr::bindingDir $libAlias auto getStructLayout]
    set layoutFn [file join $::dlr::bindingDir $libAlias auto $typeName.struct]
    
    # generate C source code to extract metadata.
    foreach m $members {
        append membCode "
            printf(\"    {$m} {size %zu offset %zu }\\n\", 
                sizeof( a.$m ), offsetof($typeName, $m) );            
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
