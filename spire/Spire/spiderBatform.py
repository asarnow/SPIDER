# $Id: spiderBatform.py,v 1.2 2012/08/01 01:22:52 tapu Exp $
#
# Parses a well-formed batch file, presents a form

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

import copy,os,re
import stat
from string import find, strip, upper, lower, count, split
import sys
from Tkinter import *
import Pmw

import GB,GG
import spiderBatch
from spiderUtils import *
from spiderGUtils import *
from spiderClasses import scrolledForm

re_regs = re.compile('^[xX][0-9][0-9]\s*=')  # looks for "x44 =" patterns
# named regs may have underscores, hyphens, dots. No spaces.
re_namedregs = re.compile('\[[\._\w-]+\] *=')  # "[namedreg] = " patterns
re_anyreg = re.compile('[xX][0-9][0-9]')  # looks for any register patterns
re_anynamedreg = re.compile('\[[\._\w-]+\]')  # "[any]" patterns

re_namedregpattern = re.compile('{\*+\[[\._\w-]+\]}')  # "{**[any]}" patterns
re_regpattern = re.compile("{\*+[xX]\d\d}")  # looks for {****x22} patterns
re_noreg = re.compile("[.\w_-]+[*]+")  # mic*** no registers: underscores, dots, minus allowed in fnames
re_stars = re.compile("[*]+")   # one or more *'s
re_group = re.compile("-- *[\w ?!#$%^&*()+=':;]+ *--")     #  looks for "-- text --"
#re_group = re.compile('-- *[\w ]+ *--')     #  looks for "-- text --"
#re_group = re.compile('--[^\-]+--')     #  looks for "-- text --"
re_FRG  = re.compile('[Ff][Rr] [GgLl]')
#re_FRL  = re.compile('[Ff][Rr] [Ll]')
re_Nend = re.compile("\d{1,}$") # gets numbers at the end of a string
# NB note uses of re.match() (beginning of string) vs re.search() below.

execGreen = "#60E090"

def isSpiderFloat(x):
    try:
        z = float(x)
        return 1
    except:
        if x.find("(") > -1 or x.find(")") > -1: return 1
       
        return 0

def valid_quotes(s):
    " there should be an even number of quotes "
    singQ = "'"
    doubQ = '"'
    n = s.count(singQ)
    if n%2:
        return Pmw.PARTIAL
    m = s.count(doubQ)
    if m%2:
        return Pmw.PARTIAL

    " quotes should occur in pairs "
    if n+m >= 4:
        sing = doub = 0
        for ch in s:
            if ch == singQ:
                sing += 1
                if sing == 2: sing = 0
            elif ch == doubQ:
                doub += 1
                if doub == 2: doub = 0
            if doub == 1 and sing == 1:
                return Pmw.PARTIAL
    return Pmw.OK
    
#root = Tk()
"""
group: [name, [list of file tuples]]
e.g.,
['Input files', [
    [21, '../params', 'parameter file', '<params>'],
    [23, '../filenums', 'file numbers', '<filenums>'],
    [25, '../Micrographs/win{****x12}', 'micrographs', '<mic>']
    ]
]

file tuple: [line number, value, comment, symbol]
"""
def countdigits(filename):
    " returns (n,x) n = no. consecutive digits, starting from right."
    "   x = starting index to digits. Digit str = file[x:x+n]       "
    file, ext = os.path.splitext(filename)  # get rid of extension, if any

    i = -1  # string index
    k = 0
    digitstring = ""
    for char in file:
        c = file[i]
        
        if c.isdigit():
            k = k + 1
            digitstring = c + digitstring
        else:
            if k > 0:
                break
        i = i - 1

    if digitstring != "":
        n = len(digitstring)
        x = len(file) + i + 1
    else:
        n = 0
        x = -1
    return (n, x)

def findRegister(pattern, all=0):
    " all == 0, returns found patterns. "
    " all > 0, returns list of found patterns"
    " returns zero if no match found "
    # using findall, found is a list
    found = re_namedregpattern.findall(pattern)  # look for {***[sym]} patterns
    if not found:
        found = re_regpattern.findall(pattern)  # look for {***x12} patterns
        if not found:
            found = re_noreg.findall(pattern)   # look for "mic***" format

    if not found:
        return 0
    elif all == 0:
        return found[0]
    else:
        return found
    
