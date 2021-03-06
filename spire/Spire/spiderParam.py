# $Id: spiderParam.py,v 1.3 2012/08/03 01:26:14 tapu Exp $
#
# Handles project parameters, param file and form

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
import os, re

from   Tkinter import *
import Pmw

import GG
from spiderUtils import *
from spiderGUtils import *
from spiderFtypes import istextfile, isSpiderDocfile
from spiderClasses import scrolledForm


######################################################################
#
#   PARAMETERS
#

"""
GB.P.parameters is a dictionary,
it has the current values read from/saved to GG.sysprefs.paramFile

The parameter dictionary keys are integers,
values are string versions of floats, and
comments may contain square-bracketed lists.
Contents are lists with 3 or 4 values (latter have drop-down lists)
PD = { key1 : [key1, value, comment],
       key2 : [key2, value, comment, [list of choices]]
       }

When a new project is started, spiderConfig.readXMLConfig checks if
there are default values under the <Parameters> tag.
For existing projects, parameters are always in GG.sysprefs.paramFile,
and are not saved to the local configuration.

June 8, 2005: Using new format for parameter doc files:

 ;spi/hcc   01-JUN-2005 AT 15:03:45   params.hcc
    1 1    0.000000     ;   zip flag ['do not unzip', 'unzip']
    2 1    0.000000     ;   file format ['SPIDER','HiScan', 'ZI scanner']
    3 1    0.000000     ;   width (pixels)
    4 1    0.000000     ;   height (pixels)
    5 1    4.780000     ;   pixel size (A)
    6 1  100.000000     ;   electron energy (kV)
    7 1    2.000000     ;   spherical aberration (mm)
    8 1    0.000000     ;   source size (1/A)
    9 1    0.000000     ;   source size (1/A)
   10 1    0.000000     ;   astigmatism (A)
   11 1    0.000000     ;   azimuth (degrees)
   12 1    0.100000     ;   amplitude contrast ratio (0..1)
   13 1 10000.000000    ;   Gaussian envelope halfwidth (1/A)
   14 1    0.037013     ;   lambda
   15 1    0.104603     ;   max. spatial frequency
   16 1    1.000000     ;   decimation factor
   17 1   75.000000     ;   window size (pixels)
   18 1   52.000000     ;   particle size (pixels)
   19 1    0.000000     ;   magnification
   20 1    0.000000     ;   scanning resolution (in microns:7,14,etc)

or a simple space-delimited text format is ok:
    1   0     zip flag    ['do not unzip', 'unzip']
    2   0.    file format ['SPIDER','HiScan', 'ZI scanner']
    4   0.0   height (pixels)
    5   4.78  pixel size (A)
    6   100   electron energy (kV)
    7   2     spherical aberration (mm)

In both cases, square bracket-delimited lists are interpreted as drop-down menus
"""

# given : 'program <parameter name="cs"/> <parameter name="kv"/>'
# returns "program 2.26 300"
def replaceTagwithParam(s):
    n = s.replace('<prog>',"")
    s = n.replace('</prog>',"")
    csval, kvval, pixsizeval = get_Cs_kv_pixsize()

    pcs = '<parameter name="cs"/>'
    if s.find(pcs) > -1 and csval != "":
        s = s.replace(pcs, csval)
        
    pcs = '<parameter name="kv"/>'
    if s.find(pcs) > -1 and kvval != "":
        s = s.replace(pcs, kvval)
                                                      
    pcs = '<parameter name="pixelsize"/>'
    if s.find(pcs) > -1 and pixsizeval != "":
        s = s.replace(pcs, pixsizeval)

    pcs = '$DATEXT'
    if s.find(pcs) > -1 and GB.P.dataext != "":
        s = s.replace(pcs, GB.P.dataext)
#        print "Replacing ",pcs," with ",GB.P.dataext  # will print to console

    return s

def get_Cs_kv_pixsize():
    " returns (cs, kv, pixsize) "
    cs = kv = pixsize = ""
    if hasProject() and hasattr(GB.P, 'parameters'):
        #print "in get_Cs_kv_pixsize"
        pdict = GB.P.parameters
        keys = pdict.keys()
        #for k in keys:
        #   print "%s" % str(pdict[k])
        for k in keys:
            d = pdict[k]
            if len(d) < 3: continue
            comment = d[2].lower()
            if comment.find('spherical aberration') > -1:
                cs = trim_zeroes(d[1])
            elif comment.find('electron energy') > -1:
                kv = trim_zeroes(d[1])
            elif comment.find('pixel size') > -1 or comment.find('pixelsize') > -1:
                pixsize = trim_zeroes(d[1])
    return (cs, kv, pixsize)

