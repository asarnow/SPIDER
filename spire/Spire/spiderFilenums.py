# $Id: spiderFilenums.py,v 1.1 2012/07/03 14:21:59 leith Exp $
#
# functions for handling file number doc selection files

"""
SPIRE - The SPIDER Reconstruction Engine
Copyright (C) 2006-2008  Health Research Inc.

HEALTH RESEARCH INCORPORATED (HRI),
ONE UNIVERSITY PLACE, RENSSELAER, NY 12144-3455

Email:  spider@wadsworth.org

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License as
published by the Free Software Foundation; either version 2 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.
"""

import re, string
from   Tkinter import *
import GB,GG
from spiderUtils import *
from spiderGUtils import getFiles, askSaveAsFilename, writeUserPrefs

####################################################################
# FILE NUMBERS
#
# NB  "range" refers to the compact form (1-4), while "list" = (1,2,3,4)

def getFileNumbersEntry():
    "thread-safe way to read the filenumbers entry box in Main Window."
    " Use this instead of GG.disp_fnums.get() "
    if isMainThread():
        result = GG.disp_fnums.get()
    else:
        result = threadedGUIcall()
    return result

def isDefaultFilenumFile():
    "checks GG.sysprefs.filenumFile for blank or occasional '.dat' (extension only)"
    f = GG.sysprefs.filenumFile.strip()
    if f == "":
        return 0
    name,ext = os.path.splitext(f)
    if name == "":
        return 0
    return 1
    
# Bound to the entry box, reads the entry box and saves to filenums file.
# Returns range in the form of a string
def readFileNumbers(event=None, filenumFile=None):
    if not hasProject():
        noProjectError()
        return
    msg = GG.msg
    newnums = getFileNumbersEntry()
    if newnums == "" or newnums == None: return
    
    if filenumFile == None:
        if isDefaultFilenumFile():
            # if there is a filenums file in sysprefs, use that
            fname = os.path.join(GB.P.projdir, GG.sysprefs.filenumFile)
        else:
            # otherwise ask user where to put filenums
            data_ext = "*." + GB.P.dataext
            initfile = "filenums." + GB.P.dataext  # HARD CODED SUGGESTION
            fname = askSaveAsFilename(filetypes=data_ext, initialfile=initfile)
            if fname == "":
                return None
            # use fname as new default filenums filename (w/o path)
            GG.sysprefs.filenumFile = os.path.basename(fname)
            writeUserPrefs()  # apparently not done automatically at quit?
        
    else:
        fname = filenumFile # use input argument
        
    nlist = range2list(newnums)
    fname = addExtension(fname, GB.P.dataext)
    a = docWriteLines(fname, nlist)
    if a == 1:
        GB.outstream('File numbers written to ' + fname + '\n')
        return range2string(newnums)
    else:
        return None
"""    
def readFileNumbers(event=None, filenumFile=None):
    if not hasProject():
        noProjectError()
        return
    msg = GG.msg
    new = getFileNumbersEntry()
    if new == "" or new == None: return
    if filenumFile == None:
        filenumFile = GG.sysprefs.filenumFile
        fname = os.path.join(GB.P.projdir, filenumFile)
    else:
        fname = filenumFile
        
    nlist = range2list(new)
    a = docWriteLines(fname, nlist)
    if a == 1:
        GB.outstream('File numbers written to ' + filenumFile + '\n')
        return range2string(new)
    else:
        return None
"""
def FileNumbersButton():
    if hasProject():
        datext = "*." + GB.P.dataext
        filelist = getFiles(filetypes=datext)
    else:
        filelist = getFiles()
    if len (filelist) == 0:
        return

    nums = filenames2numbers(filelist)
    new = []       # make sure they're unique
    for n in nums:
        if n not in new:
            new.append(n)
    setFileNumbers(new)
    
    
# Get filenumbers either from a file or entry.
# If both set, entry takes precedence.
# Filename must be fully qualified.
# Returns a range in form of a string.
def getFileNumbers(filename=None, useEntry=0):
    if filename == None:
        filename = os.path.join(GB.P.projdir,GG.sysprefs.filenumFile)
    a = 1
    new = getFileNumbersEntry()
    if new == "" or new == None:
        nlist = openFileNumbers(filename)
        setFileNumbers(nlist) # put in entry
        new = list2range(nlist)
    else:
        nlist = range2list(new)
        a = docWriteLines(filename, nlist)
        
    if a == 1:
        return range2string(new)
    else:
        return None