# Each pattern {***x11} in oldpattern must match
# digits in corresponding path elements in newpath.
#
# given oldpattern: ../home/df**/aa/mic***
#    and newpath: /net/sylt/df01/bb/raw001.tmp
#       return:   /net/sylt/df**/bb/raw***
#
# Should work for both 'mic{***x12}' and 'mic***' formats.
#
def replacePatterns(oldpattern, newpath, deleteExt=0):
    #print "replacePatterns:"
    #print oldpattern
    #print newpath
    " returns -1 upon error "
    if deleteExt:
        newpath, e = os.path.splitext(newpath)

    P = split(oldpattern,os.sep)
    P.reverse()
    N = split(newpath,os.sep)
    N.reverse()
    lenP = len(P)
    lenN = len(N)
    nelements = lenP
    if lenN < nelements:
        nelements = lenN  # use whichever has smaller no. of elements

    R = []
    for i in range(nelements):
        pat = P[i]
        found = findRegister(pat)
            
        if found:
            newpattern = fname2pattern(pat, N[i])
            if newpattern == "":
                errstr = "unable to match pathname " + newpath + "\n"
                errstr += "to batch file template " + oldpattern + "\n"
                errstr += "%s fails to match %s" % (N[i], P[i])
                print errstr
                return -1
            else:
                R.append(newpattern)
        else:
            R.append(N[i])

    if lenN > lenP:
        d = lenN - lenP
        R = R + N[-d:]

    R.reverse()
    newpattern = ""
    for element in R:
        newpattern += element + "/"
    newpattern = newpattern[:-1]
    return newpattern

# Given 'mic{***x12}' and "raw001.tmp" --> returns "raw{***x12}"
# The stars in pattern must be adjusted to match the filename.
# Should work for both 'mic{***x12}' and 'mic***' formats.
def fname2pattern(oldpattern, filename):
    #print "spiderBatform.fname2pattern: %s %s" % (oldpattern, filename)
    #  find all register patterns
    all = findRegister(oldpattern, all=1)
    if not all:
        return ""
    all.reverse()

    new = ""
    for pattern in all:
        nstars = count(pattern,"*")
        
        ndigits, index = countdigits(filename)
        if ndigits == 0:
            continue
        
        digits = filename[index:index+ndigits]

        if ndigits == nstars:
            new = filename.replace(digits, pattern)
            break
        elif ndigits > nstars:
            # add more stars to pattern
            incr = (ndigits - nstars) + 1
            incrstars = '*' * incr
            newpat = pattern.replace('*',incrstars,1)
            new = filename.replace(digits, newpat)
            break
        elif ndigits < nstars:
            # subtract stars from pattern
            decr = (nstars - ndigits)
            newpat = pattern.replace('*','',decr)
            new = filename.replace(digits, newpat)
            break
        
    return new


##########################################################################
#
# class BatchFile (and PythonBatchFile for batch.py files)
    
