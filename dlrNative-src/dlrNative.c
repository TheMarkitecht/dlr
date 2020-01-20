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

#include <unistd.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <dlfcn.h>
#include <jim.h>
#include <ffi.h>
//todo: clone, build and test with latest libffi.  system's libffi6-3.2.1-9 is 2014.

#define DLR_VERSION_STRING "0.2"

//todo: periodically re-run all tests, and valgrind, with full compiler optimization on dlr and on the interp.  code may behave differently.

typedef  uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;
typedef   int8_t i8;
typedef  int16_t i16;
typedef  int32_t i32;
typedef  int64_t i64;

typedef void (*ffiFnP)(void);

// map type ID codes to type metadata structs.
// to prevent confusion, the order here corresponds exactly to the indices given by
// FFI_TYPE_* define's in ffi.h line 459.
ffi_type * const ffiTypes[] = {
    &ffi_type_void,
    NULL, // FFI_TYPE_INT unusable; not specific enough.
    &ffi_type_float,
    &ffi_type_double,
    &ffi_type_longdouble,
    &ffi_type_uint8,
    &ffi_type_sint8,
    &ffi_type_uint16,
    &ffi_type_sint16,
    &ffi_type_uint32,
    &ffi_type_sint32,
    &ffi_type_uint64,
    &ffi_type_sint64,
    NULL, // FFI_TYPE_STRUCT unusable; length unknown.
    &ffi_type_pointer,
    NULL, // FFI_TYPE_COMPLEX unusable; not specific enough.
};

#define FFI_TYPE_FINAL  FFI_TYPE_COMPLEX

typedef struct {
    // this signature serves 2 purposes:  
    // it allows C code to verify the metablob is intact, meaning the script hasn't stepped on it.
    // and it provides a sane appearance if script prints the metablob.
    char signature[5];
    ffi_cif cif;
    ffiFnP fn;
    Jim_Obj* returnVar;
    size_t returnSizePadded;
    Jim_Obj* nativeParmsList;
    ffi_type* atypes; // placeholder for first element of the array of type pointers located directly at the end of the structure.
} metaBlobT;
static const char METABLOB_SIGNATURE[] = "meta";

// this function's name is based on the library's actual filename.  Jim requires that. 
extern int Jim_dlrNativeInit(Jim_Interp* itp);

/* **********************  EXECUTABLE CODE BELOW  ***************************** */

int loadLib(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    enum { 
        cmdIX = 0,
        fileNamePathIX,
        argCount
    };
    
    if (objc != argCount) {
        Jim_SetResultString(itp, "Wrong # args.", -1);
        return JIM_ERR;
    }
    
    const char* path = Jim_GetString(objv[fileNamePathIX], NULL);
    void *handle = dlopen(path, RTLD_NOW | RTLD_GLOBAL);
    if (handle == NULL) {
        Jim_SetResultFormatted(itp, "Error loading shared lib \"%s\": %s", path, dlerror());
        return JIM_ERR;
    }
    Jim_SetResultInt(itp, (jim_wide)handle);    
    return JIM_OK;
}

// returns (to the script) an integer which is the memory address of the 
// given function name in the given library handle.
int fnAddr(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    enum { 
        cmdIX = 0,
        fnNameIX,
        libHandleIX,
        argCount
    };
    
    if (objc != argCount) {
        Jim_SetResultString(itp, "Wrong # args.", -1);
        return JIM_ERR;
    }

    const char* fnName = Jim_GetString(objv[fnNameIX], NULL);
    if (fnName == NULL) {
        Jim_SetResultString(itp, "Expected function name but got other data.", -1);
        return JIM_ERR;
    }
    jim_wide w = 0;
    if (Jim_GetWide(itp, objv[libHandleIX], &w) != JIM_OK) {
        Jim_SetResultString(itp, "Expected lib handle but got other data.", -1);
        return JIM_ERR;
    }
    void* libHandle = (void*)w;
    if (libHandle == NULL) {
        Jim_SetResultString(itp, "Lib handle is null.", -1);
        return JIM_ERR;
    }

    ffiFnP fn = (ffiFnP)dlsym(libHandle, fnName);
    if (fn == NULL) {
        Jim_SetResultFormatted(itp, "No %s symbol found in library.", fnName);
        return JIM_ERR;
    }
    Jim_SetResultInt(itp, (jim_wide)fn);
    return JIM_OK;
}

