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

#include <jim.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <dlfcn.h>
#include <ffi.h>

typedef uint8_t u8;
typedef uint32_t u32;
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

int sizeOfInt(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    Jim_SetResultInt(itp, (jim_wide)sizeof(int));
    return JIM_OK;
}

int sizeOfPtr(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    Jim_SetResultInt(itp, (jim_wide)sizeof(void*));
    return JIM_OK;
}

// returns (to the script) an integer which is the memory address of the 
// content bytes of the given variable name.
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

// create and set a script variable having the given name, suitable for holding a binary
// structure of the given length.  
// if newBufP is not null, sets *newBufP to point to the structure.
// if newObjP is not null, sets *newObjP to point to the new Jim_Obj.
int createBufferVar(Jim_Interp* itp, Jim_Obj* varName, int len, void** newBufP, Jim_Obj** newObjP) {
    char* buf = Jim_Alloc(len + 1); // extra 1 for null terminator is not needed for dlr, but may be needed by any further script operations on the object.
    if (buf == NULL) {
        Jim_SetResultString(itp, "Out of memory while allocating buffer.", -1);
        return JIM_ERR;
    }  
    buf[len] = 0; // last-ditch safety for any further script operations on the object.
    Jim_Obj* valueObj = Jim_NewStringObjNoAlloc(itp, buf, len);
    if (Jim_SetVariable(itp, varName, valueObj) != JIM_OK) {
        Jim_SetResultString(itp, "Failed to set variable for buffer.", -1);
        return JIM_ERR;
    }    
    if (newBufP) *newBufP = (void*)buf;
    if (newObjP) *newObjP = valueObj;
    
    return JIM_OK;
}

int objToTypeP(Jim_Interp* itp, Jim_Obj *v, ffi_type** typ) {
    jim_wide code = 0;
    if (Jim_GetWide(itp, v, &code) != JIM_OK || code < 0 || code > FFI_TYPE_FINAL || ffiTypes[code] == NULL) {
        Jim_SetResultString(itp, "Expected type ID code but got other data.", -1);
        return JIM_ERR;
    }
    *typ = ffiTypes[code];
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
        returnTypeCodeIX,
        nativeParmsListIX,
        parmTypeCodeListIX,
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
    if (createBufferVar(itp, objv[metaBlobVarNameIX], blobLen, (void**)&meta, NULL) != JIM_OK) return JIM_ERR;
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
    if (objToTypeP(itp, objv[returnTypeCodeIX], &rtype) != JIM_OK) return JIM_ERR;

    // gather parm metadata.
    meta->nativeParmsList = objv[nativeParmsListIX];
    Jim_Obj* typesList = objv[parmTypeCodeListIX];
    if (nArgs != Jim_ListLength(itp, typesList)) {
        Jim_SetResultString(itp, "List lengths don't match.", -1);
        return JIM_ERR;
    }
    ffi_type** t = &meta->atypes; // now t can be treated as the types array at the end of the struct.
    for (int n = 0; n < nArgs; n++) {
        Jim_Obj* typeCode = Jim_ListGetIndex(itp, objv[parmTypeCodeListIX], n);
        if (objToTypeP(itp, typeCode, &t[n]) != JIM_OK) return JIM_ERR;
    }  
    
    // prep CIF.
    ffi_status err = ffi_prep_cif(&meta->cif, FFI_DEFAULT_ABI, (unsigned int)nArgs, rtype, &meta->atypes);
    if (err != FFI_OK) {
        Jim_SetResultString(itp, "Failed to prep FFI CIF structure for call.", -1);
        return JIM_ERR;
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
    // those vars are the buffers for the packed native binary content during this native call.
    // their content has probably moved to a new address since the last call,
    // and their Jim_Obj's replaced with new ones,
    // because the script assigned them new values since then.
    unsigned nArgs = meta->cif.nargs;
    void* argPtrs[nArgs];
    for (unsigned n = 0; n < nArgs; n++) {
        // using internalRep here for a little more speed.
        Jim_Obj* v = Jim_GetGlobalVariable(itp, 
            meta->nativeParmsList->internalRep.listValue.ele[n], JIM_NONE);
        if (v == NULL) {
            Jim_SetResultString(itp, "Native argument variable not found.", -1);
            return JIM_ERR;
        }
        // const is discarded here.  that is required, to be able to pass a large value
        // either in or out of a native function, while passing by pointer.
        argPtrs[n] = (void*)Jim_GetString(v, NULL); 
    }  

    // arrange space for return value.
    void* resultBuf = NULL;
    if (createBufferVar(itp, meta->returnVar, (int)meta->cif.rtype->size, &resultBuf, NULL) != JIM_OK) return JIM_ERR;
    
    // execute call.
    ffi_call(&meta->cif, meta->fn, resultBuf, argPtrs);
    
    return JIM_OK;
}

int Jim_dlrNativeInit(Jim_Interp* itp) {
    //ivkClientT* client = client_alloc(itp);

//todo: Jim_PackageRequire a specific Jim version.

    if (Jim_PackageProvide(itp, "dlrNative", "0.1", 0) != JIM_OK) {
        return JIM_ERR;
    }
    
    Jim_CreateCommand(itp, "dlr::native::loadLib", loadLib, NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::prepMetaBlob", prepMetaBlob, NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::callToNative", callToNative, NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::fnAddr", fnAddr, NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::sizeOfInt", sizeOfInt, NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::sizeOfPtr", sizeOfPtr, NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::addrOf", addrOf, NULL, NULL);
    
    return JIM_OK;
}

