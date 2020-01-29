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

# this is already called when the package is sourced.  no need for the app to call this.
proc ::dlr::initDlr {} {

    # script interpreter support.
    alias  ::dlr::get  set ;# allows "get" as an alternative to the one-argument "set", with much clearer intent.

    # ################  DLR SYSTEM DATA STRUCTURES  #################
    # for these, dlr script package extracts as much dimensional information as possible
    # from the host platform where dlrNative was actually compiled, helping portability.

    # fundamentals
    set ::dlr::endian               le
    #todo: detect endian from compiler macros in dlrNative.
    set ::dlr::intEndian            -int$::dlr::endian  ;# for use with Jim's pack/unpack commands.
    set ::dlr::floatEndian          -float$::dlr::endian
    set ::dlr::bindingDir           [file join [file dirname $::dlr::scriptPkg] dlr-binding]
    ::dlr::refreshMeta              0
    set ::dlr::native::sizeOfSimpleTypes    [::dlr::native::sizeOfTypes] ;# scripts should avoid using this variable directly.

    set ::dlr::directions           [list in out inOut]
    set ::dlr::dlrFlags             [dict create dir_in 1 dir_out 2 dir_inOut 3 array 8]

    # aliases to pass through to native implementations of certain dlr system commands.
    foreach cmd {prepStructType prepMetaBlob callToNative
        createBufferVar copyToBufferVar addrOf allocHeap freeHeap} {
        alias  ::dlr::$cmd  ::dlr::native::$cmd
    }

    # bit and byte lengths of simple types, for use in converters.  byte lengths are useful for
    # dlr's converters.  bit lengths are more useful for Jim's pack/unpack, but those are slower.
    foreach typ [dict keys $::dlr::native::sizeOfSimpleTypes] {
        set ::dlr::simple::${typ}::size       $::dlr::native::sizeOfSimpleTypes($typ)
        set ::dlr::simple::${typ}::bits       $(8 * [get ::dlr::simple::${typ}::size])
    }
    foreach size {8 16 32 64} {
        foreach sign {u i} {
            set ::dlr::simple::${sign}${size}::size  $($size / 8)
            set ::dlr::simple::${sign}${size}::bits  $size
        }
    }
    # sizes of unsigned ints of unspecified length.  assume they're the same length as signed ones.
    foreach signed {short int long longLong sSizeT} \
        unsigned {uShort uInt uLong uLongLong sizeT} {
        set ::dlr::simple::${unsigned}::size  [get ::dlr::simple::${signed}::size]
        set ::dlr::simple::${unsigned}::bits  [get ::dlr::simple::${signed}::bits]
    }
    set ::dlr::simple::void::size  0
    set ::dlr::simple::void::bits  0

    # ffi type codes map.  certain types are deleted for being too vague or otherwise unusable.
    set ::dlr::ffiType::void        0
    set ::dlr::ffiType::float       2
    set ::dlr::ffiType::double      3
    set ::dlr::ffiType::longDouble  4
    set ::dlr::ffiType::u8          5
    set ::dlr::ffiType::i8          6
    set ::dlr::ffiType::u16         7
    set ::dlr::ffiType::i16         8
    set ::dlr::ffiType::u32         9
    set ::dlr::ffiType::i32         10
    set ::dlr::ffiType::u64         11
    set ::dlr::ffiType::i64         12
    set ::dlr::ffiType::ptr         14

    # ... and an extended map also, including those plus additional aliases
    # corresponding to C language types on the host platform.
    # we assume unsigned ints are the same length as the signed ints.
    set ::dlr::simple::int::ffiTypeCode            [get ::dlr::ffiType::i$::dlr::simple::int::bits       ]
    set ::dlr::simple::short::ffiTypeCode          [get ::dlr::ffiType::i$::dlr::simple::short::bits     ]
    set ::dlr::simple::long::ffiTypeCode           [get ::dlr::ffiType::i$::dlr::simple::long::bits      ]
    set ::dlr::simple::longLong::ffiTypeCode       [get ::dlr::ffiType::i$::dlr::simple::longLong::bits  ]
    set ::dlr::simple::sSizeT::ffiTypeCode         [get ::dlr::ffiType::i$::dlr::simple::sizeT::bits     ]
    set ::dlr::simple::uInt::ffiTypeCode           [get ::dlr::ffiType::u$::dlr::simple::int::bits       ]
    set ::dlr::simple::uShort::ffiTypeCode         [get ::dlr::ffiType::u$::dlr::simple::short::bits     ]
    set ::dlr::simple::uLong::ffiTypeCode          [get ::dlr::ffiType::u$::dlr::simple::long::bits      ]
    set ::dlr::simple::uLongLong::ffiTypeCode      [get ::dlr::ffiType::u$::dlr::simple::longLong::bits  ]
    set ::dlr::simple::sizeT::ffiTypeCode          [get ::dlr::ffiType::u$::dlr::simple::sizeT::bits     ]
    set ::dlr::simple::ascii::ffiTypeCode          [get ::dlr::ffiType::i8                               ]
    # copy all from ffiType.
    foreach v [info vars ::dlr::ffiType::*] {
        set  ::dlr::simple::[namespace tail $v]::ffiTypeCode  [get $v]
    }

    # passMethod's.  these are the different ways a native function might expect to access its actual arguments.
    # these help determine which converter will be called, and how.
    set ::dlr::passMethods [list byVal byPtr byPtrPtr]

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
    foreach v [info vars ::dlr::simple::*::ffiTypeCode] {
        set [namespace parent $v]::scriptForms  [list asInt asNative]
    }
    # overwrite that with a few special cases such as floating point and struct.
    set ::dlr::struct::scriptForms              [list asList asDict asNative]
    foreach typ {float double longDouble} {
        set ::dlr::simple::${typ}::scriptForms  [list asDouble asNative]
    }
    set ::dlr::simple::ascii::scriptForms       [list asString]
    set ::dlr::simple::void::scriptForms        [list]

    # aliases for converters written in C and provided by dlrNative by default.
    # aliases add speed by avoiding a dispatch step in script.
    foreach conversion {pack unpack} {
        foreach size {8 16 32 64} {
            foreach sign {u i} {
                alias  ::dlr::simple::${sign}${size}::${conversion}-byVal-asInt  ::dlr::native::${sign}${size}-${conversion}-byVal-asInt
            }
        }
        alias  ::dlr::simple::float::${conversion}-byVal-asDouble       ::dlr::native::float-${conversion}-byVal-asDouble
        alias  ::dlr::simple::double::${conversion}-byVal-asDouble      ::dlr::native::double-${conversion}-byVal-asDouble
        alias  ::dlr::simple::longDouble::${conversion}-byVal-asDouble  ::dlr::native::longDouble-${conversion}-byVal-asDouble
        alias  ::dlr::simple::ascii::${conversion}-byVal-asString       ::dlr::native::ascii-${conversion}-byVal-asString
    }
    alias  ::dlr::simple::ascii::unpack-scriptPtr-asString       ::dlr::native::ascii-unpack-scriptPtr-asString

    # converter aliases for certain types.
    # types with length unspecified in C use converters for fixed-size types.
    # the fixed size is selected according to the actual host at compile time.
    foreach conversion {pack unpack} {
        foreach type {int short long longLong sSizeT} {
            alias  ::dlr::simple::${type}::${conversion}-byVal-asInt        ::dlr::simple::i[get ::dlr::simple::${type}::bits]::${conversion}-byVal-asInt
        }
        foreach type {uInt uShort uLong uLongLong sizeT ptr} {
            alias  ::dlr::simple::${type}::${conversion}-byVal-asInt        ::dlr::simple::u[get ::dlr::simple::${type}::bits]::${conversion}-byVal-asInt
        }
    }

    # pointer support.
    set ::dlr::ptrFmt               0x%0$($::dlr::simple::ptr::bits / 4)x
    # scripts can use $::dlr::null instead of packing their own nulls.
    # packed nulls are typically not needed, but might be useful to speed up handwritten converters.
    ::dlr::simple::ptr::pack-byVal-asInt  ::dlr::null  0
    # any asString data might contain this flag string, to represent a null pointer in the native data.
    # other scriptForms generally represent null pointer as an empty string / list / dict.
    set ::dlr::nullPtrFlag          ::dlr::nullPtrFlag

    # string support.
    set ::dlr::stringTypes [list ::dlr::simple::ascii]

    # compiler support.
    # in the current version, all features work with either gcc or clang.
    set ::dlr::defaultCompiler {
        exec  gcc  --std=c11  -O0  -I.  -o $binFn  $cFn
    }
    set ::dlr::compiler $::dlr::defaultCompiler

    # GObject Introspection support.
    set ::dlr::giEnabled           [exists -command ::dlr::native::giCallToNative]
}

