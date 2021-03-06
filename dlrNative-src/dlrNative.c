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
#include <dlfcn.h>

#include <jim.h>

#include "dlrNative.h"

#ifdef BUILD_GIZMO
    #include <gtk/gtk.h>
    #include <girepository.h>
#endif
/*todo: remove from dlrNative the special support for GNOME.  turns out it's not needed.
 BUT first make sure we can do without it when passing unions by value.
 GNOME does that in at least 6 places, some are in Widget class!
 libffi has serious trouble with that:
 https://github.com/libffi/libffi/issues/33
 https://stackoverflow.com/questions/40354500/how-do-i-create-an-ffi-type-that-represents-a-union
 issue is tagged to fix in libffi 4.0 but that's years away from 2020.
*/

#define DLR_VERSION_STRING "0.2"

//todo: periodically re-run all tests, and valgrind, with full compiler optimization on dlr and on the interp.  code may behave differently.

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

typedef enum {
    DF_DIR_IN = (1 << 0),
    DF_DIR_OUT = (1 << 1),
    DF_DIR_INOUT = DF_DIR_IN | DF_DIR_OUT,
    DF_ARRAY = (1 << 3)
} dlrFlagsT;

typedef struct {
    // this signature serves 2 purposes:
    // it allows C code to verify the metablob is intact, meaning the script hasn't stepped on it.
    // and it provides a sane appearance if script prints the metablob.
    char signature[5];
    ffi_cif cif;
    #ifdef BUILD_GIZMO
        GIFunctionInfo* giInfo;
        int nInArgs;
        int nOutArgs;
        dlrFlagsT* aFlags; // points directly beyond the atypes array.
    #endif
    ffiFnP fn;
    size_t returnSizePadded;
    Jim_Obj* nativeParmsList;
    ffi_type* atypes; // placeholder for first element of the array of type pointers located directly at the end of the structure.
} metaBlobT;
static const char METABLOB_SIGNATURE[] = "meta";

#define  DLR_NULL_PTR_FLAG  "_#_nullPtrFlag_#_"
#define  DLR_NULL_PTR_FLAG_STRLEN  (17)
#define  setResultNullPtrFlag(itp)  Jim_SetResultString(itp, DLR_NULL_PTR_FLAG, DLR_NULL_PTR_FLAG_STRLEN);

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
#ifdef BUILD_GIZMO
        Jim_NewStringObj(itp, "GIArgument", -1),    Jim_NewIntObj(itp, (jim_wide)sizeof(GIArgument)),
#endif
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

    void* bufP = NULL;
    if (createBufferVarNative(itp, objv[varNameIX], (int)len, &bufP, NULL) != JIM_OK)
        return JIM_ERR;

    // pass new buffer's address back to script as result of this command.
    Jim_SetResultInt(itp, (jim_wide)bufP);
    return JIM_OK;
}

