# $Id: spiderInspect.py,v 1.1 2012/07/03 14:21:59 leith Exp $
#
# Inspect various Spire/Python objects

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
import inspect
import GB,GG
from spiderGUtils import *


def inspectObject(obj, textwin=None, indent=0):
    if textwin == None:
        w = windowExists('Inspect')
        if w:
            w.destroy()
        tw = textWindow(title="Inspect", font='output')
        if tw == 0: return
    else:
        tw = textwin
    skip = indent * " "

    try:
        tw.write(str(obj))
        tw.write("-----------------------")
    except:
        pass

    strings = []
    numbers = []
    lists = []
    dicts = []
    other = []

    members = inspect.getmembers(obj)
    for m in members:
        name, value = m
        if name[0:2] == "__":   # skip built-ins
            continue
        if type(value) == type(1) or type(value) == type(1.2):
            numbers.append( (name,value) )
        elif type(value) == type("str"):
            strings.append( (name,value) )
        elif type(value) == type([]):
            lists.append( (name,value) )
        elif type(value) == type({}):
            dicts.append( (name,value) )
        else:
            other.append( (name,value) )

    for header,objlist in [('Strings',strings),('Numbers',numbers), ('Lists',lists),
                           ('Dictionaries', dicts), ('Other', other)]:
        if len(objlist) > 0:
            tw.write("%s" % header, tag='hdr')
            for s in objlist:
                tw.write(skip + "%s : %s" % (s[0], str(s[1])))
            tw.write(" ") # adds a newline

def writedict(textwin, dict, indent=0):
    name = dict[0]
    skip = indent * " "
    textwin.write(skip + name + " :")
    d = dict[1]
    skip = (indent+2) * " "
    keys = d.keys()
    keys.sort()
    for k in keys:
        textwin.write(skip + "%s : %s" % (k, str(d[k])))
            
def inspectProject():
    if not hasattr(GB,'P'):
        displayError('No project to view')
        return
    inspectObject(GB.P)
    
def inspectProjectFile():
    if not hasDatabase():
        displayError('unable to open project file')
        return

    w = windowExists('Inspect')
    if w:
        w.destroy()
    tw = textWindow(title="Inspect", font='output')
    if tw == 0: return

    tw.write("******** Project   ----------------------")
    proj = GB.DB.get('Project')
    inspectObject(proj, textwin=tw, indent=0)
    tw.write("\n******** Config   ----------------------")
    conf = GB.DB.get('Config')
    inspectObject(conf, textwin=tw, indent=0)
    tw.write("\n******** RunList   ----------------------")
    rl = GB.DB.RunList()
    inspectObject(rl, textwin=tw, indent=0)    