// return a dict of dimensions of types on the host platform where dlr was built.
int sizeOfTypes(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    Jim_Obj* lens[] = {
        Jim_NewStringObj(itp, "char", -1),          Jim_NewIntObj(itp, (jim_wide)sizeof(char)), // guaranteed 1 by the C99 standard.
        Jim_NewStringObj(itp, "short", -1),         Jim_NewIntObj(itp, (jim_wide)sizeof(short)),
        Jim_NewStringObj(itp, "int", -1),           Jim_NewIntObj(itp, (jim_wide)sizeof(int)),
        Jim_NewStringObj(itp, "long", -1),          Jim_NewIntObj(itp, (jim_wide)sizeof(long)),
        Jim_NewStringObj(itp, "longLong", -1),      Jim_NewIntObj(itp, (jim_wide)sizeof(long long)),
        Jim_NewStringObj(itp, "ptr", -1),           Jim_NewIntObj(itp, (jim_wide)sizeof(void*)),
        Jim_NewStringObj(itp, "sSizeT", -1),        Jim_NewIntObj(itp, (jim_wide)sizeof(ssize_t)),
        Jim_NewStringObj(itp, "float", -1),         Jim_NewIntObj(itp, (jim_wide)sizeof(float)),
        Jim_NewStringObj(itp, "double", -1),        Jim_NewIntObj(itp, (jim_wide)sizeof(double)),
        Jim_NewStringObj(itp, "longDouble", -1),    Jim_NewIntObj(itp, (jim_wide)sizeof(long double)),
        Jim_NewStringObj(itp, "ffiArg", -1),        Jim_NewIntObj(itp, (jim_wide)sizeof(ffi_arg)),
    };
    int numTypes = sizeof(lens) / sizeof(Jim_Obj*);
    for (int i = 0; i < numTypes; i++) {
        if (lens[i] == NULL) {
            Jim_SetResultString(itp, "Couldn't create new object.", -1);
            return JIM_ERR;
        }
    }
    Jim_Obj* d = Jim_NewDictObj(itp, lens, numTypes);
    if (d == NULL) {
        Jim_SetResultString(itp, "Couldn't create new dictionary.", -1);
        return JIM_ERR;
    }
    Jim_SetResult(itp, d);
    return JIM_OK;
}

/*
addrOf() returns (to the script) an integer which is the memory address of the 
content bytes of the given variable name.  this always refers to the 
string representation, and none of Jim's internal representations.
if the variable object's string representation is outdated due to
previous script actions, then this command automatically updates it
from the object's internal reps before extracting the address.
(that's normal behavior for any Tcl command that requires a string.)
thus addrOf() always returns a pointer to a string buffer.  
in C, that is a "char*".  the buffer contains a string of ASCII or
UTF8, or if it was prepared by packing, it contains a binary blob.
note: if the string rep is already up to date, then it won't be touched,
and will yield the same address as the last call to addrOf().  that's
the case if the script hasn't assigned to that variable at all since 
the last call to addrOf().
*/
int addrOf(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    enum { 
        cmdIX = 0,
        varNameIX,
        argCount
    };
    
    if (objc != argCount) {
        Jim_SetResultString(itp, "Wrong # args.", -1);
        return JIM_ERR;
    }

    Jim_Obj* v = Jim_GetVariable(itp, objv[varNameIX], JIM_NONE);
    if (v == NULL) {
        Jim_SetResultString(itp, "Variable not found.", -1);
        return JIM_ERR;
    }
    Jim_SetResultInt(itp, (jim_wide)Jim_GetString(v, NULL));
    return JIM_OK;
}

// provides direct use of the system heap through Jim_Alloc(), for scripts.
// size is expected to be a script integer, not binary packed.
// heap pointer is returned as a script integer, not binary packed.
// throws a script error if the alloc fails.
// this command creates easy opportunities for memory leaks and other bugs,
// and blatant tests of such leaks have somehow eluded valgrind!
// therefore createBufferVar is recommended instead.  that way the interpreter 
// tracks the memory block and can collect it automatically.
// Jim's pack command works easily with that.
// Jim references should work well with that too.
int allocHeap(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    enum { 
        cmdIX = 0,
        sizeIX,
        argCount
    };
    
    if (objc != argCount) {
        Jim_SetResultString(itp, "Wrong # args.", -1);
        return JIM_ERR;
    }

    jim_wide size;
    if (Jim_GetWide(itp, objv[sizeIX], &size) != JIM_OK) {
        Jim_SetResultString(itp, "Expected size integer but got other data.", -1);
        return JIM_ERR;
    }
    void* ptr = NULL;
    if (size > 0) {
        ptr = Jim_Alloc((int)size);
        if (ptr == NULL) {
            Jim_SetResultString(itp, "Alloc failed! Maybe out of heap memory.", -1);
            return JIM_ERR;
        }
    }        
    Jim_SetResultInt(itp, (jim_wide)ptr);
    return JIM_OK;
}