# findBrackets: used by readParamTextfile to get drop-down menus
def findBrackets(s):
    " given a comment with brackets : zip flag ['do not unzip', ' unzip'] "
    " returns (comment, list)   or (comment, None) if no brackets "
    s = s.strip()
    # look for end bracket
    if s[-1] != ']': return (s, None)
    lb = s.rfind('[')
    if lb < 0: return (s, None)
    
    comment = s[:lb].strip()
    dlist = s[lb:]

    # dlist must have at least 2 items separated by comma
    if dlist.find(',') < -1: return (s, None)
    choices = None
    
    # string "['thing1', 'thing2']" must be converted to python list.
    # If they're already quoted, just eval the string
    try:
        choices = eval(dlist)
    except:
        # no quotes? convert to list
        dlist = dlist[1:-1]  # remove brackets
        d = dlist.split(',')
        choices = []
        for item in d:
            choices.append(item)

    if comment[-1] == ',':
        comment = comment[:-1].strip()

    return (comment, choices)

# readParamTextfile reads either a text file or doc file, (or list of lines)
# returns Parm dictionary
def readParamTextfile(parmfile=None, parmlist=None):
    " returns parameter dictionary, or None "
    if parmlist == None:
        B = fileReadLines(parmfile)
    else:
        B = parmlist
    PD = {}
    key = val = comment = None

    for line in B:
        if line.strip() == "": continue
        d = line.split()
        if len(d) < 3:
            print "spiderParam: cannot process line: %s" % line
            return None
        
        # First try Spire comment format:  int  '1'  float  ';'  string
        if len(d) > 4 and d[1] == '1' and d[3][0] == ';':
            try:
                key = int(d[0])
                val = d[2]
                a = line.find(';')
                comment = line[a+1:].strip()
            except:           
                print "spiderParam: unable to process: %s" % line
                return None
        # Try standard doc comment format: " ; / comment"
        elif line[1] == ';' and line[3] == '/':
            comment = line[4:].strip()
        else:
            try:
                key = int(d[0])
                val = float(d[2])
            except:
                # see if it's a simple (non-doc) text file: key value comment
                try:
                    key = int(d[0])
                    val = float(d[1])
                    comment = ""
                    for word in d[2:]:
                        comment += word + " "
                except:
                    pass

        if key != None and val != None and comment != None:
            # look for square brackets denoting drop-down menus
            comment, choices = findBrackets(comment)
            if choices != None:
                parm = [key, val, comment, choices]
            else:
                parm = [key, val, comment]
            PD[key] = parm
            key = val = comment = None

    return PD
        

# called by button in Main window
def readParmFile(filename=None, window=None):
    if window != None and window.winfo_exists():
        window.destroy()
    if filename == None:
        filename = askfilename()
    if filename == "":
	return

    parmdict = readParamTextfile(filename)
    if parmdict == None or len(parmdict) == 0:
        displayError("Unable to get parameters from %s" % filename, 'file read error')
        return

    GB.P.parameters = parmdict
    presentParmForm()

def presentParmForm(parmdict=None):
    if parmdict != None:
        GB.P.parameters = parmdict
    pf = parmForm(wintitle='SPIDER Parameters',
                  title='Project Parameters')

def saveParmdict2File(parmdict=None, filename=None):
    if parmdict == None:
        parmdict = GB.P.parameters
    if filename == None:
        filename = askSaveAsFilename(initialfile=GG.sysprefs.paramFile)
        if filename == "":
            return
        #print "saveParmdict2File", filename
        #print "saveParmdict2File", GG.sysprefs.paramFile
        
    hdr = makeDocfileHeader(filename, batext='spi')
    filep = open(filename, 'w')
    filep.write(hdr)
    keys = parmdict.keys()
    keys.sort()
    for k in keys:
        parm = parmdict[k]
        key = int(parm[0])
        value = float(parm[1])
        comment = "    ; " + parm[2]
        if len(parm) > 3:
            comment += " " + str(parm[3])
            
        pstr = "%5d 1 %11f %s\n" % (key, value, comment)
        filep.write(pstr)
    filep.close()
    GB.outstream("values saved to %s" % filename)

def setProjectParms():
    " sets  GB.P.Cs, GB.P.kv, GB.P.pixelsize if they're in parameters " 
    keys = GB.P.parameters.keys()
    for k in keys:
        parm = GB.P.parameters[k]   # [key, float, comment]
        comment = parm[2].lower()
        if  comment.find('spherical aberration') > -1 and comment.find('(mm)') > -1:
            GB.P.Cs = parm[1]
            #print "setting GB.P.Cs to %s" % parm[1]
        elif  comment.find('electron energy') > -1 and comment.find('(kv)') > -1:
            GB.P.kv = parm[1]
            #print "setting GB.P.kv to %s" % parm[1]
        elif  comment.find('pixel size') > -1 and comment.find('(a)') > -1:
            GB.P.pixelsize = parm[1]
            #print "setting GB.P.pixelsize to %s" % parm[1]

