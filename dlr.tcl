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

package provide dlr 0.1

package require dlrNative

# system data structures
set ::dlr::sizeOfPtrBits        $(8 * [::dlr::native::sizeOfPtr])
set ::dlr::ptrFmt               0x%0$($::dlr::sizeOfPtrBits / 4)X
pack ::dlr::nullPtr             0 -intle $::dlr::sizeOfPtrBits
set ::dlr::libs                 [dict create]

# aliases to pass through to native implementations.
alias  ::dlr::prepMetaBlob      ::dlr::native::prepMetaBlob
alias  ::dlr::callToNative      ::dlr::native::callToNative
alias  ::dlr::createBufferVar   ::dlr::native::createBufferVar
alias  ::dlr::addrOf            ::dlr::native::addrOf
alias  ::dlr::sizeOfPtr         ::dlr::native::sizeOfPtr
alias  ::dlr::sizeOfInt         ::dlr::native::sizeOfInt

proc ::dlr::loadLib {libAlias fileNamePath} {
    set handle [native::loadLib $fileNamePath]
    set ::dlr::libs($libAlias) $handle
    return {}
}

proc ::dlr::fnAddr {fnName libAlias} {
    return [native::fnAddr $fnName $::dlr::libs($libAlias)]
}