// equivalent to [createBufferVar] followed by memcpy() to fill it.
// this does involve making a copy, so it's OK (and often best) for the script to
// free the pointer immediately after this.
int copyToBufferVar(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    enum {
        cmdIX = 0,
        varNameIX,
        lenIX,
        sourcePointerIntValueIX,
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
    if (len < 1) {
        Jim_SetResultString(itp, "Size must be at least 1.", -1);
        return JIM_ERR;
    }

    jim_wide srcW;
    if (Jim_GetWide(itp, objv[sourcePointerIntValueIX], &srcW) != JIM_OK) {
        Jim_SetResultString(itp, "Expected source pointer integer but got other data.", -1);
        return JIM_ERR;
    }
    void* srcP = (void*)srcW;
    if (srcP == NULL) {
        Jim_SetResultString(itp, "Source pointer must not be null.", -1);
        return JIM_ERR;
    }

    void* bufP = NULL;
    if (createBufferVarNative(itp, objv[varNameIX], (int)len, &bufP, NULL) != JIM_OK)
        return JIM_ERR;
    memcpy(bufP, srcP, (size_t)len);

    // pass new buffer's address back to script as result of this command.
    Jim_SetResultInt(itp, (jim_wide)bufP);
    return JIM_OK;
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
        returnTypeVarNameIX,
        nativeParmsListIX,
        parmTypeVarNameListIX,
        parmFlagsListIX,
        argCount
    };

    if (objc != argCount) {
        Jim_SetResultString(itp, "Wrong # args.", -1);
        return JIM_ERR;
    }

    Jim_Obj* flagsList = objv[parmFlagsListIX];
    int isGIcall = Jim_ListLength(itp, flagsList) > 0;

    // create buffer variable for metablob.  first we must determine its final size.
    int nArgs = Jim_ListLength(itp, objv[nativeParmsListIX]);
    // in this calculation there's sizeof(ffi_type*) bytes of waste.  don't care.
    int blobLen = sizeof(metaBlobT) + nArgs * sizeof(ffi_type*) + nArgs * sizeof(dlrFlagsT);
    metaBlobT* meta;
    if (createBufferVarNative(itp, objv[metaBlobVarNameIX], blobLen, (void**)&meta, NULL) != JIM_OK) return JIM_ERR;
    memset(meta, 0, sizeof(metaBlobT)); // initialize to zeros because this structure now has optional parts e.g. for gizmo.
    *(u32*)meta->signature = *(u32*)METABLOB_SIGNATURE;
    meta->signature[4] = 0; // string safety.

    // memorize function pointer.
    jim_wide fnP = 0;
    if (Jim_GetWide(itp, objv[fnPIX], &fnP) != JIM_OK) {
        Jim_SetResultString(itp, "Expected function pointer but got other data.", -1);
        return JIM_ERR;
    }
    if (fnP == 0) {
        Jim_SetResultString(itp, "Null function pointer.", -1);
        return JIM_ERR;
    }

    // gather return-value metadata.
    ffi_type* rtype = NULL;
    if (varToTypeP(itp, objv[returnTypeVarNameIX], &rtype) != JIM_OK) return JIM_ERR;

    // gather parm metadata.
    meta->nativeParmsList = objv[nativeParmsListIX];
    Jim_Obj* typesList = objv[parmTypeVarNameListIX];
    if (nArgs != Jim_ListLength(itp, typesList)) {
        Jim_SetResultString(itp, "List lengths don't match.", -1);
        return JIM_ERR;
    }
    if (isGIcall && nArgs != Jim_ListLength(itp, flagsList)) {
        Jim_SetResultString(itp, "List lengths don't match.", -1);
        return JIM_ERR;
    }
    ffi_type** t = &meta->atypes; // now t can be treated as the types array at the end of the struct.
    for (int n = 0; n < nArgs; n++) {
        Jim_Obj* typeVar = Jim_ListGetIndex(itp, typesList, n);
        if (varToTypeP(itp, typeVar, &t[n]) != JIM_OK) return JIM_ERR;
    }
#ifdef BUILD_GIZMO
    if (isGIcall) {
        meta->giInfo = (GIFunctionInfo*)fnP;
        meta->aFlags = (dlrFlagsT*)((u8*)meta + sizeof(metaBlobT) + nArgs * sizeof(ffi_type*)); // aflags array lies directly beyond the atypes array.
        meta->nInArgs = 0;
        meta->nOutArgs = 0;
        for (int n = 0; n < nArgs; n++) {
            jim_wide flags;
            if (Jim_GetWide(itp, Jim_ListGetIndex(itp, flagsList, n), &flags) != JIM_OK) {
                Jim_SetResultString(itp, "Expected parm flags integer but got other data.", -1);
                return JIM_ERR;
            }
            meta->aFlags[n] = (dlrFlagsT)flags;
            if (flags & DF_DIR_IN) meta->nInArgs++;
            if (flags & DF_DIR_OUT) meta->nOutArgs++;
        }
    } else {
        meta->fn = (ffiFnP)fnP;
    }
//todo: unref when this metablob destroyed.
//    g_base_info_unref (base_info);
// and the repo as well?
#else
    meta->fn = (ffiFnP)fnP;
#endif

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
        // this must use Jim_GetVariable(), not Jim_GetGlobalVariable(), to support asNative.
        Jim_Obj* v = Jim_GetVariable(itp, varName, JIM_NONE);
        if (v == NULL) {
            Jim_SetResultFormatted(itp, "Native argument variable not found: %#s", varName);
            return JIM_ERR;
        }
        // const is discarded here.  that is required, to be able to pass an argument by pointer
        // either in or out of a native function.  that is required for large data.
        argPtrs[n] = (void*)Jim_GetString(v, NULL);
        // safety check.
        // we'll let it slide here if the script allocated just enough bytes for the value,
        // and no extra byte for a null terminator.  not all parms are strings.
        if (argPtrs[n] == NULL || v->length < meta->cif.arg_types[n]->size) {
            Jim_SetResultFormatted(itp, "Inadequate buffer in argument variable: %#s", varName);
            return JIM_ERR;
        }
    }

    /* how to trace certain native calls.
    if (meta->fn == (ffiFnP)g_irepository_require) {
        printf("require     %p '%s' '%s'\n", *(void**)argPtrs[0], *(char**)argPtrs[1], *(char**)argPtrs[2]);
    }
    if (meta->fn == (ffiFnP)g_irepository_get_n_infos) {
        printf("get_n_infos %p '%s'\n", *(void**)argPtrs[0], *(char**)argPtrs[1]);
    }
    */

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