def askParmNew(outputfile):
    win = newWindow('Read parameters from a file')
    f1 = Frame(win, background=GG.bgd01, relief=GG.frelief, borderwidth=GG.brdr)
    txt  = "To create a new parameter file,\n"
    txt += "Spire needs a list of parameters.\n\n"
    txt += "Read parameters from an old file,\n"
    txt += "and write them to %s?" % os.path.basename(outputfile)
    lbl= Label(f1, text=txt, background=GG.bgd01, anchor=W, justify='left')
    lbl.pack(padx=5, pady=5)
    f1.pack(side='top', fill='both', expand=1)

    f2 = Frame(win, relief=GG.frelief, borderwidth=GG.brdr)
    ok = Button(f2, text='OK', command=lambda w=win: readParmFile(window=w))
    ok.pack(side='left', padx=3, pady=3)
    cancel = Button(f2, text='cancel', command=win.destroy)
    cancel.pack(side='right', padx=3, pady=3)
    f2.pack(side='top', fill='x', expand=1)

def parmNew(defaultfile=None):
    " parmNew -> askParmNew -> readParmFile -> presentParmForm "
    if not hasattr(GB,'P'):
        displayError('Please open a project.', 'New Project')
        return
    if not chdir(GB.P.projdir):
        return

    if defaultfile == None:
        parmfile = os.path.join(GB.P.projdir,GG.sysprefs.paramFile)
    else:
        parmfile = defaultfile
    GG.sysprefs.paramFile = parmfile
    parmOpen()   #askParmNew(parmfile)


def getProjDir():
    dir = ""
    if hasattr(GB,'P'):
        dir = GB.P.projdir
    if dir == "" or os.path.exists(dir) != 1:
        askstr = "Unable to find project directory.\n Please open a valid project."
        displayError('Error',askstr)
    return dir


def parmOpen():
    if not hasProject():
        displayError('Please open a project.')
        return
    dir = getProjDir()
    if dir == "" or chdir(dir) == 0: return

    parmfile = GG.sysprefs.paramFile
    if not os.path.exists(parmfile):
        askstr = "Unable to find parameter file\n '%s'\nCreate a new one?" % parmfile
        if askOKorCancel(askstr,'Error'):
            pf = parmForm(wintitle='SPIDER Parameters',
                          title='Project Parameters', new=1)
        return
    else:
        if istextfile(parmfile) and isSpiderDocfile(parmfile):
            pass
        else:
            displayError('%s\n does not appear to be a SPIDER doc file' % parmfile)
            return	

    GB.P.parameters = readParamTextfile(parmfile)

    pf = parmForm(wintitle='SPIDER Parameters',
                  title='Project Parameters',
                  subtitle=projFilename(GG.sysprefs.paramFile), new=0)

# autoBindings must be tailored to the specific parameter file.
def pixsizeAutoBindings(event=None,entries=None):
    pixelsize = maxspatfreq = windowsize = actualsize = None
    for entry in entries:
        label = entry.cget('label_text')
        if label.find('pixel size') > -1:
            pixelsize = entry
        elif label.find('spatial frequency') > -1:
            maxspatfreq = entry
        elif label.find('window size') > -1:
            windowsize = entry
        elif label.find('particle size') > -1:
            actualsize = entry
            
    winvalue = 368.0 # Angstroms. default values
    actvalue = 250.0
    if pixelsize:
        p = pixelsize.get()
        try:
            if type(p) == type(['list']):
                p = p[1]
            p = float(p)
            if p != 0:
                w = int(winvalue/p)
                if w%2 == 0: w += 1 # make window size odd
                a = int(actvalue/p)
                if windowsize: windowsize.setentry(str(w))
                if actualsize: actualsize.setentry(str(a))
                km = 1.0 / (2.0 * p)
                if maxspatfreq: maxspatfreq.setentry(str(km))
        except:
            displayError("Error computing pixels size.\nPlease enter a valid pixel size", "Error")
            #print p

