# $Id: spiderFtypes.py,v 1.1 2012/07/03 14:21:59 leith Exp $
#
# check for various SPIDER file types

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

from spiderUtils import *

import os, string, struct, sys
import time

noNumbers = re.compile("[^\d^\s^\.^\+^\-Ee]")

bigendian = 1  # global var (fyi, 1 for SGI, but code doesn't expect that)

iforms = [1,3,-11,-12,-21,-22]
   
########################################################################
# Binary file functions

def isInt(f):
    try:
        i = int(f)
        if f-i == 0: return 1
        else:        return 0
    except:
        return 0

# returns the header, if t is a valid Spider header,
# otherwise returns 0
def isSpiderHeader(t):
    h = (99,) + t   # add 1 value so can use spider header index start=1
    # header values 1,2,5,12,13,22,23 should be integers
    if not isInt(h[1]): return 0
    if not isInt(h[2]): return 0
    if not isInt(h[5]): return 0
    if not isInt(h[12]): return 0
    if not isInt(h[13]): return 0
    if not isInt(h[22]): return 0
    if not isInt(h[23]): return 0
    # check iform
    iform = int(h[5])
    if not iform in iforms: return 0
    # check other header values
    labrec = int(h[13])   # no. records in file header
    labbyt = int(h[22])   # total no. of bytes in header
    lenbyt = int(h[23])   # record length in bytes
    #print "labrec = %d, labbyt = %d, lenbyt = %d" % (labrec,labbyt,lenbyt)
    if labbyt != (labrec * lenbyt): return 0
    # looks like a valid header
    return iform  #labbyt

# returns "image","volume","Fourier"  or 0
def isSpiderBin(filename):
    if not os.path.exists(filename):
        return 0
    minsize = 92  # 23 * 4 bytes
    if os.path.getsize(filename) < minsize:
        return 0
    try:
        fp = open(filename,'rb')
        f = fp.read(minsize)   # read 23 * 4 bytes
        fp.close()
    except:
        return 0
    bigendian = 1
    t = struct.unpack('>23f',f)    # try big-endian first
    iform = isSpiderHeader(t)
    if iform == 0:
        bigendian = 0
        t = struct.unpack('<23f',f)  # little-endian
        iform = isSpiderHeader(t)
    if iform == 0:
        return 0
    elif iform == 1:
        return "image"
    elif iform == 3:
        return "volume"
    elif iform in [-11,-12,-21,-22]:
        return "Fourier"

def isSpiderFile(filename):
    global bigendian
    try:
        fp = open(filename,'rb')
        f = fp.read(92)   # read 23 * 4 bytes
        fp.close()
    except:
        return 0
    bigendian = 1
    t = struct.unpack('>23f',f)    # try big-endian first
    hdrlen = isSpiderHeader(t)
    if hdrlen == 0:
        bigendian = 0
        t = struct.unpack('<23f',f)  # little-endian
        hdrlen = isSpiderHeader(t)
    return hdrlen

def isSpiderImage(filename):
    if isSpiderFile(filename):
        hdr = spiderHeader(filename)
        if hdr['iform'] == 1:
            return 1
        else:
            return 0
        
# returns a dictionary of header values
def spiderHeader(file):
    global bigendian
    d = {}
    nbytes = 24
    try:
        fp = open(file,'rb')
        f = fp.read(nbytes * 4)
        fp.close()
    except:
        return d
    
    if bigendian == 1: fmt = '>%df' % (nbytes)
    else: fmt = '<%df' % (nbytes)
    t = struct.unpack(fmt,f)
    h = (99,) + t   # add 1 value so can use index starting at 1
    d['nslice'] = int(h[1])
    d['nrow']   = int(h[2])
    d['iform']  = int(h[5])
    d['imami']  = int(h[6])
    if h[6] != 0:
        d['fmax'] = h[7]
        d['fmin'] = h[8]
        d['avg']  = h[9]
        d['sig']  = h[10]
    d['nsam']   = int(h[12])
    d['labrec'] = int(h[13])
    d['labbyt'] = int(h[22])
    d['lenbyt'] = int(h[23])
    d['istack'] = int(h[24])

    return d

