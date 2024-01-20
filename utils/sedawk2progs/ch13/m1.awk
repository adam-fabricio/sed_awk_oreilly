#! /bin/awk -f
# NAME
#
# m1
#
# USAGE
#
# awk -f m1.awk [file...]
#
# DESCRIPTION
#
# M1 copies its input file(s) to its output unchanged except as modified by
# certain "macro expressions."  The following lines define macros for
# subsequent processing:
#
#     @comment Any text
#     @@                     same as @comment
#     @define name value
#     @default name value    set if name undefined
#     @include filename
#     @if varname            include subsequent text if varname != 0
#     @unless varname        include subsequent text if varname == 0
#     @fi                    terminate @if or @unless
#     @ignore DELIM          ignore input until line that begins with DELIM
#     @stderr stuff          send diagnostics to standard error
#
# A definition may extend across many lines by ending each line with
# a backslash, thus quoting the following newline.
#
# Any occurrence of @name@ in the input is replaced in the output by
# the corresponding value.
#
# @name at beginning of line is treated the same as @name@.
#
# BUGS
#
# M1 is three steps lower than m4.  You'll probably miss something
# you have learned to expect.
#
# AUTHOR
#
# Jon L. Bentley, jlb@research.bell-labs.com
#

function error(s) {
	print "m1 error: " s | "cat 1>&2"; exit 1
}

function dofile(fname,  savefile, savebuffer, newstring) {
	if (fname in activefiles)
		error("recursively reading file: " fname)
	activefiles[fname] = 1
	savefile = file; file = fname
	savebuffer = buffer; buffer = ""
	while (readline() != EOF) {
		if (index($0, "@") == 0) {
			print $0
		} else if (/^@define[ t]/) {
			dodef()
		} else if (/^@default[ t]/) {
			if (!($2 in symtab))
				dodef()
		} else if (/^@include[ t]/) {
			if (NF != 2) error("bad include line")
			dofile(dosubs($2))
		} else if (/^@if[ t]/) {
			if (NF != 2) error("bad if line")
			if (!($2 in symtab) || symtab[$2] == 0)
				gobble()
		} else if (/^@unless[ t]/) {
			if (NF != 2) error("bad unless line")
			if (($2 in symtab) && symtab[$2] != 0)
				gobble()
		} else if (/^@fi([ t]?|$)/) { # Could do error checking here
		} else if (/^@stderr[ t]?/) { 
			print substr($0, 9) | "cat 1>&2"
		} else if (/^@(comment|@)[ t]?/) {
		} else if (/^@ignore[ t]/) { # Dump input until $2
			delim = $2
			l = length(delim)
			while (readline() != EOF)
				if (substr($0, 1, l) == delim)
					break
		} else {
			newstring = dosubs($0)
			if ($0 == newstring || index(newstring, "@") == 0)
				print newstring
			else
				buffer = newstring "n" buffer
		}
	}
	close(fname)
	delete activefiles[fname]
	file = savefile
	buffer = savebuffer
}

# Put next input line into global string "buffer"
# Return "EOF" or "" (null string)

function readline(  i, status) {
	status = ""
	if (buffer != "") {
		i = index(buffer, "n")
		$0 = substr(buffer, 1, i-1)
		buffer = substr(buffer, i+1)
	} else {
		# Hume: special case for non v10: if (file == "/dev/stdin")
		if (getline <file <= 0)
			status = EOF
	}
	# Hack: allow @Mname at start of line w/o closing @
	if ($0 ~ /^@[A-Z][a-zA-Z0-9]*[ t]*$/)
		sub(/[ t]*$/, "@")
	return status
}

function gobble(  ifdepth) {
	ifdepth = 1
	while (readline() != EOF) {
		if (/^@(if|unless)[ t]/)
			ifdepth++
		if (/^@fi[ t]?/ && --ifdepth <= 0)
			break
	}
}

function dosubs(s,  l, r, i, m) {
	if (index(s, "@") == 0)
		return s
	l = ""	# Left of current pos; ready for output
	r = s	# Right of current; unexamined at this time
	while ((i = index(r, "@")) != 0) {
		l = l substr(r, 1, i-1)
		r = substr(r, i+1)	# Currently scanning @
		i = index(r, "@")
		if (i == 0) {
			l = l "@"
			break
		}
		m = substr(r, 1, i-1)
		r = substr(r, i+1)
		if (m in symtab) {
			r = symtab[m] r
		} else {
			l = l "@" m
			r = "@" r
		}
	}
	return l r
}

function dodef(fname,  str, x) {
	name = $2
	sub(/^[ t]*[^ t]+[ t]+[^ t]+[ t]*/, "")  # OLD BUG: last * was +
	str = $0
	while (str ~ /\\$/) {
		if (readline() == EOF)
			error("EOF inside definition")
		x = $0
		sub(/^[ t]+/, "", x)
		str = substr(str, 1, length(str)-1) "n" x
	}
	symtab[name] = str
}

BEGIN {	EOF = "EOF"
	if (ARGC == 1)
		dofile("/dev/stdin")
	else if (ARGC >= 2) {
		for (i = 1; i < ARGC; i++)
			dofile(ARGV[i])
	} else
		error("usage: m1 [fname...]")
}