# ##########  DLR SYSTEM COMMANDS IMPLEMENTED IN SCRIPT  #############

# loadLib is the first step in using a native library.
# in all cases loadLib will dlopen() the .so file, and source the corresponding
# handwritten binding script (under dlr::bindingDir) into the live interpreter.
# but first, loadLib will set dlr::refreshMeta in order to automatically regenerate all
# that lib's cached metadata and generated scripts, if metaAction is refreshMeta.
# typically you should pass refreshMeta (rather than keepMeta) to loadLib if you
# suspect the native library's source or binary have changed since the last time.
# using it on every run of the script app would cost additional startup time.
proc ::dlr::loadLib {metaAction  libAlias  fileNamePath} {
    if {$metaAction ni {refreshMeta keepMeta}} {
        error "Invalid meta action: $metaAction"
    }
    refreshMeta $( $metaAction eq {refreshMeta} )
    file mkdir [file dirname [callWrapperPath $libAlias junk]]

    set handle [native::loadLib $fileNamePath]
    set ::dlr::libHandle::$libAlias $handle

    source [file join $::dlr::bindingDir $libAlias script $libAlias.tcl]
    return {}
}

# returns the libAlias of every library loaded by dlr so far.
proc ::dlr::allLibAliases {} {
    return [lmap ns [info vars ::dlr::libHandle::*] {namespace tail $ns}]
}

