# dlr - Dynamic Library Redux

Project home:  [http://github.com/TheMarkitecht/dlr](http://github.com/TheMarkitecht/dlr)

Legal stuff:  see below.

---

## Introduction:

**dlr** is an extension for [Jim Tcl](http://jim.tcl.tk/), the small-footprint Tcl interpreter.

**dlr** may be easily pronounced as "dealer".  It makes deals between Jim and native code.

**dlr** binds your Jim scripts to libffi (Foreign Function Interface).
It lets your Jim scripts dynamically call a shared object library (.so file) of your choosing,
without writing any C/C++ code if you don't want to.

## Features of This Version:

* Concise syntax for declaring native functions and structs.
* Supports struct types.  But not nested structs, yet.
* Can automatically extract actual size and offset information for each struct member, as built by the current host's compiler (works with gcc or clang).
* Supports calling only one direction: from script to native code.
* Supports GObject Introspection for calling GTK+ 3 GUI toolkit, and other libraries built on GNOME GObject.  See [gizmo project](http://github.com/TheMarkitecht/gizmo)
* Lightweight, small footprint.  No dependencies other than Jim and libffi.
* Creates the thinnest possible C wrapper around libffi, for maximum simplicity, and future portability.  The surrounding features are implemented in a script package.
* Extensible packing/unpacking framework in the script package.  That supports fast dispatch, and selective implementation of certain type conversions entirely in C, if needed for your app.
* Automatically generated code is kept separate, in the `auto/` directory, while handwritten binding scripts are kept in the `script/` directory.
* Ultra-simple build process.  Native source for **dlr** is just one .c file.
* Works with Jim's `package require` command.
* Automatically adapts to various machine word sizes and endianness.
* Designed for Jim 0.79 on GNU/Linux for amd64 architecture (includes Intel CPU's).
* Tested on Debian 10.0 with libffi6-3.2.1-9.
* Might work well on ARM too.  It has passed tests there before.  Drop me a line if you've tried it!

## Requirements:

* Jim 0.79 or later
* libffi (tested with libffi6-3.2.1-9)
* gcc (tested with gcc 8.3.0)

## Building:

See [build](build) script.

## Future Direction:

* Improve UTF8 support.  Currently UTF8 is treated as ASCII.
* Expand the packing/unpacking framework in the script package, for unions etc.
* Test on ARM embedded systems.
* Support callbacks from native code to script.
* Supply a binding for a practical GUI toolkit, likely GTK+3.  << this is in progress; see [gizmo project](http://github.com/TheMarkitecht/gizmo)
* Speed improvements?
* Maybe let the script package generate C code to speed up your call, after your call is known to work well.

## Legal stuff:
```
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
```

See [COPYING.LESSER](COPYING.LESSER) and [COPYING](COPYING).

## Contact:

Send donations, praise, curses, and the occasional question to: `Mark-ate-TheMarkitecht-dote-com`

## Final Word:

I hope you enjoy this software.  If you enhance it, port it to another environment,
or just use it in your project etc., by all means let me know.

>  \- TheMarkitecht

---