// provides direct use of the system heap through Jim_Free(), for scripts.
// pointer is expected to be a script integer, not binary packed.
// silently ignores a NULL pointer.
int freeHeap(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    enum { 
        cmdIX = 0,
        ptrIX,
        argCount
    };
    
    if (objc != argCount) {
        Jim_SetResultString(itp, "Wrong # args.", -1);
        return JIM_ERR;
    }

    jim_wide ptr;
    if (Jim_GetWide(itp, objv[ptrIX], &ptr) != JIM_OK) {
        Jim_SetResultString(itp, "Expected heap pointer but got other data.", -1);
        return JIM_ERR;
    }
    void* p = (void*)ptr;
    if (p != NULL)
        Jim_Free(p);
    return JIM_OK;
}

// create a Jim_Obj suitable for holding a binary structure of the given length.  
// sets *newBufP to point to the structure.
// sets *newObjP to point to the new Jim_Obj.
int createBufferObj(Jim_Interp* itp, int len, void** newBufP, Jim_Obj** newObjP) {
    char* buf = Jim_Alloc(len + 1); // extra 1 for null terminator is not needed for dlr, but may be needed by any further script operations on the object.
    if (buf == NULL) {
        Jim_SetResultString(itp, "Out of memory while allocating buffer.", -1);
        return JIM_ERR;
    }  
    buf[len] = 0; // last-ditch safety for any further script operations on the object.
    *newBufP = (void*)buf;
    *newObjP = Jim_NewStringObjNoAlloc(itp, buf, len);
    return JIM_OK;
}

// create and set a script variable having the given name, suitable for holding a binary
// structure of the given length.  
// if newBufP is not null, sets *newBufP to point to the structure.
// if newObjP is not null, sets *newObjP to point to the new Jim_Obj.
int createBufferVarNative(Jim_Interp* itp, Jim_Obj* varName, int len, void** newBufP, Jim_Obj** newObjP) {
    void* buf = NULL;
    Jim_Obj* valueObj = NULL;
    if (createBufferObj(itp, len, &buf, &valueObj) != JIM_OK) 
        return JIM_ERR;
    if (Jim_SetVariable(itp, varName, valueObj) != JIM_OK) {
        Jim_SetResultString(itp, "Failed to set variable for buffer.", -1);
        return JIM_ERR;
    }    
    if (newBufP) *newBufP = (void*)buf;
    if (newObjP) *newObjP = valueObj;
    return JIM_OK;
}

// exposes createBufferVarNative() to script.
int createBufferVar(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    enum { 
        cmdIX = 0,
        varNameIX,
        lenIX,
        argCount
    };
    
    if (objc != argCount) {
        Jim_SetResultString(itp, "Wrong # args.", -1);
        return JIM_ERR;
    }

    jim_wide len;
    if (Jim_GetWide(itp, objv[lenIX], &len) != JIM_OK) {
        Jim_SetResultString(itp, "Expected size integer but got other data.", -1);
        return JIM_ERR;
    }
    return createBufferVarNative(itp, objv[varNameIX], (int)len, NULL, NULL);
}

int varToTypeP(Jim_Interp* itp, Jim_Obj *var, ffi_type** typ) {
    Jim_Obj* typeObj = Jim_GetVariable(itp, var, JIM_ERRMSG);
    if (typeObj == NULL) return JIM_ERR;
    jim_wide code = 0;
    if (Jim_GetWide(itp, typeObj, &code) == JIM_OK) {
        // found integer.  valid type code?
        if (code < 0 || code > FFI_TYPE_FINAL || ffiTypes[code] == NULL) {
            Jim_SetResultString(itp, "Invalid type ID code integer.", -1);
            return JIM_ERR;
        }
        *typ = ffiTypes[code];
        return JIM_OK;
    } 
    *typ = (ffi_type*)Jim_GetString(typeObj, NULL);
    if (*typ == NULL || typeObj->length < sizeof(ffi_type)) {
        Jim_SetResultString(itp, "Structure type metadata variable is unusable.", -1);
        return JIM_ERR;
    }  
    return JIM_OK;
}

