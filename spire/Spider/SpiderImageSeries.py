# SpiderImageSeries.py : utilities to load SPIDER images as PIL images.
#
# Spider Python Library
# Copyright (C) 2006, 2010 Health Research Inc.
#
# HEALTH RESEARCH INCORPORATED (HRI),
# ONE UNIVERSITY PLACE, RENSSELAER, NY 12144-3455
#
# Email:  spider@wadsworth.org
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.

from Tkinter import *
import Pmw
import Image
from Spider.Spiderutils import *
from Spider.Spiderarray import spider2array, array2image
try:
    import numpy
    _HAS_NUMPY_ = 1
except:
    try:
        import Numeric
        _HAS_NUMPY_ = 0
    except:
        print "Unable to import numpy, the scientific library for Python"
        #sys.exit()
 

def filenames2numbers(flist):
    " given ['mic001.dat, mic002.dat,..] --> returns [1,2,..]"
    if len(flist) == 0: return []
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

class askWindow:
    def __init__(self, n, startVar, endVar, win=None):
        self.win = win
        self.n = n
        self.startVar = startVar  # IntVars
        self.endVar = endVar
        self.displayVar = StringVar()
        
        f1 = Frame(self.win)
        f1.pack(side='top')
        f2 = Frame(self.win)
        f2.pack(side='top', fill='x')
        Label(f1, text="There are %d images" % n).pack(side="top", fill='x', pady=2)
        self.rb = Radiobutton(f1, text="Display all of them", value="all",
                         variable=self.displayVar, command=self.setall)
        self.rb.pack(side='top', anchor='w', pady=4)
        g = Pmw.Group(f1, tag_pyclass = Radiobutton,
                      tag_text = "Display some of them",
                      tag_value = "some",
                      tag_variable=self.displayVar)
        #print dir(g)
        g.pack(side="top", expand='yes', fill='both', padx=4, pady=4)
        self.displayVar.set("all")
        
        self.start = Pmw.EntryField(g.interior(), labelpos='w', label_text='start',
                               value= '1')
        self.end = Pmw.EntryField(g.interior(), labelpos='w', label_text='end',
                               value= str(n))
        self.start.pack(side='left', padx=4, pady=4)
        self.end.pack(side='right', padx=4, pady=4)
        self.sometag = g.component("tag")
        self.sometag.configure(command=self.setsome)
        self.start.component("entry").bind('<FocusIn>', self.setsome2)
        self.end.component("entry").bind('<FocusIn>', self.setsome2)

        ok = Button(f2, text="OK", command=self.setvars)
        ok.pack(side='left', padx=4, pady=4)
        quit = Button(f2, text="Cancel", command=self.cancel)
        quit.pack(side='right', padx=4, pady=4)

    def setall(self):
        self.start.setentry('1')
        self.end.setentry(str(self.n))
        self.rb.focus_set()

    def setsome(self):
        self.start.component("entry").focus_set()

    def setsome2(self, event):
        self.displayVar.set("some")

    def setvars(self):
        if self.displayVar.get() == "all":
            self.startVar.set(1)
            self.endVar.set(self.n)
        else:
            self.startVar.set(self.start.getvalue())
            self.endVar.set(self.end.getvalue())
        self.win.destroy()
            
    def cancel(self):
        self.startVar.set(0)
        self.endVar.set(0)
        self.win.destroy()

def getImageRange(n, size, top=None, interactive=1):
    " test if the number of images (n) will fit on-screen "
    xim, yim = size[0], size[1]  # image size
    hasgui = 0
    # if gui present, get screen width from Tkinter
    if top is not None:
        try:
            xmax, ymax = top.winfo_screenwidth(), top.winfo_screenheight()
            hasgui = 1
        except:
           print "ERROR: Widget passed into loadImageSeries must be a container"
           return None
    else:
        xmax = 1280  # if no gui, just use reasonable size
        ymax = 1024
        
    ncols = xmax/xim
    nrows = ymax/yim
    nxn = (ncols*nrows)
    #print ncols, nrows, xim, yim
    #print nxn, n
    if (ncols*nrows) > n:  # they'll fit on the screen
        return (1,n)

    if not interactive:
        return None

    # else ask user
    if hasgui:
        startVar = IntVar()
        endVar = IntVar()
        win = Toplevel(top)
        win.title("specify image series")
        aw = askWindow(n, startVar, endVar, win=win)
        win.wait_window(win)
        start = startVar.get()
        end = endVar.get()
        return (start,end)
    else:
        print "There are %d images. Display them all or a subset? (-1 = use all)" % n
        start = raw_input("start image:")
        if start == "-1": return (1,n)
        end = raw_input("end image:")
        if end == "-1": return (1,n)
        if start == "": start = 1  # default values
        if end == "": end = n
        try:
            s = int(start)
            e = int(end)
            return (s,e)
        except:
            return None

def isNumberRange(arg):
    " checks if string is pattern: int-int"
    if '-' in arg:
        a = arg.split("-")
        if len(a) > 1:
            try:
                a0 = int(a[0])
                a1 = int(a[1])
                return (a0,a1)
            except:
                return 0
    return 0

   