# can be used to declare new simple type based on an existing one.
proc ::dlr::typedef {existingType  name} {
    if {[exists ::dlr::simple::${name}::ffiTypeCode]} {
        error "Redeclared simple data type: $name"
    }
    if { ! [exists ::dlr::simple::${existingType}::ffiTypeCode]} {
        error "Simple data type doesn't exist: $existingType"
    }
    # FFI type codes map.
    set ::dlr::simple::${name}::ffiTypeCode [get ::dlr::simple::${existingType}::ffiTypeCode]
    # size.
    set ::dlr::simple::${name}::size [get ::dlr::simple::${existingType}::size]
    set ::dlr::simple::${name}::bits [get ::dlr::simple::${existingType}::bits]
    # scriptForms list.
    set ::dlr::simple::${name}::scriptForms  [get ::dlr::simple::${existingType}::scriptForms]
    # converter aliases.
    foreach form [get ::dlr::simple::${name}::scriptForms] {
        alias  ::dlr::simple::${name}::pack-byVal-$form    ::dlr::simple::${existingType}::pack-byVal-$form
        alias  ::dlr::simple::${name}::unpack-byVal-$form  ::dlr::simple::${existingType}::unpack-byVal-$form
    }
}

# getter/setter for the refreshMeta boolean flag.
# this determines whether metadata and wrapper scripts will be regenerated (and cached again)
# when function and type declarations are processed.
# or, if refreshMeta is false, the existing cached copies will be used instead.
# note: if there is no existing cached copy of a given script, it will be regenerated
# as if refreshMeta is true.
# typically refreshMeta flag affects behavior during script app startup.
proc ::dlr::refreshMeta {args} {
    return [set ::dlr::refreshMetaFlag {*}$args]
}

proc ::dlr::fnAddr {fnName libAlias} {
    return [native::fnAddr $fnName [get ::dlr::libHandle::$libAlias]]
}

proc ::dlr::isStructType {typeVarName} {
    return [string match *::struct::* $typeVarName]
}

proc ::dlr::isMemManagedType {typeVarName} {
    return $( [isStructType $typeVarName] || $typeVarName in $::dlr::stringTypes )
}

# qualify any unqualified type name.
# a name already qualified is returned as-is.
# others are tested to see if they exist in the given library.  if so, return that one.
# others are tested to see if they're one of the simple types in ::dlr::simple.  if so, return that one.
# otherwise, notFoundAction is implemented.  that can be "error" (the default),
# or an empty string to ignore the problem and return an empty string instead.
# after qualifyTypeName, caller may use selectTypeMeta to fetch the required info for dlrNative.
proc ::dlr::qualifyTypeName {typeVarName  libAlias  {notFoundAction error}} {
    if {[string match *::* $typeVarName]} {
        return $typeVarName
    }
    # here we assume that libs describe only structs, never simple types.
    set sType ::dlr::lib::${libAlias}::struct::${typeVarName}
    if {[exists ${sType}::meta]} {
        return $sType
    }
    if {[exists ::dlr::simple::${typeVarName}::ffiTypeCode]} {
        return ::dlr::simple::$typeVarName
    }
    if {$notFoundAction eq {error}} {
        error "Unqualified type name could not be resolved: $typeVarName"
    }
    return {}
}

proc ::dlr::selectTypeMeta {type} {
    if {[isStructType $type]} {
        return ${type}::meta ;# return string name of variable holding struct type's metadata blob.
    }
    return ${type}::ffiTypeCode ;# return integer ffiTypeCode.
}

