#!/usr/bin/env python

# SOURCE:  qview.py
# PURPOSE: diplay a SPIDER image
# 
# Spider Python Library
# Copyright (C) 2006  Health Research Inc.
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

"""
qview.py : quick python viewer, for other applications to send image data to.

qview.py image.dat
    - opens a window displaying the image (or images - wildcards accepted)

qview.py -s image.dat
    - starts a thread with a server listening on a port.
      Subsequent calls of "qview.py -s img" will put the new image in the
      already open window (and then exit).
      Server thread stopped by sending 'qview.py _exit_', since the thread
      sits at WAIT line waiting for input.

      See echo-client.py, echo-server.py in Programming Python p 526 ff
"""

import os, sys, threading
from   socket import *
import time

from   Tkinter import *
from   tkMessageBox   import askyesno
import Pmw, tkMessageBox
import Image, ImageTk
#from   Spider import Spiderutils, SpiderImageSeries
from   support import Spiderutils, SpiderImageSeries


serverHost = 'localhost'
serverPort = 50527
EXIT       = '_exit_'

########################################################################
# Server : listens on a port for an image filename
#

class Server(threading.Thread):
    
    def __init__(self, gui):
        self._stopevent = threading.Event()
        threading.Thread.__init__(self)
        self.host = ''
        self.port = serverPort
        self.gui = gui
        self.quitflag = 0

    def run(self):
        # start the server
        self.sockobj = socket(AF_INET, SOCK_STREAM)  
        self.sockobj.bind((self.host, self.port))   
        self.sockobj.listen(5)

        while 1:
            # WAIT : thread waits here for next sockobj.send cmd
            self.connection, address = self.sockobj.accept() 
            
            while 1:
                data = self.connection.recv(1024)
                if not data: break
                data = data.strip()
                if data == EXIT:
                    quitflag = 1
                else:
                    self.connection.send('qview.py: ' + data) 
                    self.gui.addImage(data)
                if self.quitflag:
                    break
                
            self.connection.close()
            if self.quitflag:
                break


########################################################################
# Graphical Interface
#

class QuickWindow:
    " imglist is a list of Image.images; useserver should be 0"
    " filename is the file being sent to the server; useserver should be 1"
    def __init__(self, master, imglist=None, filename=None, useserver=0):
        # start the graphical window
        self.top = master
        self.top.title("qview")
        self.top.protocol("WM_DELETE_WINDOW", self.quit)
        self.IM = {}  # a dictionary of images, indexed by numbers
        
        if filename != None:  # starting a new server
            im = self.filename2image(filename)
            if im == None:
                print "Unable to load %s" % filename
                return
            self.IM['0'] = im

            bw = 2    # server has a small border
            bordercolor = 'blue'
            self.useserver = 1
            self.server = Server(gui=self)
            self.server.start()
            
        elif imglist != None:   # no server, just the image viewer
            i = 0
            for im in imglist:
                self.IM[str(i)] = im
                i = i + 1
            self.useserver = 0
            bw = 0  # no border
            
        self.min = 0
        self.max = len(self.IM.keys()) - 1

        self.filelabel = Label(self.top, text="")
        self.filelabel.pack(side='top', expand=1, fill='x')

        self.label = Label(self.top, bd=bw)
        self.label.pack(side='top', expand=1, fill='both')
        
        self.current = self.min
        self.screenx, self.screeny = self.top.winfo_screenwidth(), self.top.winfo_screenheight()
        self.putimage()

        if useserver:
            self.label.configure(background=bordercolor)

        # set up the arrow key bindings
        self.top.bind_all('<Right>', self.displaynext)
        self.top.bind_all('<Left>', self.displayprev)
        self.top.bind_all('<Up>', self.displayffwd)
        self.top.bind_all('<Down>', self.displayback)
        self.top.bind_all('<space>', self.displaynext)
        self.top.bind_all('<BackSpace>', self.displayprev)

    def filename2image(self, filename): 
        try:
            im = Image.open(filename)
            im.info['filename'] = os.path.basename(filename)
            return im
        except:
            return None

    def putimage(self):
        index = str(self.current)
        im = self.IM[index]
        #check the size before we start processing
        w,h = im.size
        filename = im.info['filename']
        if w > self.screenx or h > self.screeny:
            askmsg = "%s is %d by %d pixels!" % (filename, w, h)
            askmsg = askmsg + "\nAre you sure you want to display it?"
            if not askyesno("Warning!", askmsg):
                self.displaynext()
                return
                
        if im.format == 'SPIDER':
            im = im.convert2byte()
            self.photo = ImageTk.PhotoImage(im, palette=256)
        else:
            self.photo = ImageTk.PhotoImage(im)
            
        self.label.configure(image=self.photo)
        self.filelabel.configure(text=filename)
        self.top.update_idletasks()

    def addImage(self, filename):
        " used by Server to send images to the GUI "
        im = self.filename2image(filename)
        if im == None:
            print "Unable to load %s" % filename
            return
        next = self.max + 1
        self.IM[str(next)] = im
        self.max = self.current = next
        self.putimage()            

    # displaynext, displayprev use wraparound to change the image index
    def displaynext(self, event=None):
        self.current = self.current + 1
        if self.current > self.max:
            self.current = self.min
        self.putimage()

    def displayprev(self, event=None):
        self.current = self.current - 1
        if self.current < self.min:
            self.current = self.max
        self.putimage()
        
    # displayffwd, displayback stop at start or end    
    def displayffwd(self, event=None):
        self.current = self.current + 10
        if self.current > self.max:
            self.current = self.max
        self.putimage()
        
    def displayback(self, event=None):
        self.current = self.current - 10
        if self.current < self.min:
            self.current = self.min
        self.putimage()

    def quit(self):
        if self.useserver == 1:
            self.top.title("qview closing....")
            self.top.update_idletasks()
            #print "stopping the qview server..."
            self.server.quitflag = 1
            if self.server.isAlive():
                exitcmd = "qview.py " + EXIT
                os.system(exitcmd) # because server is waiting for input
        self.top.quit()
      