#ifdef BUILD_GIZMO
int giCallToNative(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
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
    GIArgument inArgs[meta->nInArgs];
    unsigned inArgPos = 0;
    GIArgument outArgs[meta->nOutArgs];
    unsigned outArgPos = 0;
    for (unsigned n = 0; n < nArgs; n++) {
        // look up the designated variable, in a global context.
        // using internalRep of the parms list here for a little more speed.
        Jim_Obj* varName = meta->nativeParmsList->internalRep.listValue.ele[n];
        Jim_Obj* v = Jim_GetGlobalVariable(itp, varName, JIM_NONE);
        if (v == NULL) {
            Jim_SetResultFormatted(itp, "Native argument variable not found: %#s", varName);
            return JIM_ERR;
        }
        void* vBytes = (void*)Jim_GetString(v, NULL); // ensure string rep exists.
        if (meta->aFlags[n] & DF_DIR_IN) {
            memcpy(&inArgs[inArgPos], vBytes, MIN(sizeof(GIArgument), v->length));
            inArgPos++;
        }
        //todo: check docs.  see if outArgs should be value copied like inArgs.
        if (meta->aFlags[n] & DF_DIR_OUT) {
            memcpy(&outArgs[outArgPos], vBytes, MIN(sizeof(GIArgument), v->length));
            outArgPos++;
        }
        //todo: safety check
        //// safety check.
        //// we'll let it slide here if the script allocated just enough bytes for the value,
        //// and no extra byte for a null terminator.  not all parms are strings.
        //if (argPtrs[n] == NULL || v->length < meta->cif.arg_types[n]->size) {
            //Jim_SetResultFormatted(itp, "Inadequate buffer in argument variable: %#s", varName);
            //return JIM_ERR;
        //}
    }

    GIArgument retval;
    GError *error = NULL;
    if (!g_function_info_invoke (meta->giInfo,
                               (const GIArgument *) &inArgs,
                               meta->nInArgs,
                               (const GIArgument *) &outArgs,
                               meta->nOutArgs,
                               &retval,
                               &error))
    {
        g_error ("ERROR: %s\n", error->message);
        return JIM_ERR;
    }
    //todo: retval placement.
    //todo: error handling.

    return JIM_OK;
}