proc ::dlr::validateScriptForm {fullType scriptForm} {
    if {$fullType eq {::dlr::simple::void}} {
        return
    }
    if {[isStructType $fullType]} {
        set fullType ::dlr::struct
    }
    if {$scriptForm ni [get ${fullType}::scriptForms]} {
        error "Invalid scriptForm was given for type: $fullType"
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

proc ::dlr::converterName {conversion fullType passMethod scriptForm memAction} {
    if {[isMemManagedType $fullType]} {
        set memSuffix $( $memAction eq {}  ?  {}  :  "-$memAction" )
        return [structQal $fullType]::${conversion}-${passMethod}-${scriptForm}$memSuffix
    }
    return ${fullType}::${conversion}-${passMethod}-$scriptForm
}

# at each declaration, if scriptAction is applyScript, dlr source's the generated
# support scripts into the live interpreter.
# per the app's needs, it could instead define its own support procs (noScript).
# or it could source the generated ones, and then modify or further wrap certain ones.
#todo: more documentation
proc ::dlr::declareCallToNative {scriptAction  libAlias  returnTypeDescrip  fnName  parmsDescrip} {
    set fQal ::dlr::lib::${libAlias}::${fnName}::

    # memorize metadata for parms.
    set order [list]
    set orderNative [list]
    set typesMeta [list]
    foreach parmDesc $parmsDescrip {
        lassign $parmDesc  dir  passMethod  type  name  scriptForm  memAction
        set pQal ${fQal}parm::${name}::

        lappend order $name

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
        set ${pQal}passType $( $passMethod eq {byPtr} ? {::dlr::simple::ptr} : $fullType )
        lappend typesMeta [selectTypeMeta [get ${pQal}passType]]

        validateScriptForm $fullType $scriptForm
        set ${pQal}scriptForm  $scriptForm

        set ${pQal}memAction  $memAction
        if {$passMethod eq {byPtrPtr}} {
            # an empty string is acceptable, but it must be specified.
            if {[llength $parmDesc] < 6} {
                error "Expected memAction for parameter $passMethod $type $name."
            }
        }

        # assume there are 3 variables to hold packed native data:
        # ${pQal}targetNative for the target data (int, struct, ascii, etc).
        # ${pQal}ptrNative for a pointer to the target.
        # ${pQal}ptrPtrNative for a pointer to the pointer.  a few functions will use this to return a
        # pointer-to-struct or pointer-to-string.  any other function won't use it.

        # now choose which of those 3 will be passed to libffi for the actual native call.
        set nativeName  ${pQal}targetNative
        if {$passMethod eq {byPtr}} {
            set nativeName  ${pQal}ptrNative
        } elseif {$passMethod eq {byPtrPtr}} {
            set nativeName  ${pQal}ptrPtrNative
        }
        lappend orderNative $nativeName
    }
    set ${fQal}parmOrder        $order
    # keep alive orderNative so it's not garbage collected, for later use in callToNative.
    set ${fQal}orderNative      $orderNative

    # memorize metadata for return value.
    # it does not support other variable names for the native value, since that's generally hidden from scripts anyway.
    # it's always "out byVal" but does support different types and scriptForms.
    # it's not practical to support "out byPtr" here because there are many variations of
    # how the pointer's target was allocated, who is responsible for freeing that ram, etc.
    # instead that must be left to the script app to deal with.
    set rQal ${fQal}return::
    lassign $returnTypeDescrip  type scriptForm
    set fullType [qualifyTypeName $type $libAlias]
    set ${rQal}type  $fullType
    validateScriptForm $fullType $scriptForm
    set ${rQal}scriptForm  $scriptForm
    set ${rQal}unpacker  [converterName unpack $fullType byVal $scriptForm {}]
    # FFI requires padding the return buffer up to sizeof(ffi_arg).
    # on a big endian machine, that means unpacking from a higher address.
    set ${rQal}padding 0
    if { ! [exists ${fullType}::size]} {
        error "Type is not supported for function return value: $fullType"
    }
    if {[get ${fullType}::size] < $::dlr::simple::ffiArg::size && $::dlr::endian eq {be}} {
        set ${rQal}padding  $($::dlr::simple::ffiArg::size - [get ${fullType}::size])
    }
    set rMeta [selectTypeMeta $fullType]

    if {[refreshMeta] || ! [file readable [callWrapperPath $libAlias $fnName]]} {
        generateCallProc  $libAlias  $fnName  ::dlr::callToNative
    }

    #todo: enhance all error messages throughout the project.
    if {$scriptAction ni {applyScript noScript}} {
        error "Invalid script action: $scriptAction"
    }
    if {$scriptAction eq {applyScript}} {
        source [callWrapperPath  $libAlias  $fnName]
    }

    # prepare a metaBlob to hold dlrNative and FFI data structures.
    # do this last, to prevent an ill-advised callToNative using half-baked metadata
    # after an error preparing the metadata.  callToNative can't happen without this metaBlob.
    prepMetaBlob  ${fQal}meta  [::dlr::fnAddr  $fnName  $libAlias]  \
        ${rQal}native  $rMeta  $orderNative  $typesMeta  {}
}

# returns a boolean expression that can check for the null pointer flag at run time.
# some scriptForm's have code here to try and avoid shimmering, for more speed.
proc ::dlr::nullTestExpression {parmBare scriptForm} {
    if {$scriptForm eq {asString}} {
        return " \$$parmBare eq {$::dlr::nullPtrFlag} "
    } elseif {$scriptForm eq {asList}} {
        return " \[ llength \$$parmBare \] == 0 "
    } elseif {$scriptForm eq {asDict}} {
        return " \[ dict size \$$parmBare \] == 0 "
    } elseif {$scriptForm eq {asNative}} {
        error "Parameter '$parmBare' uses scriptForm '$scriptForm' which does not support testing for null, for 'byPtr' passMethod."
    }
    # all other scriptForms e.g. asInt, asDouble.
    return " \[ string length \$$parmBare \] == 0 "
}

# returns a value that represents a null pointer in script, when it appears as the
# target value being passed to/from a byPtr parameter of a function.
# the pointers themselves are handled asInt, so they don't use this at all.  it can only
# appear as a target value; that is a value which is to be targeted by a pointer
# during data conversion.
proc ::dlr::nullFlagValue {scriptForm} {
    return $( scriptForm eq {asString}  ?  $::dlr::nullPtrFlag  :  {} )
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
proc ::dlr::generateCallProc {libAlias  fnName  callCommand} {
    set fQal ::dlr::lib::${libAlias}::${fnName}::

    # to generate readable code:
    # start and end each append operation with a newline.
    # after each leading newline, put 4 spaces, plus 4 more for each enclosing brace block.
    # no spaces of indentation before a 'proc', or the matching close-brace of its body.
    # rely on the final regsub to collapse blank lines.

    # call packers to pack "in" parms.
    set procArgs [list]
    set procFormalParms [list]
    set body {}
    foreach  parmBare [get ${fQal}parmOrder] {
        # parmBare is the simple name of the parameter, such as "radix".

        # set up local names to access all the metadata for this parm.
        set pQal ${fQal}parm::${parmBare}::
        foreach v [info vars ${pQal}* ] {upvar  #0  $v  [namespace tail $v]}

        lappend procArgs $parmBare
        # Jim "reference arguments" are used to write to "out" and "inOut" parms in the caller's frame.
        lappend procFormalParms $( $dir in {out inOut} ? "&$parmBare" : "$parmBare" )

        # derive the names of the variables that might be used at run time.
        # most of these are the qualified names of the variable holding the parm's
        # packed binary data for one call, such as "::dlr::lib::testLib::strtolTest::parm::radix::targetNative"
        # that qualified name stays the same across calls, but often it must hold
        # a different value for each call, so its content must be repacked for each call.
        set targetNative ${pQal}targetNative
        set    ptrNative ${pQal}ptrNative
        set ptrPtrNative ${pQal}ptrPtrNative

        #todo: support asNative by wrapping some of the following code in "if asNative" and emit a plain "set"

        # pack a parm to pass in to the native func.  possibly its pointers also.
        # this must be done, even for "out" parms, to ensure buffer space is available
        # before the call.  that makes sense because ordinary C code always does that.
        set packer [converterName pack $type byVal $scriptForm {}]
        append body "\n    $packer  $targetNative  \$$parmBare \n"
        if {$passMethod in {byPtr byPtrPtr}} {
            # pass by pointer requires 2 packed native vars:  one for the target type's data,
            # and another for the pointer to it.  both must be packed to native before the call.
            set pBody "
        set addrOf$parmBare \[ ::dlr::addrOf  $targetNative \]
        ::dlr::simple::ptr::pack-byVal-asInt  $ptrNative  \$addrOf$parmBare
            "
            set pBodyNull "set  $ptrNative  \$::dlr::null \n"
            # pass by pointer-to-pointer-to-target requires a third native var.
            # its packing code will be inserted next to that of the first-degree pointer below.
            set ppBody {}
            set ppBodyNull {}
            if {$passMethod eq {byPtrPtr}} {
                set ppBody "::dlr::simple::ptr::pack-byVal-asInt  $ptrPtrNative  \[ ::dlr::addrOf  $ptrNative \]"
                set ppBodyNull "set  $ptrPtrNative  \$::dlr::null \n"
            }
            # check for the null pointer flag at run time.
            append body "
    if { [nullTestExpression $parmBare $scriptForm] } {
        $pBodyNull
        $ppBodyNull
    } else {
        $pBody
        $ppBody
    }
            "
        }
    }

    # call native function.
    #todo: see how much time is saved by specifying native callCommand's instead of aliases.  change at the 2 calls to generateCallProc.
    set rQal ${fQal}return::
    if {[get ${rQal}type] eq {::dlr::simple::void}} {
        append body "\n    $callCommand  ${fQal}meta \n"
    } else {
        append body "\n    set  ${rQal}native  \[ $callCommand  ${fQal}meta \] \n"
    }

    # call unpackers to unpack "out" parms.
    foreach  \
        parmBare  [get ${fQal}parmOrder]  \
        procArg  $procArgs  {

        # set up local names to access all the metadata for this parm.
        set pQal ${fQal}parm::${parmBare}::
        foreach v [info vars ${pQal}* ] {upvar  #0  $v  [namespace tail $v]}

        # derive the names of the variables that might be used at run time.
        set targetNative ${pQal}targetNative
        set    ptrNative ${pQal}ptrNative
        set ptrPtrNative ${pQal}ptrPtrNative
        set          ptr ${pQal}ptr

        # unpack a parm passed back from the native func.
        #todo: support nulls.
        if {$dir in {out inOut}} {
            if {$passMethod eq {byPtrPtr}} {
                if {[isMemManagedType $type]} {
                    # pointer given out by the native function must be unpacked first.
                    append body "\n    set  $ptr  \[ ::dlr::simple::ptr::unpack-byVal-asInt  \$$ptrNative \] \n"
                    # these types have optimized unpackers for byPtr.
                    set unpacker [converterName unpack $type scriptPtr $scriptForm $memAction]
                    append body "\n    set  $procArg  \[ $unpacker  \$$ptr \] \n"
                } else {
                    error "Type '$type' does not support '$dir' '$passMethod'."
                }
            } elseif {$passMethod eq {byPtr}} {
                if {[isMemManagedType $type]} {
                    # these types have optimized unpackers for byPtr.
                    set unpacker [converterName unpack $type scriptPtr $scriptForm $memAction]
                    append body "\n    set  $procArg  \[ $unpacker  \$addrOf$procArg \] \n"
                } else {
                    set unpacker [converterName unpack $type byVal $scriptForm {}]
                    append body "\n    set  $procArg  \[ $unpacker  \$$targetNative \] \n"
                }
            } else {
                set unpacker [converterName unpack $type byVal $scriptForm {}]
                append body "\n    set  $procArg  \[ $unpacker  \$$targetNative \] \n"
            }
        }
    }

    # unpack return value.
    if {[get ${rQal}type] ne {::dlr::simple::void}} {
        append body "\n    return  \[ [get ${rQal}unpacker] \$${rQal}native \$${rQal}padding \] \n"
    }

    # compose "proc" commands.
    set procCmd "proc  ${fQal}call  { $procFormalParms }  { \n$body \n} "
    # collapse multiple newlines into one, along with any preceding whitespace.
    regsub -all {([ ]*\n)+} $procCmd \n procCmd

    # save the generated code to a file.
    set path [callWrapperPath $libAlias $fnName]
    file mkdir [file dirname $path]
    set f [open $path w]
    puts $f $procCmd
    close $f

    return $procCmd
}

# this is the required first step before using a struct type.
#todo: documentation
proc ::dlr::declareStructType {scriptAction  libAlias  structTypeName  membersDescrip} {
    configureStructType  $libAlias  $structTypeName  $membersDescrip
    if {[refreshMeta] || ! [file readable [structConverterPath $libAlias $structTypeName]]} {
        detectStructLayout  $libAlias  $structTypeName
        validateStructType  $libAlias  $structTypeName
        generateStructConverters  $libAlias  $structTypeName
    } else {
        validateStructType  $libAlias  $structTypeName
    }
    if {$scriptAction ni {applyScript noScript}} {
        error "Invalid script action: $scriptAction"
    }
    if {$scriptAction eq {applyScript}} {
        source [structConverterPath  $libAlias  $structTypeName]
    }
}

proc ::dlr::configureStructType {libAlias  structTypeName  membersDescrip} {
    set sQal ::dlr::lib::${libAlias}::struct::${structTypeName}::

    # unpack metadata from the given declaration and memorize it.
    #todo: support nested structs.
    set ${sQal}memberOrder [list]
    foreach {mDescrip} $membersDescrip {
        lassign $mDescrip mType mName mScriptForm
        set mQal ${sQal}member::${mName}::

        lappend ${sQal}memberOrder $mName

        if { ! [exists ::dlr::simple::${mType}::ffiTypeCode]} {
            error "Library '$libAlias' struct '$typ' member '$mName' declared type is unknown."
        }
        set mFullType ::dlr::simple::$mType ;# qualifyTypeName should not be used here.  a simple type is required.
        set ${mQal}type $mFullType

        validateScriptForm $mFullType $mScriptForm
        set ${mQal}scriptForm $mScriptForm
    }
}

proc ::dlr::validateStructType {libAlias  structTypeName} {
    set sQal ::dlr::lib::${libAlias}::struct::${structTypeName}::

    # load up the type information previously detected and cached in the binding dir.
    set layoutFn [file join $::dlr::bindingDir $libAlias auto $structTypeName.struct]
    if { ! [file readable $layoutFn]} {
        error "Structure layout metadata was not detected for library '$libAlias' type '$typeName'."
    }
    set f [open $layoutFn r]
    set sDic [read $f]
    close $f

    # unpack metadata from the given declaration and merge it with the cached detected info.
    #todo: support nested structs.
    set ${sQal}size $sDic(size)
    set membersRemain [dict keys $sDic(members)]
    set typeMeta [list]
    foreach mName [get ${sQal}memberOrder] {
        set mQal ${sQal}member::${mName}::
        set mFullType [get ${mQal}type]
        lappend typeMeta [selectTypeMeta $mFullType]

        set ix [lsearch $membersRemain $mName]
        if {$ix < 0} {
            error "Library '$libAlias' struct '$typ' member '$mName' is not found in the detected metadata."
        }
        set membersRemain [lreplace $membersRemain $ix $ix]

        set mDic [dict get $sDic members $mName]
        set ${mQal}offset $mDic(offset)

        if {$mDic(size) != [get ${mFullType}::size]} {
            error "Library '$libAlias' struct '$typ' member '$mName' declared type does not match its size in the detected metadata."
        }
    }
    if {[llength $membersRemain] > 0} {
        # this could happen e.g. if the cached metadata was generated with an earlier version of the declaration.
        error "Library '$libAlias' struct '$typ' member '[lindex $membersRemain 0]' is mentioned in the detected metadata but not in the given declaration."
    }

    # prep FFI type record for this structure.  do this last of all.
    ::dlr::prepStructType  ${sQal}meta  $typeMeta
}

#todo: documentation similar to generateCallProc
proc ::dlr::generateStructConverters {libAlias  structTypeName} {
    set sQal ::dlr::lib::${libAlias}::struct::${structTypeName}::
    set procs [list]
    set packerParms {packVarName unpackedData {offsetBytes 0} {nextOffsetVarName {}}}
    set unpackerParms {packedValue {offsetBytes 0} {nextOffsetVarName {}}}
    set memberTemps [lmap m [get ${sQal}memberOrder] {expr {"mv::$m"}}]

    #todo: support asNative by emitting a plain "set".  support for the struct and for its members.

    set computeNext "
    if { \$nextOffsetVarName ne {}} {
        upvar \$nextOffsetVarName next
        set next \$( \$offsetBytes + \$${sQal}size )
    }
    "

    # generate pack-byVal-asList
    set body "
    lassign \$unpackedData  [join $memberTemps {  }]
    ::dlr::createBufferVar  \$packVarName  \$${sQal}size
    "
    foreach  mName [get ${sQal}memberOrder]  mTemp $memberTemps  {
        set mQal ${sQal}member::${mName}::
        set packer [converterName   pack  [get ${mQal}type]  byVal  [get ${mQal}scriptForm]  {}]
        append body "\n    $packer  \$packVarName  \$$mTemp  \$( \$offsetBytes + \$${mQal}offset ) \n"
        # that could run faster (maybe?) if it placed the offset integer into the script
        # instead of fetching it from metadata at run time.  then again, it might not.
        # it would definitely be harder to read and maintain with the magic numbers,
        # and more likely to fail after the struct is recompiled.
    }
    append body $computeNext
    lappend procs "proc  ${sQal}pack-byVal-asList  { $packerParms }  { \n$body \n}"

    # generate pack-byVal-asDict
    set body "\n    ::dlr::createBufferVar  \$packVarName  \$${sQal}size \n"
    foreach  mName [get ${sQal}memberOrder]  {
        set mQal ${sQal}member::${mName}::
        set packer [converterName   pack  [get ${mQal}type]  byVal  [get ${mQal}scriptForm]  {}]
        append body "\n    $packer  \$packVarName  \$unpackedData($mName)  \$( \$offsetBytes + \$${mQal}offset ) \n"
    }
    append body $computeNext
    lappend procs "proc  ${sQal}pack-byVal-asDict  { $packerParms }  { \n$body \n}"

    # generate unpack-byVal-asList
    set body $computeNext
    append body  "\n    return  \[ list  " \\ \n
    foreach  mName [get ${sQal}memberOrder]  {
        set mQal ${sQal}member::${mName}::
        set unpacker [converterName  unpack  [get ${mQal}type]  byVal  [get ${mQal}scriptForm]  {}]
        append body "\n        \[ $unpacker  \$packedValue  \$( \$offsetBytes + \$${mQal}offset ) \] " \\ \n
    }
    append body "\n    \] \n"
    lappend procs "proc  ${sQal}unpack-byVal-asList  { $unpackerParms }  { \n$body \n}"

    # generate unpack-byVal-asDict
    set body $computeNext
    append body  "\n    return  \[ dict create  " \\ \n
    foreach  mName [get ${sQal}memberOrder]  {
        set mQal ${sQal}member::${mName}::
        set unpacker [converterName  unpack  [get ${mQal}type]  byVal  [get ${mQal}scriptForm]  {}]
        append body "\n        $mName \[ $unpacker  \$packedValue  \$( \$offsetBytes + \$${mQal}offset ) \] " \\ \n
    }
    append body "\n    \] \n"
    lappend procs "proc  ${sQal}unpack-byVal-asDict  { $unpackerParms }  { \n$body \n}"

    # alias some more utility functions for this type.
    foreach scriptForm $::dlr::struct::scriptForms {
        lappend procs "alias  ${sQal}unpack-scriptPtr-${scriptForm}-free  ::dlr::struct::unpack-scriptPtr-free  $scriptForm  [string trimright $sQal :]"
    }

    # collapse multiple newlines into one, along with any preceding whitespace.
    set script [join $procs \n\n]
    regsub -all {([ ]*\n)+} $script \n script

    # save the generated code to a file.
    set path [structConverterPath $libAlias $structTypeName]
    file mkdir [file dirname $path]
    set f [open $path w]
    puts $f $script
    close $f

    return $script
}

# works with either gcc or clang.
# struct layout metadata is returned, and also cached in the binding dir.
proc ::dlr::detectStructLayout {libAlias  typeName} {
    set sQal ::dlr::lib::${libAlias}::struct::${typeName}::

    # determine paths.
    set cFn      [file join $::dlr::bindingDir $libAlias auto detectStructLayout.c]
    set binFn    [file join $::dlr::bindingDir $libAlias auto detectStructLayout]
    set layoutFn [file join $::dlr::bindingDir $libAlias auto $typeName.struct]
    set headerFn [file join $::dlr::bindingDir $libAlias script includes.h]
    file mkdir [file dirname $cFn]
    file mkdir [file dirname $binFn]
    file mkdir [file dirname $layoutFn]

    # read header file of #include's.
    set hdr [open $headerFn r]
    set includes [subst -nobackslashes [read $hdr]]
    close $hdr

    # generate C source code to extract metadata.
    foreach mName [get ${sQal}memberOrder] {
        append membCode "
            printf(\"    {$mName} {size %zu offset %zu }\\n\",
                sizeof( a.$mName ), offsetof($typeName, $mName) );
        "
    }
    set src [open $cFn w]
    puts $src "
        #include <stddef.h>
        #include <stdio.h>

        $includes

        int main (int argc, char **argv) {
            $typeName a;
            printf(\"name {$typeName} size %zu members {\\n\", sizeof($typeName));
            $membCode
            puts(\"}\\n\");
        }
    "
    close $src

    # compile and execute C code.
    eval $::dlr::compiler
    set dic [exec $binFn]

    # cache metadata in binding dir.
    set lay [open $layoutFn w]
    puts $lay $dic
    close $lay

    return $dic
}


proc ::dlr::callWrapperPath {libAlias  fnName} {
    return [file join $::dlr::bindingDir $libAlias auto $fnName.call.tcl]
}

proc ::dlr::structConverterPath {libAlias  structTypeName} {
    return [file join $::dlr::bindingDir $libAlias auto $structTypeName.convert.tcl]
}

# does a copyToBufferVar followed by unpack-byVal.
# useful when a native function returns a pointer to a struct as the function return value,
# or it takes a parm that is pointer-to-pointer-to-struct, and sets the pointer e.g. by malloc'ing a struct.
# this command helps to simplify memory management wrappers for those, in library binding scripts.
# parameters are in this order for easy aliasing.
proc ::dlr::struct::unpack-scriptPtr {scriptForm  structTypeName  pointerIntValue} {
    ::dlr::copyToBufferVar  native  [::dlr::get ${structTypeName}::size]  $pointerIntValue
    return [${structTypeName}::unpack-byVal-$scriptForm  $native]
}

# equivalent to unpack-scriptPtr followed by freeHeap.
proc ::dlr::struct::unpack-scriptPtr-free {scriptForm  structTypeName  pointerIntValue} {
    ::dlr::copyToBufferVar  native  [::dlr::get ${structTypeName}::size]  $pointerIntValue
    set unpackedData [${structTypeName}::unpack-byVal-$scriptForm  $native]
    ::dlr::freeHeap $pointerIntValue
    return $unpackedData
}

# equivalent to ascii::unpack-scriptPtr-asString followed by freeHeap.
proc ::dlr::simple::ascii::unpack-scriptPtr-asString-free {pointerIntValue} {
    set unpackedData [::dlr::simple::ascii::unpack-scriptPtr-asString $pointerIntValue]
    ::dlr::freeHeap $pointerIntValue
    return $unpackedData
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

::dlr::initDlr