########################################################################
#

def findServer():
    sockobj = socket(AF_INET, SOCK_STREAM)      # make a TCP/IP socket object
    try:
        sockobj.connect((serverHost, serverPort)) # connect to server machine,port
        return sockobj
    except:
        return None

def helpmessage():
    print "usage: qview.py [-s] imagefile(s)"
    sys.exit()

def processargs(args):
    " returns (serverflag, filelist, directory) "
    serverflag = 0
    readall = 0
    filenames = []
    cwd = os.getcwd()

    for item in args:
        if item == '-s':
            serverflag = 1
        elif item == '-h' or item == '-help':
            helpmessage()
        elif os.path.isdir(item):
            # qview dir : reads all files in directory, but
            # qview *   : should not read subdirectories
            if len(filenames) > 0:
                continue
            cwd = os.path.abspath(item)
            os.chdir(cwd)
            filenames = os.listdir(os.getcwd())
            break 
        else:
            filenames.append(item)

    if filenames == []:
        helpmessage()

    if readall:
        files = os.listdir(os.getcwd())
        filenames = []
        for file in files:
            if not os.path.exists(file):  # why is this needed?
                continue
            # only include binary files
            if not os.path.isdir(file) \
               and not Spiderutils.istextfile(file) \
               and file[0] != '.':   
                filenames.append(file)
        if len(filenames) == 0:
            print "no images found in %s" % os.getcwd()
            sys.exit()
            
    return (serverflag, filenames, cwd)

def loadimages(filelist, directory=None):
    " checks if files can be loaded by Image. Return list of images. "
    if directory != None:
        os.chdir(directory)
    imlist = SpiderImageSeries.loadImageSeries(filelist, DISPLAY_ALL=1)
    return imlist
    

#===================================================================
if __name__ == '__main__':

    # -s means use the same window (check if server exists)
    # qview.py _exit_   means stop the server and exit

    verbose = 0
    serverflag = 0
    
    length = len(sys.argv[1:])
    if length < 1:
        helpmessage()

    # process an exit request
    if sys.argv[1] == EXIT:
        sockobj = findServer()
        if sockobj:           # then send info to server, and exit
            sockobj.send(sys.argv[1])     # send line to server over socket
            data = sockobj.recv(1024)  # receive line from server
            sockobj.close()
        sys.exit()

    serverflag, filelist, cwd = processargs(sys.argv[1:])

    # no server: just start up image window
    if serverflag == 0 :
        imglist = loadimages(filelist, directory=cwd)
        if len(imglist) < 1:
            sys.exit()
        root = Tk()
        qw = QuickWindow(root, imglist=imglist, useserver=0)
        root.mainloop()

    # -s = 'use same window' or 'use server'
    else:
        if len(filelist) > 0:
            filename = filelist[0]
        # see if an existing server can be found
        sockobj = findServer()
        # ----- Client -----
        if sockobj:           # then send info to server, and exit
            if verbose:
                print "sending %s to existing server" % filename
            sockobj.send(filename)     # send line to server over socket
            data = sockobj.recv(1024)  # receive line from server
            if verbose:
                print "the qview client received %s" % data
                if data.find("qview") < 0:
                    print "qview client received incorrect feedback from server"
                    # data should be of form "qview : filename"
            sockobj.close()
        # ----- Server -----
        else:
            root = Tk()
            qw = QuickWindow(root, filename=filename, useserver=1)
            root.mainloop()