// g_free has to be made available here, for GI calls' memory management to use.
int giFreeHeap(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    enum {
        cmdIX = 0,
        ptrIntValueIX,
        argCount
    };

    jim_wide ptr;
    if (Jim_GetWide(itp, objv[ptrIntValueIX], &ptr) != JIM_OK) {
        Jim_SetResultString(itp, "Expected pointer integer but got other data.", -1);
        return JIM_ERR;
    }

    g_free((gpointer)ptr);
    return JIM_OK;
}

#endif


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
    if (v == NULL || v->bytes == NULL || v->length < requiredLen) {
        if (createBufferVarNative(itp, objv[pk_packVarNameIX], sizeBytes, NULL, &v) != JIM_OK) return JIM_ERR;
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

int u8_pack_byVal_asInt(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    u8* buf = NULL;
    if (packerSetup_byVal(itp, objc, objv, sizeof(u8), (void**)&buf) != JIM_OK) return JIM_ERR;
    jim_wide data;
    if (packerSetup_byVal_asInt(itp, objc, objv, &data) != JIM_OK) return JIM_ERR;
    *buf = (u8)data;
    return JIM_OK;
}

int u16_pack_byVal_asInt(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    u16* buf = NULL;
    if (packerSetup_byVal(itp, objc, objv, sizeof(u16), (void**)&buf) != JIM_OK) return JIM_ERR;
    jim_wide data;
    if (packerSetup_byVal_asInt(itp, objc, objv, &data) != JIM_OK) return JIM_ERR;
    *buf = (u16)data;
    return JIM_OK;
}

int u32_pack_byVal_asInt(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    u32* buf = NULL;
    if (packerSetup_byVal(itp, objc, objv, sizeof(u32), (void**)&buf) != JIM_OK) return JIM_ERR;
    jim_wide data;
    if (packerSetup_byVal_asInt(itp, objc, objv, &data) != JIM_OK) return JIM_ERR;
    *buf = (u32)data;
    return JIM_OK;
}

int u64_pack_byVal_asInt(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    u64* buf = NULL;
    if (packerSetup_byVal(itp, objc, objv, sizeof(u64), (void**)&buf) != JIM_OK) return JIM_ERR;
    jim_wide data;
    if (packerSetup_byVal_asInt(itp, objc, objv, &data) != JIM_OK) return JIM_ERR;
    *buf = (u64)data;
    return JIM_OK;
}

int i8_pack_byVal_asInt(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    i8* buf = NULL;
    if (packerSetup_byVal(itp, objc, objv, sizeof(i8), (void**)&buf) != JIM_OK) return JIM_ERR;
    jim_wide data;
    if (packerSetup_byVal_asInt(itp, objc, objv, &data) != JIM_OK) return JIM_ERR;
    *buf = (i8)data;
    return JIM_OK;
}

int i16_pack_byVal_asInt(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    i16* buf = NULL;
    if (packerSetup_byVal(itp, objc, objv, sizeof(i16), (void**)&buf) != JIM_OK) return JIM_ERR;
    jim_wide data;
    if (packerSetup_byVal_asInt(itp, objc, objv, &data) != JIM_OK) return JIM_ERR;
    *buf = (i16)data;
    return JIM_OK;
}

int i32_pack_byVal_asInt(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    i32* buf = NULL;
    if (packerSetup_byVal(itp, objc, objv, sizeof(i32), (void**)&buf) != JIM_OK) return JIM_ERR;
    jim_wide data;
    if (packerSetup_byVal_asInt(itp, objc, objv, &data) != JIM_OK) return JIM_ERR;
    *buf = (i32)data;
    return JIM_OK;
}

int i64_pack_byVal_asInt(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    i64* buf = NULL;
    if (packerSetup_byVal(itp, objc, objv, sizeof(i64), (void**)&buf) != JIM_OK) return JIM_ERR;
    jim_wide data;
    if (packerSetup_byVal_asInt(itp, objc, objv, &data) != JIM_OK) return JIM_ERR;
    *buf = (i64)data;
    return JIM_OK;
}

int double_pack_byVal_asDouble(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    double* buf = NULL;
    if (packerSetup_byVal(itp, objc, objv, sizeof(double), (void**)&buf) != JIM_OK) return JIM_ERR;
    double data;
    if (packerSetup_byVal_asDouble(itp, objc, objv, &data) != JIM_OK) return JIM_ERR;
    *buf = (double)data;
    return JIM_OK;
}

int float_pack_byVal_asDouble(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    float* buf = NULL;
    if (packerSetup_byVal(itp, objc, objv, sizeof(float), (void**)&buf) != JIM_OK) return JIM_ERR;
    double data;
    if (packerSetup_byVal_asDouble(itp, objc, objv, &data) != JIM_OK) return JIM_ERR;
    *buf = (float)data;
    return JIM_OK;
}

int longDouble_pack_byVal_asDouble(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    long double* buf = NULL;
    if (packerSetup_byVal(itp, objc, objv, sizeof(long double), (void**)&buf) != JIM_OK) return JIM_ERR;
    double data;
    if (packerSetup_byVal_asDouble(itp, objc, objv, &data) != JIM_OK) return JIM_ERR;
    *buf = (long double)data;
    return JIM_OK;
}

int ascii_pack_byVal_asString(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
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

int pack_null(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    enum {
        cmdIX = 0,
        packVarNameIX,
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
    const int sizeBytes = sizeof(void*);
    int requiredLen = offset + sizeBytes;

    Jim_Obj* v = Jim_GetVariable(itp, objv[packVarNameIX], JIM_NONE);
    if (v == NULL || v->bytes == NULL || v->length < requiredLen) {
        if (createBufferVarNative(itp, objv[packVarNameIX], sizeBytes, NULL, &v) != JIM_OK) return JIM_ERR;
    }
    void** bufP = (void**)((u8*)v->bytes + offset);

    if (objc > nextOffsetVarNameIX) {
        // memorize the offset for the next operation after this one.
        if (Jim_SetVariable(itp, objv[nextOffsetVarNameIX], Jim_NewIntObj(itp, requiredLen)) != JIM_OK) {
            Jim_SetResultString(itp, "Failed to memorize next offset.", -1);
            return JIM_ERR;
        }
    }

    *bufP = NULL;
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
    if (v->bytes == NULL || v->length < requiredLen) {
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

int unpackerSetup_scriptPtr(Jim_Interp* itp, int objc, Jim_Obj * const objv[],
    int sizeBytes, void** bufP) {

    enum {
        cmdIX = 0,
        pointerIntValueIX,
        argCount
    };

    if (objc != argCount) {
        Jim_SetResultString(itp, "Wrong # args.", -1);
        return JIM_ERR;
    }

    jim_wide p = 0;
    if (Jim_GetWide(itp, objv[pointerIntValueIX], &p) != JIM_OK) {
        Jim_SetResultString(itp, "Expected pointer integer but got other data.", -1);
        return JIM_ERR;
    }

    *bufP = (void*)p;
    return JIM_OK;
}

int u8_unpack_byVal_asInt(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    u8* buf = NULL;
    if (unpackerSetup_byVal(itp, objc, objv, sizeof(u8), (void**)&buf) != JIM_OK) return JIM_ERR;
    Jim_SetResultInt(itp, (jim_wide) *buf);
    return JIM_OK;
}

int u16_unpack_byVal_asInt(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    u16* buf = NULL;
    if (unpackerSetup_byVal(itp, objc, objv, sizeof(u16), (void**)&buf) != JIM_OK) return JIM_ERR;
    Jim_SetResultInt(itp, (jim_wide) *buf);
    return JIM_OK;
}

int u32_unpack_byVal_asInt(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    u32* buf = NULL;
    if (unpackerSetup_byVal(itp, objc, objv, sizeof(u32), (void**)&buf) != JIM_OK) return JIM_ERR;
    Jim_SetResultInt(itp, (jim_wide) *buf);
    return JIM_OK;
}

int u64_unpack_byVal_asInt(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    u64* buf = NULL;
    if (unpackerSetup_byVal(itp, objc, objv, sizeof(u64), (void**)&buf) != JIM_OK) return JIM_ERR;
    Jim_SetResultInt(itp, (jim_wide) *buf);
    return JIM_OK;
}

int i8_unpack_byVal_asInt(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    i8* buf = NULL;
    if (unpackerSetup_byVal(itp, objc, objv, sizeof(i8), (void**)&buf) != JIM_OK) return JIM_ERR;
    Jim_SetResultInt(itp, (jim_wide) *buf);
    return JIM_OK;
}

int i16_unpack_byVal_asInt(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    i16* buf = NULL;
    if (unpackerSetup_byVal(itp, objc, objv, sizeof(i16), (void**)&buf) != JIM_OK) return JIM_ERR;
    Jim_SetResultInt(itp, (jim_wide) *buf);
    return JIM_OK;
}

int i32_unpack_byVal_asInt(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    i32* buf = NULL;
    if (unpackerSetup_byVal(itp, objc, objv, sizeof(i32), (void**)&buf) != JIM_OK) return JIM_ERR;
    Jim_SetResultInt(itp, (jim_wide) *buf);
    return JIM_OK;
}

int i64_unpack_byVal_asInt(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    i64* buf = NULL;
    if (unpackerSetup_byVal(itp, objc, objv, sizeof(i64), (void**)&buf) != JIM_OK) return JIM_ERR;
    Jim_SetResultInt(itp, (jim_wide) *buf);
    return JIM_OK;
}

int float_unpack_byVal_asDouble(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    float* buf = NULL;
    if (unpackerSetup_byVal(itp, objc, objv, sizeof(float), (void**)&buf) != JIM_OK) return JIM_ERR;
    Jim_SetResult(itp, Jim_NewDoubleObj(itp, (double)*buf));
    return JIM_OK;
}

int double_unpack_byVal_asDouble(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    double* buf = NULL;
    if (unpackerSetup_byVal(itp, objc, objv, sizeof(double), (void**)&buf) != JIM_OK) return JIM_ERR;
    Jim_SetResult(itp, Jim_NewDoubleObj(itp, (double)*buf));
    return JIM_OK;
}

int longDouble_unpack_byVal_asDouble(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    long double* buf = NULL;
    if (unpackerSetup_byVal(itp, objc, objv, sizeof(long double), (void**)&buf) != JIM_OK) return JIM_ERR;
    Jim_SetResult(itp, Jim_NewDoubleObj(itp, (double)*buf));
    return JIM_OK;
}

int ascii_unpack_byVal_asString(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    char* buf = NULL;
    if (unpackerSetup_byVal(itp, objc, objv, 0, (void**)&buf) != JIM_OK) return JIM_ERR;
    //todo: limit to a certain max length here for safety.  have the lib's binding script fetch that from metadata and pass it to here.
    Jim_SetResultString(itp, buf, -1);
    return JIM_OK;
}

// this does involve making a copy, so it's OK (and often best) for the script to
// free the pointer immediately after this.
int ascii_unpack_scriptPtr_asString(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    char* buf = NULL;
    if (unpackerSetup_scriptPtr(itp, objc, objv, 0, (void**)&buf) != JIM_OK) return JIM_ERR;
    //todo: limit to a certain max length here for safety.  have the lib's binding script fetch that from metadata and pass it to here.
    if (buf == NULL) {
        setResultNullPtrFlag(itp);
    } else {
        Jim_SetResultString(itp, buf, -1);
    }
    return JIM_OK;
}

// this function's name is based on the library's actual filename.  Jim requires that.
int Jim_dlrNativeInit(Jim_Interp* itp) {
    //ivkClientT* client = client_alloc(itp);

//todo: Jim_PackageRequire a specific Jim version.

    if (Jim_PackageProvide(itp, "dlrNative", DLR_VERSION_STRING, 0) != JIM_OK) {
        return JIM_ERR;
    }

    // main required features.
    Jim_CreateCommand(itp, "dlr::native::loadLib", loadLib, NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::prepMetaBlob", prepMetaBlob, NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::callToNative", callToNative, NULL, NULL);
#ifdef BUILD_GIZMO
    Jim_CreateCommand(itp, "dlr::native::giCallToNative", giCallToNative, NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::giFreeHeap", giFreeHeap, NULL, NULL);
#endif

    // support features.
    Jim_CreateCommand(itp, "dlr::native::prepStructType", prepStructType, NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::fnAddr", fnAddr, NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::addrOf", addrOf, NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::createBufferVar", createBufferVar, NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::copyToBufferVar", copyToBufferVar, NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::allocHeap", allocHeap, NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::freeHeap", freeHeap, NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::sizeOfTypes", sizeOfTypes, NULL, NULL);

    // data packers.
    Jim_CreateCommand(itp, "dlr::native::u8-pack-byVal-asInt",              u8_pack_byVal_asInt,  NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::u16-pack-byVal-asInt",             u16_pack_byVal_asInt, NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::u32-pack-byVal-asInt",             u32_pack_byVal_asInt, NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::u64-pack-byVal-asInt",             u64_pack_byVal_asInt, NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::i8-pack-byVal-asInt",              i8_pack_byVal_asInt,  NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::i16-pack-byVal-asInt",             i16_pack_byVal_asInt, NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::i32-pack-byVal-asInt",             i32_pack_byVal_asInt, NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::i64-pack-byVal-asInt",             i64_pack_byVal_asInt, NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::float-pack-byVal-asDouble",        float_pack_byVal_asDouble, NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::double-pack-byVal-asDouble",       double_pack_byVal_asDouble, NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::longDouble-pack-byVal-asDouble",   longDouble_pack_byVal_asDouble, NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::ascii-pack-byVal-asString",        ascii_pack_byVal_asString, NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::pack-null",                        pack_null, NULL, NULL);

    // data unpackers.
    Jim_CreateCommand(itp, "dlr::native::u8-unpack-byVal-asInt",            u8_unpack_byVal_asInt,  NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::u16-unpack-byVal-asInt",           u16_unpack_byVal_asInt, NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::u32-unpack-byVal-asInt",           u32_unpack_byVal_asInt, NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::u64-unpack-byVal-asInt",           u64_unpack_byVal_asInt, NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::i8-unpack-byVal-asInt",            i8_unpack_byVal_asInt,  NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::i16-unpack-byVal-asInt",           i16_unpack_byVal_asInt, NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::i32-unpack-byVal-asInt",           i32_unpack_byVal_asInt, NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::i64-unpack-byVal-asInt",           i64_unpack_byVal_asInt, NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::float-unpack-byVal-asDouble",      float_unpack_byVal_asDouble, NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::double-unpack-byVal-asDouble",     double_unpack_byVal_asDouble, NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::longDouble-unpack-byVal-asDouble", longDouble_unpack_byVal_asDouble, NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::ascii-unpack-byVal-asString",      ascii_unpack_byVal_asString, NULL, NULL);
    Jim_CreateCommand(itp, "dlr::native::ascii-unpack-scriptPtr-asString",  ascii_unpack_scriptPtr_asString, NULL, NULL);

    return JIM_OK;
}

//todo: use Jim_WrongNumArgs throughout.