def setFileNumbers(fnlist):
    if fnlist == None or len(fnlist) < 1: return
    fnlist.sort()
    a = range2string(list2range(fnlist))
    
    if isMainThread():
        GG.disp_fnums.set(a)
    else:
        msg = "GG.disp_fnums.set('%s')" % a
        GG.spidui.write_queue(msg)
        
    if hasProject():
        filenums = os.path.join(GB.P.projdir,GG.sysprefs.filenumFile)
        docWriteLines(filenums, fnlist)

# returns 1 if finds line "<sym>str  ; file numbers " in batch header
def useFileNumbers(filename):
    filenumSymbol = GG.sysprefs.filenumSymbol
    found = 0
    lines = fileReadLines(filename)
    for line in lines:
        line = line.strip()
        if line.find(GB.end_of_header) > -1:
            break
        if line.find(filenumSymbol) > -1:
            # make sure it's not in a comment
            if string.find(stripComment(line), filenumSymbol) > -1:
                found = 1
                break
    return found


def getFilenumFilename(batchfilename):
    "returns filename associated with filenumSymbol in batch header"
    filenumSymbol = GG.sysprefs.filenumSymbol
    filenumFilename = ""
    lines = fileReadLines(batchfilename)
    for line in lines:
        line = line.strip()
        if line.find(GB.end_of_header) > -1:
            break
        line = stripComment(line)
        if line.find(filenumSymbol) > -1:
            filenumFilename = line.replace(filenumSymbol,"").strip()
            filenumFilename = addExtension(filenumFilename, GB.P.dataext)
            break
    return filenumFilename

# Reads from a file. Filename must be fully qualified.
# Returns a list of integers.
def openFileNumbers(filename):
    if os.path.exists(filename) != 1: return []
    nlist = readdoc(filename, 1)
    fn = []
    for item in nlist:
        fn.append(int(item))
    return fn

# given ['mic001.dat, mic002.dat,..] --> returns [1,2,..]
def filenames2numbers(flist):
    if len(flist) == 0: return
    nums = re.compile('\d+\D')  # ints followed by one non-int char
    nlist = []
    for file in flist:
        m = nums.findall(file)
        if len(m) == 1:
            n = m[0][:-1] # remove trailing char
            nlist.append(int(n)) 
        elif len(m) > 1:  # if more than one, use n nearest the dot
            for item in m:
                if item.find('.') > -1:
                    n = item[:-1]
                    nlist.append(int(n))
    return nlist
    
# input: string "1-4"
# output: list [1,2,3,4]
def range2list(nrange):
    if nrange == "" or None:
        return []
    L = nrange.split(',')
    K = []
    for item in L:
        h = item.find('-')
        if h != -1:
            start = int(item[:h])
            end = int(item[h+1:])
            for i in range(start,end+1):
                K.append(i)
        else:
            K.append(int(item))
    K.sort() 
    return K

# input: list [1,2,3,6,7,8,9,10,11,17]
# output: list with strings ['1-3', '6-11', '17']
def list2range(f):
    fn = []
    for item in f: fn.append(int(item))
    if len(fn) < 1: return []
    fn.sort()
    N = []
    p = fn[0]
    start = p
    n = p
    fn = fn[1:]

    while len(fn) > 0:
        n = fn[0]
        if n == p+1:
            p = n
        else:
            if start != p:  N.append(str(start) + '-' + str(p))
            else:           N.append(str(start))
            start = n
            p = n
        fn = fn[1:]
    if start != n:
        N.append(str(start) + '-' + str(n))
    else:
        N.append(str(start))

    M = []    # get rid of trivial ranges (eg, '1-2')
    for item in N:
        if '-' in item:
            x = item.split('-')
            a = int(x[0])
            b = int(x[1])
            if b == a + 1:
                M.append(x[0])
                M.append(x[1])
            else:
                M.append(item)
        else:
            M.append(item)
            
    return M

# input: list of strings (output from list2range)
# output: string
def range2string(n):   # converts ['1-4','7'] to "1-4,7"
    if len(n) == 0: return ""
    x = str(n)
    a = x.replace('[', '')
    b = a.replace(']', '')
    c = b.replace("'", "")
    return c