class BatchFile:
    """ Parses a file into register and filename lists.
        B = list of lines from readlines()
        groups: [name, [list of file tuples]], ..
    """
    def __init__(self, filename, B):
        self.filename = os.path.basename(filename)
        f, ext = os.path.splitext(filename)
        self.ext = ext
        self.dir = os.path.dirname(filename)
        self.fullname = truepath(filename)
        self.B = B  # full text of the file
        self.message = ""
        self.header    = self.getBatchHeader()
        #self.registers = self.getRegisters()
        self.registers = []
        self.groups    = self.getGroups()
        self.lastmodified = lastModified(filename)
        #self.printGroups()

    def getBatchHeader(self):
        """ Return all lines up to (not incl) 'END BATCH HEADER'
            Returns entire file if no EBH line """
        H = []
        found = 0
        for line in self.B:
            if len(line) > 0:
                if find(upper(line),GB.end_of_header) > -1:
                    found = 1
                    break
            H.append(line)
        if not found:
            self.message = "missing END BATCH HEADER comment\n"
        return H

    def findRegister(self, line):
        line = line.strip()
        if len(line) < 1:
            return None

        # if find the GLOBAL keyword
        if 'glo' == line.lower()[:3] :
            while len(line) > 0 and line[0] != " " and line[0] != "[":
                line = line[1:]
            return self.findRegister(line)
        
        if re_regs.match(line) or re_namedregs.match(line):
            # evaluate RHS of =
            rxr = line.split("=")
            rhs = rxr[1]
            if rhs.find(";"):
                value = rhs.split(";")[0].strip()
            else:
                value = rhs.strip()

            try:
                f = float(eval(value))
                return line
            except:
                return None
        
        else:
            return None

    def getRegisters(self):
        """ creates list of register tuples:
                   [(index, reg, value, label),...]
            NB: only gets the first time that register is set. """
        S = []
        i = 0
        # find lines where registers are set.
        for line in self.header:
            item = self.findRegister(line)
            if item:
                S.append((i, item))
            i = i + 1
                        
        R = []
        reglist = []
        # parse the register lines into [line_number, reg_name, value, comment]
        for item in S:
            index =  item[0] 
            line = item[1]
            register = line.split('=')[0].strip() # lower(line[0:3]) 
            if register in reglist:
                continue
            else:
                reglist.append(register)
            
            b = re_regs.search(line)
            if not b:
                b = re_namedregs.search(line)
            if not b:
                print "spiderBatform: unable to parse %s" % line
                continue
            s = line[b.end():]       # s has 'value ; comment'
            start_comment = find(s,';')
            if start_comment < 0:
                self.message += "line %s: %s needs a comment\n" % (index,line)
                value = strip(s)
                comment = "(NEEDS A COMMENT) %s =" % (register)
            else:
                value = strip(s[:start_comment])
                comment = strip(s[start_comment+1:])
            t = [index, register, value, comment]
            R.append(t)
        return R

    def checkForGlobal(self, symb):
        " see if symbol is preceded by GLOBAL keyword "
        sym = symb.strip()
        if 'glo' == sym.lower()[:3] :
            gword = ""
            while len(sym) > 0 and sym[0] != " " and sym[0] != "[":
                gword += sym[0]
                sym = sym[1:]
            sym = sym.strip()
            if len(gword) == 0:
                gword == None
            return sym, gword
        else:
            return sym, None
        

    def getGroups(self):
        """ processes '-- groupname --' => (groupname, startline) """
        Groups = []
        nogroup = 'needs a "--files--" comment'
        thisgroup = nogroup   # start a new group
        files = []

        # lines of interest:
        #  start with FR (G|L)
        #  start with ';' (comments)
        #  contain an equal sign (which may start with GLOBAL keyword)

        n = len(self.header)
        for i in range(n):

            line = strip(self.header[i])
            if len(line) == 0:
                continue
            
            if line[0] == ';':
                # if it's a group header line, start a new group
                b = re_group.search(line) # looks for "-- text --"
                if b:
                    # close up the current group
                    if len(files) > 0:
                        #for item in files:
                        #   print item
                        f = copy.deepcopy(files)
                        Groups.append([thisgroup, f])
                    # get the group name
                    p = b.start() + 2
                    q = b.end() - 2
                    thisgroup = strip(line[p:q])
                    files = []

            # if it's an FR command, add next line to 'files' list
            elif re_FRG.match(line):
                nline = strip(self.header[i+1])
                symbol,value,comment = symbolValueComment(nline)
                if symbol == "":
                    continue
                if symbol.find("=") > -1 or value.find("=") > -1:
                    GB.errstream('ERROR: equal sign in FR statement:','red')
                    GB.errstream("%d: %s" % (i+2,nline))
                    continue
                if comment == "":
                    comment = getComment(line)
                    if comment == "":
                        self.message += "line %d: %s needs a comment\n" % (i+1,nline)
                        comment = "(NEEDS A COMMENT)"
                files.append([i+1,value,comment,symbol, "FR"])

            # if it's a VAR assignment, add line to 'files' list
            elif line.find("=") > 0:   #re_namedregs.match(line):
                eq = line.find("=")  # comment may have equal sign
                symbol = line[:eq].strip()
                rhs = line[eq+1:].strip()

                c = rhs.find(";")
                if c > 0:
                    value = rhs[:c].strip()
                    comment = rhs[c+1:].strip()
                else:
                    value = rhs
                    self.message += "line %d: %s needs a comment\n" % (i,line)
                    comment = "(NEEDS A COMMENT)"
                symbol, globalprefix = self.checkForGlobal(symbol)
                if not globalprefix:
                    files.append([i,value,comment,symbol, "VAR"])
                else:
                    files.append([i,value,comment,symbol, globalprefix])

            else:
                """
                try:
                    symbol,value,comment = symbolValueComment(line)
                    if i > 0:
                        prevline = strip(self.header[i-1])
                        if not re_FRG.match(prevline):
                            GB.errstream('ERROR?: ill-formed assignment statement?:','red')
                            GB.errstream("%d: %s" % (i+1,line))
                except:
                    pass
                """
                pass # couldn't handle UD statements in refine_settings
            
        # finish up
        if len(files) > 0: Groups.append([thisgroup, files])

        if thisgroup == nogroup and len(Groups) > 0:
            self.message += 'FR commands need "--files--" comment\n'

        return Groups

    def printGroups(self):
        print "printGroups;"
        for group in self.groups:
            print group