//todo: test with nested structs.
int prepStructType(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    enum { 
        cmdIX = 0,
        structTypeVarNameIX,
        memberTypeVarNameListIX,
        argCount
    };
    
    if (objc != argCount) {
        Jim_SetResultString(itp, "Wrong # args.", -1);
        return JIM_ERR;
    }
    
    // create buffer variable for type blob.  first we must determine its final size from the number of its members.
    Jim_Obj* typesList = objv[memberTypeVarNameListIX];
    int nMemb = Jim_ListLength(itp, typesList);
    int blobLen = sizeof(ffi_type) + (nMemb + 1) * sizeof(ffi_type*);
    ffi_type* structTyp;
    if (createBufferVarNative(itp, objv[structTypeVarNameIX], blobLen, (void**)&structTyp, NULL) != JIM_OK) return JIM_ERR;
    structTyp->type = FFI_TYPE_STRUCT;
    structTyp->size = 0;
    structTyp->alignment = 0;
    
    // gather members types.
    structTyp->elements = (ffi_type**)(structTyp + 1); // now structTyp->elements can be treated as the types array at the end of the struct.
    for (int n = 0; n < nMemb; n++) {
        if (varToTypeP(itp, Jim_ListGetIndex(itp, typesList, n), &structTyp->elements[n]) != JIM_OK) {
            Jim_SetResultString(itp, "Variable defining a member type is unusable.", -1);
            return JIM_ERR;
        }  
    }  
    structTyp->elements[nMemb] = NULL; // terminating NULL element is required by FFI.
    
    return JIM_OK;
}

// prepMetaBlob builds or updates a metadata binary structure, storing it in the given variable.
// it makes all preparations necessary for a series of callToNative for one native function.
// after any of the metadata passed into prepMetaBlob has been touched by script, 
// script must call prepMetaBlob again to update the metaBlob.
// failure to do that will probably crash the interp, or corrupt it.
// (the contents of the native parameter variables themselves are not subject to that,
// since those are not passed to prepMetaBlob.  
// instead their contents are assumed to be different for each callToNative.)
// likewise, failure to prepMetaBlob before the first callToNative will probably 
// crash the interp, or corrupt it.
// prepMetaBlob mainly converts type codes to type pointers, so it can call ffi_prep_cif.
int prepMetaBlob(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    enum { 
        cmdIX = 0,
        metaBlobVarNameIX,
        fnPIX,
        returnVarNameIX,
        returnTypeVarNameIX,
        nativeParmsListIX,
        parmTypeVarNameListIX,
        argCount
    };
    
    if (objc != argCount) {
        Jim_SetResultString(itp, "Wrong # args.", -1);
        return JIM_ERR;
    }
    
    // create buffer variable for metablob.  first we must determine its final size.
    int nArgs = Jim_ListLength(itp, objv[nativeParmsListIX]);
    int blobLen = sizeof(metaBlobT) + nArgs * sizeof(ffi_type*);
    metaBlobT* meta;
    if (createBufferVarNative(itp, objv[metaBlobVarNameIX], blobLen, (void**)&meta, NULL) != JIM_OK) return JIM_ERR;
    *(u32*)meta->signature = *(u32*)METABLOB_SIGNATURE;
    meta->signature[4] = 0; // string safety.
    
    // memorize function pointer.
    jim_wide w = 0;
    if (Jim_GetWide(itp, objv[fnPIX], &w) != JIM_OK) {
        Jim_SetResultString(itp, "Expected function pointer but got other data.", -1);
        return JIM_ERR;
    }
    meta->fn = (ffiFnP)w;
    if (meta->fn == NULL) {
        Jim_SetResultString(itp, "Null function pointer.", -1);
        return JIM_ERR;
    }  

    // gather return-value metadata.
    meta->returnVar = objv[returnVarNameIX];
    ffi_type* rtype = NULL;
    if (varToTypeP(itp, objv[returnTypeVarNameIX], &rtype) != JIM_OK) return JIM_ERR;

    // gather parm metadata.
    meta->nativeParmsList = objv[nativeParmsListIX];
    Jim_Obj* typesList = objv[parmTypeVarNameListIX];
    if (nArgs != Jim_ListLength(itp, typesList)) {
        Jim_SetResultString(itp, "List lengths don't match.", -1);
        return JIM_ERR;
    }
    ffi_type** t = &meta->atypes; // now t can be treated as the types array at the end of the struct.
    for (int n = 0; n < nArgs; n++) {
        Jim_Obj* typeVar = Jim_ListGetIndex(itp, typesList, n);
        if (varToTypeP(itp, typeVar, &t[n]) != JIM_OK) return JIM_ERR;
    }  
    
    // prep CIF.
    // this will also set the .size of any structure types used here.
    ffi_status err = ffi_prep_cif(&meta->cif, FFI_DEFAULT_ABI, (unsigned int)nArgs, rtype, &meta->atypes);
    if (err != FFI_OK) {
        Jim_SetResultString(itp, "Failed to prep FFI CIF structure for call.", -1);
        return JIM_ERR;
    }  

    if (rtype == &ffi_type_void) {
        meta->returnSizePadded = 0;
    } else {
        // calculate padding of return value AFTER ffi_prep_cif(), since that's where 
        // rtype->size is computed if rtype is a struct type.
        meta->returnSizePadded = rtype->size;
        // FFI requires padding the return variable up to sizeof(ffi_arg).
        if (meta->returnSizePadded < sizeof(ffi_arg)) 
            meta->returnSizePadded = sizeof(ffi_arg);
    }
    
    return JIM_OK;
}