# return [ (dimensions), (stats) ]  
def getSpiderInfo(t):
    " assumes its a valid header "
    h = (99,) + t   # add 1 value so can use spider header index start=1
    nsam = int(h[12])
    nrow = int(h[2])
    nslice = int(h[1])
    iform = int(h[5])

    dim2D = [1, -11, -12]
    dim3D = [3, -21, -22]
    if iform in dim3D:
        dims = (nsam, nrow, nslice)
    else:
        dims = (nsam, nrow)
        
    imami = int(h[6])
    if imami != 0:
        max = float(h[7])
        min = float(h[8])
        avg = float(h[9])
        std = float(h[10])
        stats = (max, min, avg, std)
        return [dims, stats]
    else:
        return [dims]
    
# returns [type,  (dimensions), and if ther are any,(stats) ]
# where type = "image","volume","Fourier"
# or returns 0
def spiderInfo(filename):
    if not os.path.exists(filename):
        return 0
    minsize = 92  # 23 * 4 bytes
    if os.path.getsize(filename) < minsize:
        return 0
    try:
        fp = open(filename,'rb')
        f = fp.read(minsize)   # read 23 * 4 bytes
        fp.close()
    except:
        return 0
    bigendian = 1
    t = struct.unpack('>23f',f)    # try big-endian first
    iform = isSpiderHeader(t)
    if iform != 0:
        info = getSpiderInfo(t)
    if iform == 0:
        bigendian = 0
        t = struct.unpack('<23f',f)  # little-endian
        iform = isSpiderHeader(t)
        if iform != 0:
            info = getSpiderInfo(t)

    if iform == 0:
        return 0
    elif iform == 1:
        type = "image"
    elif iform == 3:
        type = "volume"
    elif iform in [-11,-12,-21,-22]:
        type = "Fourier"
    return [type] + info

########################################################################
# Text functions

text_characters = "".join(map(chr, range(32, 127)) + list("\n\r\t\b"))
_null_trans = string.maketrans("", "")

# Test for text vs binary should call istextfile(filename)
# returns 1 for text, 0 for binary, 0 for error (no read permission?)
# pdf test added, cos they can get either answer.
def istextfile(filename, blocksize = 512):
    if os.path.isdir(filename):
        return 0
    name,ext = os.path.splitext(filename)
    if ext.lower() == ".pdf":
        return 0
    try:
        res = istext(open(filename).read(blocksize))
        return res
    except:
        print "Error: spiderFtypes.istextfile: unable to read %s" % filename
        return 0

def istext(s):
    if "\0" in s:
        return 0

    if not s:  # Empty files are considered text
        return 1

    # Get the non-text characters (maps a character to itself then
    # use the 'remove' option to get rid of the text characters.)
    t = s.translate(_null_trans, text_characters)

    # If more than 30% non-text characters, then
    # this is considered a binary file
    ratio = float(len(t)) / float(len(s))
    if ratio > 0.30:
        return 0
    return 1

# returns last key number (or -1)
def nkeysSpiderDoc(file):
    try:
        fp = open(file, 'r')
        fp.close()
    except:
        displayError( 'unable to open %s' % (file))
        return -1
    cmd = 'tail -5 %s' % (file)
    try:
        T,err = getCommandOutput(cmd)
        #T = getoutput(cmd)  
    except:
        return -1
    t = string.split(T,'\n')
    n = len(t) - 1
    for i in range(n,-1,-1): # start from bottom
        s = t[i].strip()
        
        if s == "" or s[0] == ';':
            continue
        
        ss = s.split()  # split by spaces
        n = len(ss)     # no. columns
        
        if n > 2:
            try:
                nkeys = int(ss[0])
                ncol = int(ss[1])
            except:
                return -1
            
            # for n columns, then 2nd number must be n-2 (no. columns)
            if isInt(ncol) and ncol == n-2:
                if isInt(nkeys):
                    return nkeys
            
        # maybe it's an old doc file
        try:
            nkeys = int(s[:6])
            nfs = int(s[6])
            return nkeys
        except:
            return -1