# Given a list of filenames, return a list of PIL images.
# Checks if file is stack or volume.
# If gui present (parent != None), checks if images will fit on screen.
#        If not, then asks for start, end.
# If byte == 1, run convert2byte on Spider files .

def loadImageSeries(filelist=None, parent=None, byte=1, istart=None, iend=-1,
                    verbose=1, DISPLAY_ALL=None):
    " create a list of PIL images from SPIDER files "
    
    print "Hunting " 
    
    if filelist == None or len(filelist) < 1:
        return []

    # see if the first filelist argument is a flag or range (overrides istart?)

    firstarg = filelist[0]
    if firstarg == '-a' or firstarg == '-1':
        if verbose: print "displaying all..."
        DISPLAY_ALL = 1
        filelist = filelist[1:]
        istart=1; iend=len(filelist)
    elif isNumberRange(firstarg):
        istart,iend = isNumberRange(firstarg)
        DISPLAY_ALL = 0
        filelist = filelist[1:]

    # check the first file, to see if exists, is stack, or is volume
        
    Nfiles = len(filelist)
    if Nfiles < 1: return []
    file = filelist[0]
    if not os.path.exists(file):
        print "unable to find %s" % file
        return []

    print "Found %s" % file
    
    
    
    info = spiderInfo(file)
    if info:
        type, size = info[0], info[1]
    else:
        type = 'non-spider'
        try:
            im = Image.open(file)
            size = im.size
        except:
            size = (100,100) # placeholder

    if type == "volume":
        Nimages = size[2]
    elif type == "stack":
        hdr = getSpiderHeader(filelist[0])
        Nimages = int(hdr[26])
    else:
        Nimages = Nfiles
    if DISPLAY_ALL == 1:
        istart = 1
        iend = Nimages

    # IF start,end not set by first argument in filelist, see if they will
    # fit onscreen. Get number of images; if too many to fit, get start, end images.
    if DISPLAY_ALL == None:
        if istart == None:
            if verbose: print "computing if images will fit on screen..."
            res = getImageRange(Nimages, size, parent)
            if not res:
                return []
            istart, iend = res
            
    if istart==0: istart=1  # use Spider indexing

    # Load the SPIDER files as PIL images
    imglist = []

    # ----------------------------------------------
    if type == "image" or type == "non-spider":
        newlist = filelist[istart-1:iend]    # SHOULD USE FILE NUMBERS??!!!
        for file in newlist:
            if not os.path.exists(file):
                print "Unable to find %s" % file
                continue
            try:
                im = Image.open(file)
                if byte and im.format == 'SPIDER':
                    im = im.convert2byte()
                else:
                    im = Image.open(file)
                im.info['filename'] = os.path.basename(file)
                imglist.append(im)
            except:
               print "Unable to sleep:: %s" % file
               print "Unable to load:: %s" % file

    # ----------------------------------------------
    elif type == "stack": 

        basename = os.path.basename(file)
        try:
            im = Image.open(file)
            ni = im.nimages
            s1 = istart - 1 # go from SPIDER 1 to Python 0
            if iend > s1 and iend < ni:
                s2 = iend   # don't subtract 1, cos used by range()
            else:
                s2 = ni
            for i in range(s1,s2):   #ni):
                im.seek(i)
                im.info['filename'] = "%s@%d" % (basename[:-4], i+1)
                #im.info['filename'] = str(i+1)
                if byte:
                    imglist.append(im.convert2byte())
                else:
                    imglist.append(im)
        except:
           print "Error trying to load SPIDER stack " + file
           return []

    # ----------------------------------------------
    elif type == "volume":
        
        V = spider2array(file)  # V is a 3D numpy array
        N = V[istart-1:iend]
        if byte:
            V = N
            amax = max(V.flat) # flatten to 1D array to get extrema
            amin = min(V.flat)
            if amax == amin:
                print "*** Error: volume slices contain constant data"
                return []
            m = 255.0 / (amax-amin)
            b = -m * amin
            if _HAS_NUMPY_:
                N = ((m*V)+b).astype(numpy.uint8) # mV+b returns an array
            else:
                N = ((m*V)+b).astype(Numeric.UnsignedInt8) 
        
        zsize, ysize, xsize = N.shape
        for z in range(zsize):
            im = array2image(N[z])
            im.info['filename'] = str(z+1 + istart-1)
            imglist.append(im)

    return imglist

# =======================================================================
if __name__ == "__main__":

    print 'Use: "spiderImageSeries.py -n files* " to turn off GUI'

        
    if sys.argv[1:]:
        filelist = sys.argv[1:]
    else:
        filelist=None

    if filelist[0] == '-n':
        filelist = filelist[1:]
	print "loatin"
        imglist = loadImageSeries(filelist)
        print imglist
    else:
        root = Tk()
	print "dandjfkadsjfkj"
        imglist = loadImageSeries(filelist=filelist, parent=root)
        root.mainloop()
    
