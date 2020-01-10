# dlr - Dynamic Library Redux

Project home:  [http://github.com/TheMarkitecht/dlr](http://github.com/TheMarkitecht/dlr)

Legal stuff:  see below.

---

## Introduction:

dlr is an extension for [Jim Tcl](http://jim.tcl.tk/), the small-footprint Tcl interpreter.

dlr may be easily pronounced as "dealer".

dlr binds your Jim scripts to libffi (Foreign Function Interface).
It lets your Jim scripts dynamically call a shared object library (.so file) of your choosing.

## Features of This Version:

* Supports calling only one direction: from script to native code.
* Lightweight, small footprint.  No dependencies other than Jim and libffi.
* Creates the thinnest possible C wrapper around libffi, for maximum simplicity, and future portability.  All the surrounding features are implemented in a script library.
* Ultra-simple build process.
* Works with Jim's `package require` command.
* Designed for Jim 0.79 on GNU/Linux for amd64 architecture (includes Intel CPU's).
* Tested (such as it is) on Debian 10.0 with libffi.so.6.0.4.
* Might work well on ARM too (drop me a line if you've tried it!).

## Requirements:

* Jim 0.79 or later
* libffi (tested with 6.0.4)
* gcc (tested with gcc 8.3.0)

## Building:

See [build](build) script.

## Future Direction:

* Add a modular packing/unpacking framework in the script library.
* Add a concise syntax for declaring the call.
* Test on ARM embedded systems.
* Maybe let the script library generate C code to speed up your call, after your call is known to work well.

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