# quits as soon as it gets a good data line
def isSpiderDocfile(file):
    try:
        fp = open(file, 'r')
    except:
        print 'unable to open %s' % (file)
        return 0

    comments = 0
    isDoc = 0
    blank = 0
    while 1:
        s = fp.readline()
        if s == "":  # only EOF should return blank
            break

        if len(s) > 2 and s[0] == " " and s[1] == ';':   # Spider comment line
            continue

        if noNumbers.match(s):  # if find any nondigits, +, _ etc
            isDoc = 0
            break

        ss = s.split()
        # test for new format: nums divided by blanks, 1st value is an int,
        try:
            i = int(ss[0])
            # and there are N data columns, where N = s[1]
            n = int(ss[1])
            if len(ss[2:]) == n:
                isDoc = 1
                break         # then it's new (SPIDER 11.0 Feb 2004)
        except:
            pass
        
        # see if it's the older fixed column format
        if len(s) < 13:
            isDoc = 0
            break
        try:
            key = int(s[0:6])   # 1st 6 chars are key
            n = int(s[6])       # 7th char is N
            f = float(s[7:13])   # see if there's 1 good data value
            isDoc = 1
            break
        except:
            isDoc = 0
            break
    fp.close()
    return isDoc


# ---------------------------------------------------------
# Batch file routines

re_hdr = re.compile('END +BATCH +HEADER')  
re_reg = re.compile('[xX][0-9][0-9] *=')   # "x11 =" patterns
re_bat1 = re.compile(':: *SPIDER +BATCH +FILE *::') # lower case, ignores too many spaces
re_bat2 = re.compile(':: *SPIDER +PROCEDURE +FILE *::')

# isSpiderBatchfile
# only looks for ":: spider batch file ::" or "[x11,x12]"  in first line .
# No other parsing
def isSpiderBatchfile(file):
    """ only checks first few lines of text.
        only ":: spider batch file ::"
          or ; --- End batch header ---
          or "FR G/L" pattern followed by [symbol]
        are checked
    " or ?symbol? pattern
    """
    try:
        fp = open(file, 'r')
    except:
        print 'unable to open %s' % (file)
        return 0

    max = 40
    for i in range(max):
        line = fp.readline()
        if not line:
            fp.close()
            return 0
        line = line.strip()
        line = line.upper()
        cmd = ""
        if len(line) > 3:
            cmd = line[0:4]
            
        if len(line) == 0:
            continue
        elif re_bat1.search(line) or re_bat2.search(line):
            fp.close()
            return 1
        elif re_hdr.search(line):
            fp.close()
            return 1
        # coment must come after header
        elif line[0] == ";":
            continue
        elif re_reg.match(line):
            fp.close()
            return 1
        # FR must be followed by symbol
        elif cmd == "FR G" or cmd == "FR L":
            fp.close()
            return 1
            #line = fp.readline()
            #line = line.strip()
            #if re_sym.match(line):
        # too much work to eliminate a text file
        #else:
            #fp.close()
            #return 0

re_proc_hdr  = re.compile('\[([xX][0-9][0-9],?)+\]')  # "[x12,x13,..]" patterns
re_proc_hdr2 = re.compile('\(([xX][0-9][0-9],?)+\)')  # "(x12,x13,..)" patterns
re_proc_hdr3 = re.compile('\( *(( *, *)?\[[\._\w-]+\])+ *\)')  # ([a],[b]) patterns
re_sym = re.compile('\?[\w ]+\?')   # "?symbol?" patterns
def isSpiderProcedurefile(file):
    """
    Checks 2 conditions:
    if top has either [x12] register or FR ?XXX? pattern,
    if there's a RE statement.
    
    Only checking the first few lines of text doesn't work. procs can
    start with arbitrary Spider ops.
    [x11,x12] (or (x11,x12)) pattern 
    or "FR" pattern followed by ?symbol?
    or comments or blank lines are allowed
    """
    B = fileReadLines(file)
    if B == None:
        return 0

    has_top = 0
    has_RE = 0

    # check top for registers or FR
    maxlin = min(22, len(B))
    for i in range(maxlin):
        line = B[i]
        line = stripComment(line)
        if len(line) == 0:
            continue
        # note use of "re.match" (beginning of line) vs "re.search"
        elif re_proc_hdr2.match(line) or re_proc_hdr.match(line) or re_proc_hdr3.match(line):
            has_top = 1
            break
        # FR must be followed by "?symbol?"
        elif line[0:2].upper() == "FR":
            next = B[i+1]
            next = next.strip()
            #if re_sym.match(line):  # doesn't work for ? (input) ?
            if next[0] == '?' and next[1:].find('?') > 0:
                has_top = 1
                break

    if not has_top:
        return 0

    B.reverse()
    for line in B:
        s = stripComment(line).upper()
        if s == 'RE':
            has_RE = 1
            break

    if has_top and has_RE:
        return 1
    else:
        return 0