def kvAutoBindings(event=None,entries=None):
    import math
    for entry in entries:
        label = entry.cget('label_text')
        if label.find('electron energy') > -1:
            energy = entry
        elif label.find('lambda') > -1:
            lamda = entry
    #energy = entries[3]
    #lamda = entries[11]
    try:
	kv = energy.get()
	if type(kv) == type(['list']):
            kv = kv[1]
        kv = float(kv)
	if kv != 0:
	    k = 12.398 / (math.sqrt(kv * (1022.0 + kv)))
	    s = str(k)
	    i = s.find('.')
	    #Sif i > -1 and 
	    lamda.setentry(str(k))
    except:
	displayError("Please enter a valid value for electron energy", "Error")

###################################################################
#

class parmForm(scrolledForm):
    
    def makeButtons(self, bot):
        self.addButton(bot, text='OK', command=self.parmSave)
        self.addButton(bot, text='Cancel', command=self.quit, side='right')

	saveButtonState = 'normal'

    def processargs(self):
        self.new = 0
        if self.kwargs.has_key('new'):
            self.new = self.kwargs['new']

    def mkMainFrame(self):
	fr1 = self.fmain

        if hasProject() and GB.P.parameters:
            parmdict = GB.P.parameters
        else:
            parmdict = GB.DP
        self.parmdict = parmdict

	# Fill the frame with labels and entries.
	entries = []
	keys = parmdict.keys()
	keys.sort()
	entrywidth = 12
	maxlabelwidth = 0
	focusentry = None

	for key in keys:
	    item = parmdict[key]
	    value = item[1]
	    name = item[2].strip()
	    if name == "":
                print "skipping %s" % str(item)
                continue

            x = fontMeasure(name)
	    if x > maxlabelwidth:
                maxlabelwidth = x
                   
	    if len(item) == 3:            # entry field
		F = Pmw.EntryField(fr1,
			    labelpos = 'w',
			    value = value,
 			    label_text = name + ':')
	    elif len(item) == 4:          # menu
		menulist = item[3]
		F = Pmw.ComboBox(fr1,
			    label_text = name + ':',
			    labelpos='w',
			    dropdown=1,
			    scrolledlist_items = menulist)
		selection = int(float(item[1]))
		F.selectitem(menulist[selection])

	    F.parmkey = key    # associate the key with the widget
	    
	    # bindings for autocalculation of window size from pixel size
	    if name.find('pixel size') > -1:
                F.bind('<FocusOut>',
                       lambda event,e=entries:pixsizeAutoBindings(event,e))
                focusentry = F
                if hasProject():   # see if it got pixsize from database
                    px = str(GB.P.pixelsize)                   
                    if px != None and px != "":
                        F.setvalue(px)
                        dopixsize = 1
                    else:
                        dopixsize = 0
	    if name.find('electron energy') > -1:
                F.bind('<FocusOut>',
 		    lambda event,e=entries:kvAutoBindings(event,e))
                if hasProject():
                    kv = str(GB.P.kv)
                    if GB.P.kv != None and GB.P.kv != "":
                        F.setvalue(kv)
                        dokv = 1
                    else:
                        dokv = 0
                
	    entries.append(F)

	if not self.new:
            dopixsize = 0
            dokv = 0

	if dopixsize:
            pixsizeAutoBindings(entries=entries)
        if dokv:
            kvAutoBindings(entries=entries)

	for entry in entries:
	    label = entry.component('label')
	    if label != "" :
		entry.pack(fill='x', expand=1, padx=10, pady=4)
	Pmw.alignlabels(entries, sticky='e')

	self.entries = entries

    def parmSave(self):
        GG.sysprefs.paramFile = addExtension(GG.sysprefs.paramFile,GB.P.dataext)
	filename = os.path.join(GB.P.projdir,GG.sysprefs.paramFile)
	P = []
        parmdict = self.parmdict

	# insert the new values from the form into the Parm object
	for F in self.entries:
	    key = F.parmkey
            if not parmdict.has_key(key):
                print "parmsave key = %s" % str(key)
	    item = parmdict[key]
	    # eg item[4] = [5, '4.780000', 'pixel size (A)']
	    newval = F.get()
	    
	    if len(item) == 3:
                f = float(newval)
                item[1] = newval  # insert the new value as a string
            elif len(item) == 4: # then it's a menu
                k = item[3].index(newval)
                item[1] = str(k)

	    if hasProject():
                GB.P.parameters[key] = item
	    P.append(item)

        # write the output to a doc file
        localparam = os.path.split(addExtension(GG.sysprefs.paramFile,GB.P.dataext))[1]
        currentparam = os.path.join(GB.P.projdir,localparam)
        #saveParmdict2File(parmdict=parmdict, filename=GG.sysprefs.paramFile)
        saveParmdict2File(parmdict=parmdict, filename=currentparam)

        # set GB.P.Cs, GB.P.kv, GB.P.pixelsize
        setProjectParms()
        self.top.destroy()

#  end class parmForm
#######################################################################