# ---------------------------------------------------------------------
# PythonBatchFile uses __init__ and getBatchHeader from BatchFile class
class PythonBatchFile(BatchFile):

    def getGroups(self):
        "process groups in Python batch headers"
        Groups = []
        groupname = ""
        files = []

        i = 0
        for item in self.header:
            line = item.strip()
            if len(line) < 1:
                i += 1
                continue

            # if it's a group header line, start a new group
            if line[0] == '#' and re_group.search(line):
                # close up the current group
                if len(files) > 0:
                    f = copy.deepcopy(files)
                    Groups.append([groupname, f])
                line = line[1:]                     # remove comment char
                groupname = line.replace('-','').strip()  # remove hyphens
                files = []
                
            elif line.find('=') > -1:
                if groupname == "":  # assignment is outside a group label
                    continue
                d = line.split('=')     # inp = 'img****'  # test images
                symbol = d[0].strip()   # inp
                if d[1].find('#') > -1:
                    c = d[1].split('#')
                    value = c[0].strip()   # 'img****'
                    comment = c[1].strip()
                else:
                    value = d[1].strip()
                    comment = "(NEEDS A COMMENT)"
                    self.message += "line %d needs a comment\n" % (i,line)
                files.append([i,value,comment,symbol])
            i += 1
            
        # finish up
        if len(files) > 0: Groups.append([groupname, files])
        return Groups

    def getRegisters(self):
        "redefined in PythonBatchClass (all 'registers' are in groups)"
        return []

##########################################################################
#
# class BatchForm
#
# kwargs:
#    batchobj : a BatchFile object
#    geometry : result from window.geometry() ; (put a new window in same place)