def isSpiderConfigFile(file):
    try:
        fp = open(file, 'r')
    except:
        print 'unable to open %s' % (file)
        return 0

    max = 5
    for i in range(max):
        line = fp.readline()
        if not line:
            fp.close()
            return 0
        if line.find("<Configuration>") > -1:
            fp.close()
            return 1
    fp.close()
    return 0


# ---------------------------------------------------------
# outputs (date, time) tuple in spider format: ('14-OCT-2003', '15:55:17')
def spiderDate(t):
    import types
    if isinstance(t, types.IntType):  # output of time()
        t = time.asctime(time.localtime(t))
    elif isinstance(t, types.LongType):  # output of time()
        t = time.asctime(time.localtime(t))
    elif isinstance(t, types.FloatType):  # output of time()
        t = time.asctime(time.localtime(t))
    elif isinstance(t, types.TupleType): # output from localtime()
        t = time.asctime(t)
    elif isinstance(t, StringType):  # output from asctime()
        pass
    else:
        return ('XXX', 'XXX')
    t = string.split(t)
    mo = string.upper(t[1])
    day = t[2]
    yr = t[-1]
    mtime = t[3]
    date = '%s-%s-%s' % (day,mo,yr)
    return (date, mtime)

# Return list [name, type, size, date, time] (or 1 word [description] )
def getFileType(file):
    if os.path.isdir(file): return ['directory']
    name = projFilename(file)
    tup = os.stat(file)
    (date, time) = spiderDate(tup[8])

    # check extensions
    basename, ext = os.path.splitext(file)
    ext = string.lower(ext[1:]) # remove dot
    type = ""
    
    if ext == 'gz' or ext == 'tgz' or ext == 'zip':
        type = 'zipped'
    elif ext == 'tif' or ext == 'tiff':
        type = 'tif'
    elif ext == 'tar':
        type = 'tarfile'
    if type != "":
        size = ('---', '---')
        return [name, type, size, date, time]
    
    # check existence, access
    # if not checkFileAccess(file):
    if istextfile(file):
        if isSpiderDocfile(file):
            type = 'Document'
            name = projFilename(file)
            nkeys = nkeysSpiderDoc(file)
            if nkeys == -1:
                displayError('Unable to get last key from %s' %(file))
                return ['text']
            tup = os.stat(file)
            nbytes = tup[6]
            size = (str(nkeys), str(nbytes))
            mtime = tup[8]  # last modification
            (date, time) = spiderDate(mtime)
            return [name, type, size, date, time]
        else:
            return ['text']
        
    elif isSpiderFile(file):
        name = projFilename(file)
        d = spiderHeader(file)
        iform = d['iform']
        if iform == 1:
            type = 'Image'
            size = (d['nsam'], d['nrow'])
        elif iform == 3:
            type = 'Volume'
            size = (d['nsam'], d['nrow'], d['nslice'])
        elif iform == -11 or iform == -12:
            type = 'Fourier'
            size = (d['nsam'], d['nrow'])
        elif iform == -21 or iform == -22:
            type = '3D Fourier'
            size = (d['nsam'], d['nrow'], d['nslice'])
        else:
            type = 'Unknown'
            size = (0,0)
        if d['istack'] != 0:
            type = 'Stack'
        tup = os.stat(file)
        (date, time) = spiderDate(tup[8])
        return [name, type, size, date, time]

    return ['binary']

        
if __name__ == '__main__':

    flist = os.listdir(os.getcwd())
    flist.sort()
    for file in flist:
        d = getFileType(file)
        if len(d) == 1:
            print "%s : %s" % (file, d[0])
        else:
            print d
