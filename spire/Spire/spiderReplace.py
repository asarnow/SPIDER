# $Id: spiderReplace.py,v 1.1 2012/07/03 14:21:59 leith Exp $
#
# make changes to batch file text prior to execution

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
import os, threading

import GB,GG
from spiderUtils import *
from spiderGUtils import makeVBOFFwindow

# batReplace replaced by batReplaceFilenums, since it no longer deals
# with MD VB OFF or the results file
def batReplaceFilenums(batfile, filenumFile=None):
    if not os.access(batfile, os.W_OK):
        try:
            os.chmod(batfile,0664)
        except:
            GB.errstream.write('Write permission is required for\n' + batfile)
            return 0
        
    # read in the text of the batch file    
    B = fileReadLines(batfile)
    if B == None: return 0

    # replace filenums file in batch text with temporary filename passed in
    B = replaceFilenums(B, newfilenumfile=filenumFile)

    os.remove(batfile)
    if fileWriteLines(batfile, B):
        return 1
    else:
        return 0

# -------------------------------------------------------------------
# batReplace: rewrites the batch file
#   1) handles MD VB OFF
#   2) replaces filenums in "<symbol>filenums ; comment"
# September 2005:
#   Spire no longer changes EN D --> EN, and controls deletion of results.
#   Instead 'results' refers to the spireout file, whose deletion is
#   controlled by GG.prefs.saveResults

# returns 1 = ok
#         0 = error
def batReplace(batfile, filenumfile=None, netexec='local'):
    if not os.access(batfile, os.W_OK):
        try:
            os.chmod(batfile,0664)
        except:
            GB.errstream.write('Write permission is required for\n' + batfile)
            return 0
        
    # read in the text of the batch file    
    B = fileReadLines(batfile)
    if B == None: return 0

    """
    # 1) add/remove MD VB OFF
    B = MD_VB_OFF(B)
    if B == []:
        print "MD VB OFF problem"
        return 0
    """

    # 2) replace filenums file in batch text with temporary filename passed in
    if GG.prefs.useFilenumsEntry:
        B = replaceFilenums(B, newfilenumfile=filenumfile)

    # 3) change EN D --> EN
    #B = end2en(B)

    os.remove(batfile)
    if fileWriteLines(batfile, B):
        return 1
    else:
        return 0

# some helper functions for batReplace ------------------

# MD_VB_OFF
# If MD VB OFF found, user may specify:
#  - Change to VB ON
#  - Proceed with VB OFF, don't save files to project
#  - Cancel
# If user selects 'change', then change all subsequent VB OFFs as well.
# 
# Returns B, list of text lines, or [] = Cancel execution

def MD_VB_OFF(B):
    res = '0'
    n = len(B)
    for i in range(n):
        line = B[i]
        s = stripComment(line).upper()
        if s.find("VB OFF") > -1:
            if res == '0':  # unset
                res = vboffdialog()
                #print "res = %s" % res
                
            if res == 'change':
                B[i] = "VB ON\n"
            elif res == 'proceed':
                return B
            elif res == 'cancel':
                return []
    return B

# expects to be called from inside a batchLoop thread, therefore cannot call
# makeVBOFFwindow() directly. Instead, puts it on Main GUI's process queue.
def vboffdialog():
    if isMainThread():
        res = makeVBOFFwindow()
    else:
        res = threadedGUIcall()

    #print "vboffdialog result: %s" % res
    return res

# MD_TERM_ON
#   B = lines from a batch file
#   if netexec = local:  adds MD \n TERM ON to top of file,
#   if netexec = remote: removes MD TERM ON
# returns lines with changes made
def MD_TERM_ON(B, netexec='local'):
    N = []
    if netexec == 'local':
        # if TERM ON is not found, add it, else do nothing
        TERM_ON_present = 0
        for line in B:
            s = stripComment(line).upper()
            if s.find('TERM ON') > -1:
                TERM_ON_present = 1
                return B
            
        if not TERM_ON_present:
            B = ['MD\n'] + ['TERM ON\n'] + B
            return B
        
    #  else netexec == remote : remove TERM ON if present
    else:
        ptr = 0
        for line in B:
            s = stripComment(line).upper()
            # get rid of 'TERM ON' and previous line with 'MD'
            if s.find('TERM ON') > -1:
                if ptr > 0:
                    B = B[:ptr-1] + B[ptr+1:]
                    break
            ptr = ptr + 1
        return B

def replaceFilenums(B, newfilenumfile=None):
    " B = list of lines. Returns B with new filenumbers value"
    if newfilenumfile == None:
        newfilenumfile = uniqueFilename(prefix='fn')
        
    k = 0
    for line in B:
        if line.find(GB.end_of_header) > -1:
            break
        nline = stripComment(line)
        
        # symbol must be at beginning of line
        if nline.find(GG.sysprefs.filenumSymbol) == 0:
            # if there's a comment
            a = line.find(';')
            if a > -1:
                symbol,value = spiderSymbol(line[:a])
                comment = line[a:]
                #print "utils.replaceFilenums comment : " + comment
                # replace the old value with the new name
                newline = symbol + newfilenumfile + '     ' + comment
            # if no comment
            else:
                symbol,value = spiderSymbol(stripComment(line))
                newline = symbol + newfilenumfile + '     ; file numbers doc file'
                
            B[k] = newline
            break
        else:
            k +=1

    return B

def end2en(B):
    " replace all occurrences of EN D (or END) with EN "
    k = 0
    for line in B:
        nline = stripComment(line).upper()
        if nline == 'EN D' or nline == 'END':
            B[k] = 'EN\n'
        k += 1
    return B