int callToNative(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    enum { 
        cmdIX = 0,
        metaBlobVarNameIX,
        argCount
    };
    
    if (objc != argCount) {
        Jim_SetResultString(itp, "Wrong # args.  Should be: callToNative metaBlobVarName", -1);
        return JIM_ERR;
    }

    // find metaBlob for this native function.
    Jim_Obj* metaBlobObj = Jim_GetVariable(itp, objv[metaBlobVarNameIX], JIM_NONE);
    if (metaBlobObj == NULL) {
        Jim_SetResultString(itp, "MetaBlob variable not found.", -1);
        return JIM_ERR;
    }
    // Jim_GetString() not used here.  we can detect an invalid metablob without it, and faster.
    metaBlobT* meta = (metaBlobT*)metaBlobObj->bytes;
    if (meta == NULL || *(u32*)meta->signature != *(u32*)METABLOB_SIGNATURE) {
        Jim_SetResultString(itp, "Invalid metaBlob content.", -1);
        return JIM_ERR;
    }
    
    // fill argPtrs with pointers to the content of designated script vars.
    // those objects have the buffers for the packed native binary content during this native call.
    // their content has probably moved to a new address since the last call,
    // and their Jim_Obj's replaced with new ones,
    // because the script assigned them new values since then.
    unsigned nArgs = meta->cif.nargs;
    void* argPtrs[nArgs];
    for (unsigned n = 0; n < nArgs; n++) {
        // look up the designated variable, in a global context.
        // using internalRep of the parms list here for a little more speed.
        Jim_Obj* varName = meta->nativeParmsList->internalRep.listValue.ele[n];
        Jim_Obj* v = Jim_GetGlobalVariable(itp, varName, JIM_NONE);
        if (v == NULL) {
            Jim_SetResultString(itp, "Native argument variable not found.", -1);
            return JIM_ERR;
        }
        // const is discarded here.  that is required, to be able to pass an argument by pointer
        // either in or out of a native function.  that is required for large data.
        argPtrs[n] = (void*)Jim_GetString(v, NULL); 
        // safety check.
        // we'll let it slide here if the script allocated just enough bytes for the value,
        // and no extra byte for a null terminator.  not all parms are strings.
        if (argPtrs[n] == NULL || v->length < meta->cif.arg_types[n]->size) {
            Jim_SetResultFormatted(itp, "Inadequate buffer in argument variable: %s", 
                Jim_GetString(varName, NULL));
            return JIM_ERR;
        }
    }  

    if (meta->cif.rtype == &ffi_type_void) {
        // arrange space for a junk return value, just in case libffi decides to write one.
        ffi_arg rtn;

        // execute call.
        ffi_call(&meta->cif, meta->fn, &rtn, argPtrs);
        Jim_SetEmptyResult(itp);
    } else {
        // arrange space for return value.
        void* resultBuf = NULL;
        Jim_Obj* resultObj = NULL;
        if (createBufferObj(itp, meta->returnSizePadded, &resultBuf, &resultObj) != JIM_OK) return JIM_ERR;

        // execute call.
        ffi_call(&meta->cif, meta->fn, resultBuf, argPtrs);
        Jim_SetResult(itp, resultObj);
    }
    
    //todo: optionally check for errors, in the ways offered by the most common libs.    
    //todo: optionally call a custom error checking function.
    return JIM_OK;
}