class batchForm(scrolledForm):
    """ present registers and filename strings to user for editing """
    
    def processargs(self):
        if self.kwargs.has_key("geometry"):
            self.top.geometry(self.kwargs["geometry"])
        if self.kwargs.has_key("batchobj"):
            self.batobj = self.kwargs["batchobj"]
        if self.kwargs.has_key("displayFRhelp") and self.kwargs["displayFRhelp"]:
            self.helpmsg = """
            Filenames set with FR commands do not have quotes (brown text).\n
            Filenames set with equal sign are quoted, unless they are symbols.
            """
        else:
            return
        if self.batobj.message != "":
            displayError(self.batobj.filename+'\n'+ self.batobj.message)
                   
    def makeButtons(self, bfr):
        self.addButton(bfr, text="Save", command=self.save,
                       help = "write these values to %s" % (self.batobj.filename))
        self.addButton(bfr, text="Save as", command=self.saveas,
                       help = "Save with another name")
        self.addButton(bfr, text="Editor", command=self.edit,
                       help ="open in %s" % (GG.prefs.editor) )
        self.addButton(bfr, text="Cancel", command=self.localquit, side='right',
                       help = "exit without saving")

        execute = Button(bfr, text='Execute!', activebackground=execGreen,
                         command=self.runbatch)
        execute.pack(side='right',padx=GG.padx, pady=GG.pady)
        self.helpMessage(execute,"run %s in SPIDER" % (self.batobj.filename)) 
        
    def mkMainFrame(self):
        fform = self.fmain
        bat = self.batobj
        maxlabelwidth = 0
        borderx2 = 2 * GG.brdr
        commentchar = ';'
        if self.batobj.ext == '.py':
            commentchar = '#'

        """
        # Register group
        self.regentries = []
        if len(bat.registers) > 0:
            pmwgroup = Pmw.Group(fform, tag_text='Registers',
                                 ring_borderwidth='2')
            pmwgroup.component('ring').configure(borderwidth=borderx2)
            group = pmwgroup.interior()
            for reg in bat.registers:
                name = string.strip(reg[3])
                x = fontMeasure(name)
                if x > maxlabelwidth: maxlabelwidth = x
                
                f = Pmw.EntryField(group, labelpos = 'w',
                                   value = reg[2],
                                   label_text = name + ':',
                                   validate = {'validator' : 'real'})
                # attach balloon help
                self.helpMessage(f.component('label'),reg[1])
                self.regentries.append(f)
            for reg in self.regentries:
                reg.pack(fill='x', expand=1, padx=GG.pad2x, pady=GG.pady)
            Pmw.alignlabels(self.regentries, sticky='e')
            group.pack(fill='both', expand=1, padx=GG.padx, pady=GG.pady)
            pmwgroup.pack(fill = 'both', expand=1, padx=GG.padx, pady=GG.pady)
        """

        """ var groups """
        self.filentries = []
        for g in bat.groups:
            grpentries = []
            name = g[0]
            filelist = g[1]
            pmwgroup = Pmw.Group(fform, tag_text=name)
            pmwgroup.component('ring').configure(borderwidth=borderx2)
            group = pmwgroup.interior()
            #gframe = Frame(group) # so can use grid
            row = 0
            # symobj: [21, '../string_value', '; comment', '[symbol]', FR]
            for symobj in filelist:
                label = strip(symobj[2])
                if label == "":
                    label = "(**** NEEDS A COMMENT ****)"
                while label[0] == commentchar or label[0] == " ":
                    label = label[1:]
                    
                x = fontMeasure(label)
                if x > maxlabelwidth: maxlabelwidth = x

                ffr = Frame(group)
                ffr.pack(side='top', fill='x', expand=1)
                
                if symobj[-1] == "FR":
                    labtxt = ""
                    fgcolor = "#663033"
                else:
                    labtxt = "="

                value = symobj[1]
                
                if isSpiderFloat(value):
                    f = Pmw.EntryField(ffr, labelpos = 'w',
                                       value = value,
                                       label_text = symobj[2]) #,
                                       #validate = {'validator' : 'real'})
                    # attach balloon help
                    self.helpMessage(f.component('label'),symobj[3])
                    f.pack(side='top', fill='x', expand=1, padx=GG.pad2x, pady=GG.pady)
                    
                else:
                    f = Pmw.EntryField(ffr, labelpos = 'w',
                                       label_text = labtxt,
                                       value = symobj[1]) #,
                                       #validate = valid_quotes)
                    if symobj[-1] == "FR":
                        f.component('entry').configure(fg=fgcolor)
                        
                    b = Button(ffr, text=label,
                               command=Command(self.askfile,f,label))
                    
                    # attach balloon help to browse button
                    if len(symobj) > 3:
                        symbol = symobj[3]
                        self.helpMessage(b,symbol)

                    b.pack(side='left',padx=GG.padx, pady=GG.pady)
                    f.pack(side='left', anchor='w',fill='x',expand=1,
                           padx=GG.padx, pady=GG.pady)
                    
                
                seeEntry(f)
                grpentries.append(f)
                row += 1

           # Pmw.alignlabels(grpentries, sticky='e')

            #gframe.pack(fill='both', expand=1)
            group.pack(fill='both', expand=1, padx=GG.padx, pady=GG.pady)
            pmwgroup.pack(fill = 'both', expand=1, padx=GG.padx, pady=GG.pady)
            self.filentries.append(grpentries)

        #for g in bat.groups:
        #    name = g[0]
        #    filelist = g[1]
        #    print "name: " + name
        #    for item in filelist:
        #        print "    %s" % (str(item))

    def askfile(self,entry,label=None):
        " browses for a filename "
        if label == None: label = ""
        oldvalue = entry.getvalue().strip()
        quoted = 0
        if oldvalue[0] == '"' and oldvalue[-1] == '"': quoted = 1
        elif oldvalue[0] == "'" and oldvalue[-1] == "'": quoted = 1

        # start from batch file's directory
        if hasattr(self.batobj, 'dir'):
            chdir(self.batobj.dir)

        if label.lower().find('directory') > -1:
            getDir2(entry)
        else:
            if not getFile(entry):
                return
   
        # replace quotes, if necessary
        if quoted:
            newvalue = entry.getvalue().strip()
            entry.setvalue("'" + newvalue + "'")
        else:
            newvalue = entry.getvalue().strip()
            entry.setvalue(newvalue)

        # check for **** template patterns
        p = re_regpattern.search(oldvalue)   # {***x22} patterns
        if not p:
            p = re_stars.findall(oldvalue)   # mic*** patterns
        if p:
            newvalue = entry.getvalue()
            new = replacePatterns(oldvalue,newvalue,deleteExt=1)
            if new != -1:
                if quoted and new[-1] != "'":
                    new = new + "'"
                entry.setvalue(new)
            else:
                entry.setvalue(oldvalue)
        elif label.lower().find('template') > -1:
            displayError('SPIDER may expect a template\n' + \
                         'here, not an actual filename.', "Warning!")
            
        if os.path.dirname(os.path.abspath(oldvalue)) == os.path.dirname(newvalue):
            newvalue = os.path.basename(newvalue)
            
        seeEntry(entry)       

    def save(self, filename=None, saveas=0, quit=1):
        "saveas=1 indicates an old file is being overwritten"
        if filename == None:
           filename = self.batobj.fullname

        #print saveas
        kastmod = lastModified(filename)
        #print kastmod
        #print self.batobj.lastmodified

        if not saveas:
            lastmod = lastModified(filename) # returns zero if file does not exist
            if lastmod != 0 and lastmod > self.batobj.lastmodified:
                # then need to reflect changes
                msg = 'This file was modified by another process.\n' + \
                      'If you save, it will overwrite those changes.\n' + \
                      'Save to overwrite changes?'
                updateres = askYesorNo(msg, "File modified")
                #print updateres
                if updateres:
                    updateBatch(self.batobj, self)  # this will quit the window
                    return "update"

        # registers
        """
        i = 0
        newregs = []
        for reg in self.batobj.registers:
            oldvalue = reg[2]
            newvalue = self.regentries[i].getvalue()
            if oldvalue != newvalue:
                reg = [ "changed", reg[0], reg[1], newvalue, reg[3] ]
            i += 1
            newregs.append(reg)
        self.batobj.registers = newregs
        """
            
        """ filenames """
        i = 0
        for group in self.batobj.groups:
            filelist = group[1]  # the (index, value, comment) tuples
            gentries = self.filentries[i]
            i = i + 1
            e = 0
            for entry in gentries:
                newvalue = string.strip(entry.getvalue())
                filetup = filelist[e]
                oldvalue = filetup[1]
                if oldvalue != newvalue:
                    if self.batobj.ext == '.py':
                        new = ["changed", filetup[0], newvalue] + filetup[2:]
                    else:
                        new = ["changed", filetup[0], newvalue] + filetup[2:]
                    filelist[e] = new
                e += 1

        # write changes to text
        B = self.batobj.B
        commentchar = ';'
        if self.batobj.ext == '.py':
            commentchar = '#'
        """
        for reg in self.batobj.registers:
            if reg[0] == 'changed':
                lineno  = reg[1] # ['changed', 14, 'x74', '200', 'dist. from the edge (x)']
                x       = reg[2]
                value   = reg[3]
                comment = reg[4]
                comment = comment.strip()
                if comment[0] != commentchar:
                    comment = commentchar + ' ' + comment
                newstr = "%s = %s    %s\n" % (x,value,comment)
                B[lineno] = newstr
        """
        for group in self.batobj.groups:
            filelist = group[1]
            for file in filelist:
                if file[0] == 'changed':
                    # ['changed', 38, '2', 'comment', '[imgnum]', 'glo']
                    lineno = file[1]
                    value  = file[2]
                    comment = file[3]
                    comment = comment.strip()
                    if comment[0] != commentchar:
                        comment = commentchar + ' ' + comment
                    symbol = file[4]
                    if len(file) < 6:
                        print "error: %s" % str(file)
                        continue
                    varflag = file[5]
                    if varflag.lower()[:3] == 'glo':
                        symbol = "%s %s" % (varflag, symbol)
                    if varflag == "FR":
                        newstr = "%s%s   %s\n" % (symbol,value,comment)
                    else:
                        newstr = "%s = %s   %s\n" % (symbol,value,comment)
                    B[lineno] = newstr

        fileWriteLines(filename, B)
        GB.outstream("Changes saved to %s" % filename)

        if quit != 0:
            self.localquit()
        else:
            return ""

    def saveas(self):
        filename = askSaveAsFilename()  #askfilename()
        if filename == "":
            return
        res = self.save(filename=filename, saveas=1)

    def edit(self):
        filename = os.path.join(self.batobj.dir,self.batobj.filename)
        fileEdit(filename)

    def runbatch(self):
        " saves, quits, then runs batch file "
        res = self.save(quit=0)
        #print "spiderBatform.runbatch.res: %s" % str(res)
        if res == 'update':
            return
        dir = self.batobj.dir
        cmdlist = [self.batobj.filename]
        #GG.topwindow.after(500,spiderBatch.runbatch([dir,cmdlist]))
        spiderBatch.runbatch([dir,cmdlist])
        self.localquit()

    def localquit(self):
        del(self.batobj)  # remove instance object
        self.quit()

