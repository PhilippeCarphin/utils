#
# Sample makefile for bash loadable builtin development
#
# Copyright (C) 2022 Free Software Foundation, Inc.

#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

# these should match the ones in Makefile.in (for the make install target)

BASH_DEV_DIR ?= /Users/pcarphin/Repositories/github.com/bminor/bash/localinstall
my_build_dir ?= .
prefix ?= $(BASH_DEV_DIR)
exec_prefix = ${prefix}
libdir = ${exec_prefix}/lib

# ${loadablesdir} is where the example loadable builtins and data files
# are installed (make install target in Makefile.in)

loadablesdir = ${libdir}/bash
DESTDIR =

# include Makefile.inc for all boilerplate definitions

include $(DESTDIR)$(loadablesdir)/Makefile.inc
INC+= -I$(loadablesdir)

# here, `example' is the name of the shared object
# replace `example' with the appropriate filename

all:	$(my_build_dir)/my-builtins.so

$(my_build_dir)/my-builtins.so:	$(my_build_dir)/shell-split.o
	$(SHOBJ_LD) $(SHOBJ_LDFLAGS) $(SHOBJ_XLDFLAGS) -o $@ $^ $(SHOBJ_LIBS)

$(my_build_dir)/%.o: %.c
	$(SHOBJ_CC) $(SHOBJ_CFLAGS) $(CCFLAGS) $(INC) -c -o $@ $<

clean:
	rm -f $(my_build_dir)/shell-split.o $(my_build_dir)/my-builtins.so