enum { 
    pk_cmdIX = 0,
    pk_packVarNameIX,
    pk_unpackedDataIX,
    pk_offsetBytesIX,
    pk_nextOffsetVarNameIX,
    pk_argCount
} pk_args;

int packerSetup_byVal(Jim_Interp* itp, int objc, Jim_Obj * const objv[], 
    int sizeBytes, void** bufP) {
            
    if (objc > pk_argCount || objc < pk_offsetBytesIX) {
        Jim_SetResultString(itp, "Wrong # args.", -1);
        return JIM_ERR;
    }
    
    jim_wide offset = 0;
    if (objc > pk_offsetBytesIX) {
        if (Jim_GetWide(itp, objv[pk_offsetBytesIX], &offset) != JIM_OK) {
            Jim_SetResultString(itp, "Expected offset integer but got other data.", -1);
            return JIM_ERR;
        }
        if (offset < 0) {
            Jim_SetResultString(itp, "Offset cannot be negative.", -1);
            return JIM_ERR;
        }    
    }
    int requiredLen = offset + sizeBytes;
    
    Jim_Obj* v = Jim_GetVariable(itp, objv[pk_packVarNameIX], JIM_NONE);
    if (v == NULL) {
        if (createBufferVarNative(itp, objv[pk_packVarNameIX], sizeBytes, NULL, &v) != JIM_OK) return JIM_ERR;
    } else {
        if (v->length < requiredLen) {
            Jim_SetResultString(itp, "Inadequate buffer in variable.", -1);
            return JIM_ERR;
        }    
    }
    *bufP = (void*)((u8*)v->bytes + offset);
    
    if (objc > pk_nextOffsetVarNameIX) {
        // memorize the offset for the next operation after this one.
        if (Jim_SetVariable(itp, objv[pk_nextOffsetVarNameIX], Jim_NewIntObj(itp, requiredLen)) != JIM_OK) {
            Jim_SetResultString(itp, "Failed to memorize next offset.", -1);
            return JIM_ERR;
        }
    }
    
    return JIM_OK;
}

int packerSetup_byVal_asInt(Jim_Interp* itp, int objc, Jim_Obj * const objv[], jim_wide* dataP) {
    *dataP = 0;
    if (Jim_GetWide(itp, objv[pk_unpackedDataIX], dataP) != JIM_OK) {
        Jim_SetResultString(itp, "Expected data value integer but got other data.", -1);
        return JIM_ERR;
    }    
    return JIM_OK;
}

int packerSetup_byVal_asDouble(Jim_Interp* itp, int objc, Jim_Obj * const objv[], double* dataP) {
    *dataP = 0;
    if (Jim_GetDouble(itp, objv[pk_unpackedDataIX], dataP) != JIM_OK) {
        Jim_SetResultString(itp, "Expected data value double-precision float but got other data.", -1);
        return JIM_ERR;
    }    
    return JIM_OK;
}

int pack_8_byVal_asInt(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    u8* buf = NULL;
    if (packerSetup_byVal(itp, objc, objv, sizeof(u8), (void**)&buf) != JIM_OK) return JIM_ERR;
    jim_wide data; 
    if (packerSetup_byVal_asInt(itp, objc, objv, &data) != JIM_OK) return JIM_ERR;
    *buf = (u8)data;
    return JIM_OK;
}

int pack_16_byVal_asInt(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    u16* buf = NULL;
    if (packerSetup_byVal(itp, objc, objv, sizeof(u16), (void**)&buf) != JIM_OK) return JIM_ERR;
    jim_wide data; 
    if (packerSetup_byVal_asInt(itp, objc, objv, &data) != JIM_OK) return JIM_ERR;
    *buf = (u16)data;
    return JIM_OK;
}

int pack_32_byVal_asInt(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    u32* buf = NULL;
    if (packerSetup_byVal(itp, objc, objv, sizeof(u32), (void**)&buf) != JIM_OK) return JIM_ERR;
    jim_wide data; 
    if (packerSetup_byVal_asInt(itp, objc, objv, &data) != JIM_OK) return JIM_ERR;
    *buf = (u32)data;
    return JIM_OK;
}