# end class BatchForm --------------------------------------------------

def getBatch(filename=None):
    " read a batch file and create a batch object, then create a form "
    if filename == None:
        filename = askfilename()
    if filename == "":
        return
    B = fileReadLines(filename)
    if B == None: return
    if not isPython(filename):
        bat = BatchFile(filename,B)  # create instance
    else:
        bat = PythonBatchFile(filename,B)
    
    batdir = bat.dir

    if batdir == '.':
        batdir = GB.P.projdir
    bf = batchForm(batchobj=bat, title=bat.filename,
                   subtitle="directory: %s" % (batdir),displayFRhelp=1)

def updateBatch(batobj, batform):
    " reread a file that's been changed by an external editor "
    filename = batobj.fullname
    #print "updateBatch : " + filename
    del(batobj)    # get filename and delete old object
    B = fileReadLines(filename)
    if B == None: return
    #print B
    bat = BatchFile(filename,B)  # create new batch object instance

    geo = batform.top.geometry()  # get the current form's window location
    batform.quit()                # destroy old window

    bf = batchForm(batchobj=bat, geometry=geo,
                   title=bat.filename,
                   subtitle="directory: %s" % (bat.dir),
                   displayFRhelp=1)
                            

#-----------------------------------------------------------------
if __name__ == '__main__':

    if len(sys.argv[1:]) > 0:
        filename = sys.argv[1]
    else:
        print "Usage: spiderBatform.py batchfile"
        sys.exit()
        
    B = fileReadLines(filename)
    if B == None: sys.exit()

    b = BatchFile(filename,B)
    for i in b.registers:
        print i
    for i in b.groups:
        print i[0]
        for line in i[1]: print line

    print b.message
