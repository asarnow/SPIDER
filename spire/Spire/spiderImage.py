# $Id: spiderImage.py,v 1.1 2012/07/03 14:21:59 leith Exp $
#
# contains code for displaying images

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
#
# There should always be a function called displayImage that
# takes a SPIDER image file as its argument.
#

import GG, GB
import os, string
from socket import *
from commands import getoutput
import LocalVars
from spiderUtils import gethostname
from   tkMessageBox   import showerror
#from spiderGUtils import *

def displayError(message, title=None, parent=None):
    if title == None: title = 'Error'
    showerror(title, message)
    if parent != None:
        parent.lift()


serverPort = 50008
serverHost = gethostname()
webjarstr = "WEB.jar"
jwebcmd = LocalVars.jwebcmd

def sendFileToSocket(filename):
    " returns 0 if unable to send the file"
    sockobj = socket(AF_INET, SOCK_STREAM)
    result = sockobj.connect_ex((serverHost, serverPort))
    if result == 0:
        sockobj.send(filename)
        sockobj.close()
        return 1
    else:
        return 0

def displayImage(filename):
    if not os.path.exists(filename): return
    #print "spiderImage.displayImage %s" % GG.prefs.displayProgram

    if GG.prefs.displayProgram.lower() == 'jweb':
        result = sendFileToSocket(filename)
        if result == 0:
            startJweb()
            # may need to insert delay here
            res2 = sendFileToSocket(filename)
        return
            
    elif GG.prefs.displayProgram == 'qv':
        cmd = "qv -s %s &" % (filename)
        os.system(cmd)
        
    else:
        cmd = "%s %s &" % (GG.prefs.displayProgram, filename)
        os.system(cmd)
    #print cmd
        
def displayVolume(filename):
    " in the future, this code may be different from image code"
    if not os.path.exists(filename): return
    #print "displayVolume %s" % GG.prefs.displayProgram

    if GG.prefs.displayProgram.lower() == 'jweb':
        result = sendFileToSocket(filename)
        if result == 0:
            startJweb()
            # may need to insert delay here
            res2 = sendFileToSocket(filename)
        return

def isJwebstarted():
    " checks if the server port number is already in use"
    serverHost = os.uname()[1]
    try:
        s = socket(AF_INET, SOCK_STREAM)
        s.bind((serverHost, serverPort))
        s.close()
    except Exception, e:
        print "Socket binding generated an exception."
        print e
        if len(e) > 1 and e[1] == 'Address already in use':
            print "Port number %d used by Jweb is already in use." % serverPort
        return 1
    
    return 0
    """
    user = os.environ['USER']
    psout = getoutput('ps -f -u%s' % user)
    for item in psout.split('\n'):
        if item.find('java') > -1 and item.find('StartWeb') > -1:
            return 1
    return 0
    """

def printClasspath():
    for i in os.environ['CLASSPATH'].split(":"):
        print i


def startJweb(verbose=1):
    "try to start jweb as a listening server with SPIDUI argument  "
    if not isJwebstarted():    # check if server port number is in use
        # check CLASSPATH
        env = os.environ.keys()
        #printClasspath()
        if 'CLASSPATH' not in env:
            if verbose:
                displayError('CLASSPATH environmental variable not set')
            return
        if string.find(os.environ['CLASSPATH'], webjarstr) < 0:
            if verbose:
                displayError('Jweb does not appear to be in your classpath')
            return
        if verbose:
            serverHost = GB.P.host
            displayError("Trying to start Jweb on %s with command\n%s" \
                         % (serverHost,jwebcmd),"Unable to connect to Jweb")

        # start jweb
        #cp = os.environ['CLASSPATH']
        #setcmd = "CLASSPATH=%s; export CLASSPATH" % cp
        #cmd = "%s; %s" % (setcmd, GG.jwebcmd)
        #print cmd
        #os.system(cmd)
        os.system(GG.jwebcmd)
        #getoutput(GG.jwebcmd)
    else:
        if verbose:
            displayError('Please start Jweb with command\n' + jwebcmd + ' &',\
                         'Unable to connect to Jweb')