int pack_64_byVal_asInt(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    u64* buf = NULL;
    if (packerSetup_byVal(itp, objc, objv, sizeof(u64), (void**)&buf) != JIM_OK) return JIM_ERR;
    jim_wide data; 
    if (packerSetup_byVal_asInt(itp, objc, objv, &data) != JIM_OK) return JIM_ERR;
    *buf = (u64)data;
    return JIM_OK;
}

int pack_double_byVal_asDouble(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    double* buf = NULL;
    if (packerSetup_byVal(itp, objc, objv, sizeof(double), (void**)&buf) != JIM_OK) return JIM_ERR;
    double data; 
    if (packerSetup_byVal_asDouble(itp, objc, objv, &data) != JIM_OK) return JIM_ERR;
    *buf = (double)data;
    return JIM_OK;
}

int pack_float_byVal_asDouble(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    float* buf = NULL;
    if (packerSetup_byVal(itp, objc, objv, sizeof(float), (void**)&buf) != JIM_OK) return JIM_ERR;
    double data; 
    if (packerSetup_byVal_asDouble(itp, objc, objv, &data) != JIM_OK) return JIM_ERR;
    *buf = (float)data;
    return JIM_OK;
}

int pack_longDouble_byVal_asDouble(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    long double* buf = NULL;
    if (packerSetup_byVal(itp, objc, objv, sizeof(long double), (void**)&buf) != JIM_OK) return JIM_ERR;
    double data; 
    if (packerSetup_byVal_asDouble(itp, objc, objv, &data) != JIM_OK) return JIM_ERR;
    *buf = (long double)data;
    return JIM_OK;
}

int pack_char_byVal_asString(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    if (objc > pk_argCount || objc < pk_offsetBytesIX) {
        Jim_SetResultString(itp, "Wrong # args.", -1);
        return JIM_ERR;
    }    
    int len = 0;
    const char* src = Jim_GetString(objv[pk_unpackedDataIX], &len);
    len++; //todo: is this needed?  see if it includes the term null prior to increment.
    char* buf = NULL;
    if (packerSetup_byVal(itp, objc, objv, len, (void**)&buf) != JIM_OK) return JIM_ERR;
    memcpy(buf, src, len);
    buf[len] = 0; // guarantee safety for future string operations.  this should already be a null.
    return JIM_OK;
}

int unpackerSetup_byVal(Jim_Interp* itp, int objc, Jim_Obj * const objv[], 
    int sizeBytes, void** bufP) {
        
    enum { 
        cmdIX = 0,
        packedValueIX,
        offsetBytesIX,
        nextOffsetVarNameIX,
        argCount
    };
    
    if (objc > argCount || objc < offsetBytesIX) {
        Jim_SetResultString(itp, "Wrong # args.", -1);
        return JIM_ERR;
    }
    
    jim_wide offset = 0;
    if (objc > offsetBytesIX) {
        if (Jim_GetWide(itp, objv[offsetBytesIX], &offset) != JIM_OK) {
            Jim_SetResultString(itp, "Expected offset integer but got other data.", -1);
            return JIM_ERR;
        }
        if (offset < 0) {
            Jim_SetResultString(itp, "Offset cannot be negative.", -1);
            return JIM_ERR;
        }    
    }
    int requiredLen = offset + sizeBytes;
    
    Jim_Obj* v = objv[packedValueIX];
    if (v->length < requiredLen) {
        Jim_SetResultString(itp, "Packed value is too short.", -1);
        return JIM_ERR;
    }    

    if (objc > nextOffsetVarNameIX) {
        // memorize the offset for the next operation after this one.
        if (Jim_SetVariable(itp, objv[nextOffsetVarNameIX], Jim_NewIntObj(itp, requiredLen)) != JIM_OK) {
            Jim_SetResultString(itp, "Failed to memorize next offset.", -1);
            return JIM_ERR;
        }
    }

    *bufP = (void*)((u8*)v->bytes + offset);
    return JIM_OK;
}

int unpack_8_byVal_asInt(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    u8* buf = NULL;
    if (unpackerSetup_byVal(itp, objc, objv, sizeof(u8), (void**)&buf) != JIM_OK) return JIM_ERR;
    Jim_SetResultInt(itp, (jim_wide) *buf);
    return JIM_OK;
}

int unpack_16_byVal_asInt(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    u16* buf = NULL;
    if (unpackerSetup_byVal(itp, objc, objv, sizeof(u16), (void**)&buf) != JIM_OK) return JIM_ERR;
    Jim_SetResultInt(itp, (jim_wide) *buf);
    return JIM_OK;
}

