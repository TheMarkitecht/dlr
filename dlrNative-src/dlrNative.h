/*
"dlr" - Dynamic Library Redux
Copyright 2020 Mark Hubbard, a.k.a. "TheMarkitecht"
http://www.TheMarkitecht.com

Project home:  http://github.com/TheMarkitecht/dlr
dlr is an extension for Jim Tcl (http://jim.tcl.tk/)
dlr may be easily pronounced as "dealer".

This file is part of dlr.

dlr is free software: you can redistribute it and/or modify
it under the terms of the GNU Lesser General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

dlr is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public License
along with dlr.  If not, see <https://www.gnu.org/licenses/>.
*/

#include <stdint.h>
#include <ffi.h>
//todo: clone, build and test with latest libffi.  system's libffi6-3.2.1-9 is 2014.

typedef  uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;
typedef   int8_t i8;
typedef  int16_t i16;
typedef  int32_t i32;
typedef  int64_t i64;


extern int loadLib(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) ;

extern int fnAddr(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) ;

extern int sizeOfTypes(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) ;

extern int addrOf(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) ;

extern int allocHeap(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) ;

extern int freeHeap(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) ;

extern int createBufferObj(Jim_Interp* itp, int len, void** newBufP, Jim_Obj** newObjP) ;

extern int createBufferVarNative(Jim_Interp* itp, Jim_Obj* varName, int len, void** newBufP, Jim_Obj** newObjP) ;

extern int createBufferVar(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) ;

extern int copyToBufferVar(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) ;

extern int varToTypeP(Jim_Interp* itp, Jim_Obj *var, ffi_type** typ) ;

extern int prepStructType(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) ;

extern int prepMetaBlob(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) ;

extern int callToNative(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) ;

#ifdef BUILD_GIZMO
extern int callToGI(Jim_Interp* itp, int objc, Jim_Obj * const objv[]);
#endif

extern int packerSetup_byVal(Jim_Interp* itp, int objc, Jim_Obj * const objv[],
    int sizeBytes, void** bufP);

extern int packerSetup_byVal_asInt(Jim_Interp* itp, int objc, Jim_Obj * const objv[], jim_wide* dataP) ;

extern int packerSetup_byVal_asDouble(Jim_Interp* itp, int objc, Jim_Obj * const objv[], double* dataP) ;

extern int u8_pack_byVal_asInt(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) ;

extern int u16_pack_byVal_asInt(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) ;

extern int u32_pack_byVal_asInt(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) ;

extern int u64_pack_byVal_asInt(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) ;

extern int i8_pack_byVal_asInt(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) ;

extern int i16_pack_byVal_asInt(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) ;

extern int i32_pack_byVal_asInt(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) ;

extern int i64_pack_byVal_asInt(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) ;

extern int double_pack_byVal_asDouble(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) ;

extern int float_pack_byVal_asDouble(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) ;

extern int longDouble_pack_byVal_asDouble(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) ;

extern int ascii_pack_byVal_asString(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) ;

extern int unpackerSetup_byVal(Jim_Interp* itp, int objc, Jim_Obj * const objv[],
    int sizeBytes, void** bufP);

extern int unpackerSetup_scriptPtr(Jim_Interp* itp, int objc, Jim_Obj * const objv[],
    int sizeBytes, void** bufP);

extern int u8_unpack_byVal_asInt(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) ;

extern int u16_unpack_byVal_asInt(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) ;

extern int u32_unpack_byVal_asInt(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) ;

extern int u64_unpack_byVal_asInt(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) ;

extern int i8_unpack_byVal_asInt(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) ;

extern int i16_unpack_byVal_asInt(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) ;

extern int i32_unpack_byVal_asInt(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) ;

extern int i64_unpack_byVal_asInt(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) ;

extern int float_unpack_byVal_asDouble(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) ;

extern int double_unpack_byVal_asDouble(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) ;

extern int longDouble_unpack_byVal_asDouble(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) ;

extern int ascii_unpack_byVal_asString(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) ;

extern int ascii_unpack_scriptPtr_asString(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) ;

// this function's name is based on the library's actual filename.  Jim requires that.
extern int Jim_dlrNativeInit(Jim_Interp* itp);

