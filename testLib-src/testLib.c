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

#define _POSIX_C_SOURCE 200809L

#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>

typedef uint8_t u8;
typedef uint32_t u32;

/* **********************  EXECUTABLE CODE BELOW  ***************************** */

// wrapper of a simple libc function, to help debugging and smoke testing.
extern long int strtolTest(const char *nptr, char **endptr, int base);
long int strtolTest(const char *nptr, char **endptr, int base) {
    if (nptr == NULL)
        return -999999999;
    return strtol(nptr, endptr, base);
}

// pass a struct or array by value.  return a different version of that.
typedef struct {int a, b, c, d; } quadT;
extern quadT mulByValue(const quadT st, const int factor);
quadT mulByValue(const quadT st, const int factor) {
    quadT r = {st.a * factor, st.b * factor, st.c * factor, st.d * factor};
    return r;
}
extern quadT mulDict(const quadT st, const int factor);
quadT mulDict(const quadT st, const int factor) {
    return mulByValue(st, factor);
}

// define another type.
typedef u32 dataHandleT;
extern dataHandleT dataHandler(dataHandleT handle);
dataHandleT dataHandler(dataHandleT handle) {
    return handle << 4;
}

extern dataHandleT dataHandlerPtr(dataHandleT* handleP);
dataHandleT dataHandlerPtr(dataHandleT* handleP) {
    *handleP = *handleP << 4;
    return *handleP;
}

extern void dataHandlerVoid(dataHandleT* handleP);
void dataHandlerVoid(dataHandleT* handleP) {
    *handleP = *handleP << 4;
}

// floating point.
extern float floatSquare(double stuff, long double longStuff);
float floatSquare(double stuff, long double longStuff) {
    return (float)(stuff * longStuff);
}

extern void floatSquarePtr(double* stuff);
void floatSquarePtr(double* stuff) {
    *stuff = *stuff * *stuff;
}

extern void cryptAscii(char* txt, int step);
void cryptAscii(char* txt, int step) {
    char* ch = txt;
    for ( ; *ch != 0; ch++)
        *ch += step;
}

extern void cryptAsciiMalloc(char* clear, char** crypted, int step);
void cryptAsciiMalloc(char* clear, char** crypted, int step) {
    *crypted = strdup(clear);
    char* ch = *crypted;
    for ( ; *ch != 0; ch++)
        *ch += step;
}

extern char* cryptAsciiRtn(char* clear, int step);
char* cryptAsciiRtn(char* clear, int step) {
    char* crypted = strdup(clear);
    char* ch = crypted;
    for ( ; *ch != 0; ch++)
        *ch += step;
    return crypted;
}

// pass a struct or array by pointer.  return a different version of that.
extern void mulPtr(quadT* st, const int factor);
void mulPtr(quadT* st, const int factor) {
    st->a *= factor;
    st->b *= factor;
    st->c *= factor;
    st->d *= factor;
}
extern void mulMalloc(quadT** st, const int factor);
void mulMalloc(quadT** st, const int factor) {
    quadT* r = (quadT*)malloc(sizeof(quadT));
    r->a = 10 * factor;
    r->b = 11 * factor;
    r->c = 12 * factor;
    r->d = 13 * factor;
    *st = r;
}
extern quadT* mulMallocRtn(const quadT st, const int factor);
quadT* mulMallocRtn(const quadT st, const int factor) {
    quadT* r = (quadT*)malloc(sizeof(quadT));
    r->a = st.a * factor;
    r->b = st.b * factor;
    r->c = st.c * factor;
    r->d = st.d * factor;
    return r;
}
extern void mulPtrNat(quadT* st, const int factor);
void mulPtrNat(quadT* st, const int factor) {
    st->a *= factor;
    st->b *= factor;
    st->c *= factor;
    st->d *= factor;
}
extern quadT* mulMallocRtnNat(const int factor);
quadT* mulMallocRtnNat(const int factor) {
    quadT* r = (quadT*)malloc(sizeof(quadT));
    r->a = 10 * factor;
    r->b = 11 * factor;
    r->c = 12 * factor;
    r->d = 13 * factor;
    return r;
}

// enums
typedef enum {north, east, south, west, directionCount} directions;
extern directions dirRotate(const directions d);
directions dirRotate(const directions d) {
    return (d + 1) % directionCount;
}
extern void dirRotatePtr(directions* d);
void dirRotatePtr(directions* d) {
    *d = (*d + 1) % directionCount;
}