int unpack_32_byVal_asInt(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    u32* buf = NULL;
    if (unpackerSetup_byVal(itp, objc, objv, sizeof(u32), (void**)&buf) != JIM_OK) return JIM_ERR;
    Jim_SetResultInt(itp, (jim_wide) *buf);
    return JIM_OK;
}

int unpack_64_byVal_asInt(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    u64* buf = NULL;
    if (unpackerSetup_byVal(itp, objc, objv, sizeof(u64), (void**)&buf) != JIM_OK) return JIM_ERR;
    Jim_SetResultInt(itp, (jim_wide) *buf);
    return JIM_OK;
}

int unpack_float_byVal_asDouble(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    float* buf = NULL;
    if (unpackerSetup_byVal(itp, objc, objv, sizeof(float), (void**)&buf) != JIM_OK) return JIM_ERR;
    Jim_SetResult(itp, Jim_NewDoubleObj(itp, (double)*buf));
    return JIM_OK;
}

int unpack_double_byVal_asDouble(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    double* buf = NULL;
    if (unpackerSetup_byVal(itp, objc, objv, sizeof(double), (void**)&buf) != JIM_OK) return JIM_ERR;
    Jim_SetResult(itp, Jim_NewDoubleObj(itp, (double)*buf));
    return JIM_OK;
}

int unpack_longDouble_byVal_asDouble(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    long double* buf = NULL;
    if (unpackerSetup_byVal(itp, objc, objv, sizeof(long double), (void**)&buf) != JIM_OK) return JIM_ERR;
    Jim_SetResult(itp, Jim_NewDoubleObj(itp, (double)*buf));
    return JIM_OK;
}

//todo: add a test for this.
int unpack_char_byVal_asString(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    char* buf = NULL;
    if (unpackerSetup_byVal(itp, objc, objv, 0, (void**)&buf) != JIM_OK) return JIM_ERR;
    //todo: limit to a certain max length here for safety.  have the lib's binding script fetch that from metadata and pass it to here.
    Jim_SetResultString(itp, (char*) buf, -1);
    return JIM_OK;
}

int Jim_dlrNativeInit(Jim_Interp* itp) {
    //ivkClientT* client = client_alloc(itp);

//todo: Jim_PackageRequire a specific Jim version.

    if (Jim_PackageProvide(itp, "dlrNative", DLR_VERSION_STRING, 0) != JIM_OK) {
        return JIM_ERR;
    }
    
    Jim_CreateCommand(itp, "dlr::native::loadLib", loadLib, NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::prepMetaBlob", prepMetaBlob, NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::callToNative", callToNative, NULL, NULL);
    
    Jim_CreateCommand(itp, "dlr::native::prepStructType", prepStructType, NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::fnAddr", fnAddr, NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::addrOf", addrOf, NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::createBufferVar", createBufferVar, NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::allocHeap", allocHeap, NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::freeHeap", freeHeap, NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::sizeOfTypes", sizeOfTypes, NULL, NULL);
    
    Jim_CreateCommand(itp, "dlr::native::pack-8-byVal-asInt",  pack_8_byVal_asInt,  NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::pack-16-byVal-asInt", pack_16_byVal_asInt, NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::pack-32-byVal-asInt", pack_32_byVal_asInt, NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::pack-64-byVal-asInt", pack_64_byVal_asInt, NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::pack-float-byVal-asDouble", pack_float_byVal_asDouble, NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::pack-double-byVal-asDouble", pack_double_byVal_asDouble, NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::pack-longDouble-byVal-asDouble", pack_longDouble_byVal_asDouble, NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::pack-char-byVal-asString", pack_char_byVal_asString, NULL, NULL);

    Jim_CreateCommand(itp, "dlr::native::unpack-8-byVal-asInt",  unpack_8_byVal_asInt,  NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::unpack-16-byVal-asInt", unpack_16_byVal_asInt, NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::unpack-32-byVal-asInt", unpack_32_byVal_asInt, NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::unpack-64-byVal-asInt", unpack_64_byVal_asInt, NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::unpack-float-byVal-asDouble", unpack_float_byVal_asDouble, NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::unpack-double-byVal-asDouble", unpack_double_byVal_asDouble, NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::unpack-longDouble-byVal-asDouble", unpack_longDouble_byVal_asDouble, NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::unpack-char-byVal-asString", unpack_char_byVal_asString, NULL, NULL);

    return JIM_OK;
}

