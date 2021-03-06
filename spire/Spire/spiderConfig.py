# $Id: spiderConfig.py,v 1.2 2012/08/01 01:17:32 tapu Exp $
#
# functions for Spire configuration files
#
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

import os, string, types
import webbrowser
import xml.dom.minidom
import GB,GG
from spiderUtils import *
from spiderGUtils import *
import spiderDialog
import spiderClasses
from spiderFtypes import isSpiderBatchfile, isSpiderProcedurefile

import inspect

defaultConfig = os.path.join(GG.SPIREHOME,GG.sysprefs.configFile)

def mkNewConfig():
    if not hasProject():
        noProjectError()
        return
    ncf = newConfigForm(wintitle="Spire Configuration",
                        title="Configuration",
                        subtitle="Fill in the blanks, values can be saved as an XML file",
                        config=GB.C)

def dirlist2xml(dlist):
    " returns xml in a text string"
    name = dlist[0]
    files = dlist[1]
    text = '<dir name="%s">' % name
    
    # do file strings first
    for item in files:
        if type(item) == type("string"):
            text += item + ","

    # then directory lists
    for item in files:
        if type(item) == type(["list"]):
            text += dirlist2xml(item)
            
    text += "</dir>\n"
    return text

def dir2dialog(d):
    " dir is of form [dirname [ f, f, [dir], [dir],..]] "
    dirname = d[0]
    dlist = d[1]
    D = spiderDialog.Dialog(name=dirname, title=dirname, dir=dirname) # create instance
    for item in dlist:
        if isSpiderBatchfile(item):
            button = [item, "Run", [item]]
            D.cmdlist.append(button)
    return D

# for reading directories from the disk -----
def isBatchFile(f):
    if isSpiderBatchfile(f) or isSpiderProcedurefile(f):
        return True
    else:
        return False
    
def getDirFiles(dirname):
    if dirsizeTooBig(dirname):
        return [dirname, []]
    
    os.chdir(dirname)
    dlist = []
    blist = []
    flist = os.listdir(os.getcwd())

    for f in flist:
        if os.path.isdir(f):
            dlist.append(f)
        elif isBatchFile(f) and f[-1] != '~':
            blist.append(f)

    d = [dirname, blist]
    for subdir in dlist:
        d[1].append([subdir])   # for now just support 1 level of recursion
    #    d.append(getDirFiles(subdir))
    os.chdir('..')
    return d

def readDirsFromDisk(projectDir=None, tmpfile="tmp999.xml"):
    " dir is of form [dirname [ f, f, [dir], [dir],..]] "
    if projectDir == None:
        projectDir = GB.P.projdir

    os.chdir(projectDir)

    dlist = []
    blist = []
    flist = os.listdir(os.getcwd())

    for f in flist:
        if os.path.isdir(f):
            dlist.append(f)
        elif isBatchFile(f) and f[-1] != '~':
            blist.append(f)

    projdirs = ['.', blist]

    for subdir in dlist:
        projdirs[1].append(getDirFiles(subdir))

    xmltext = dirlist2xml(projdirs)
    fileWriteLines(tmpfile, xmltext)
    fileEdit(tmpfile)
    

def mkconfig(src, ftypes, xmlout):
    " make a Spire config (not an xml config) "
    if not os.path.exists(src):
        displayError("Unable to find %s" % src)
        return
    if type(ftypes) != type(["list"]):
        ftypes = [ftypes]
    
    GB.outstream("Reading files and directories under %s" % src)
    C = spiderClasses.Config() # make a new instance
    C.path = [src]
    dlist = read_dirtree(src, ftypes)
    C.Dirs = dlist[1]
    print "back from readdirtree. dlist:"
    print dlist
    # dlist: ['prj', [ file, file, [dir], [dir], ...]
    # each of the 1st level dirs under the project dir
    # has its own dialog
    olddir = os.getcwd()
    dlist[0] = '.'  # top-level project directory is generic, can have any name
    projectdir = dlist[0]
    print "projectdir: %s" % projectdir

    #if not chdir(projectdir):
        #return
    filelist = dlist[1]
    dialoglist = []
    for item in filelist:
        if type(item) == type(["list"]):
            dirname = item[0]
            dirlist = item[1]
            if not chdir(dirname):
                print "can't change to %s" % dirname
                continue
            dialoglist.append(dirname)
            ddgg = dir2dialog(item)
            print "dialog"
            print ddgg
            C.Dialogs[item[0]] = ddgg
            chdir("..")
            
    C.Dialogs['dialogList'] = dialoglist

    # set the new config as the project config
    if hasProject():
        GB.C = C

    # save it as xml file
    if xmlout != "":
        C.save2xml(xmlout)
        #saveXMLConfig(file=xmlout, config=C)
        
    chdir(olddir)

# ################################################################
#
# Configuration Form
#
class newConfigForm(spiderClasses.scrolledForm):

    def processargs(self):
        if self.kwargs.has_key("config"):
            self.config = self.kwargs["config"]
        else:
            self.config = spiderClasses.Config()

        self.LocalConfigFilename = None

        self.pathVar = StringVar()
        if self.config != None:
            self.dialoglist = []
            self.dirlist = []
        else:
            self.config = spiderClasses.Config()
        self.dirCancel = 0

    def makeButtons(self, buttonframe):
        self.addButton(buttonframe, text="Save", command=self.saveas,
                       help = "Save the configuration")
        self.addButton(buttonframe, text="Read", command=self.readconfig,
                       help = "Read an XML configuration file")
        self.addButton(buttonframe, text="New", command=self.newconfig,
                       help = "Clear all values")
        self.addButton(buttonframe, text="View", command=self.viewconfig,
                       help = "View the configuration")
        self.addButton(buttonframe, text="Cancel", command=self.quit,
                       side='right', help = "Close this window")
        
    def mkMainFrame(self):
        self.fmain.configure(background=GG.bgd03)
        
        # ----- Create the Pmw group that will contain each section ---------
        px = py = 4
        # Main entries
        mg = Pmw.Group(self.fmain, tag_text='Main tags')
        mg.pack(side='top', fill = 'both', expand=1, padx=2*px, pady=py)
        mgrp = mg.interior()
        
        self.title = Pmw.EntryField(mgrp, labelpos='w', label_text="Title")
        self.image = Pmw.EntryField(mgrp, labelpos='w', label_text="Image")
        self.helpurl = Pmw.EntryField(mgrp, labelpos='w', label_text="Help URL")
        self.title.pack(side='top', anchor='w', expand=1, fill='x')
        self.image.pack(side='top', anchor='w', expand=1, fill='x')
        self.helpurl.pack(side='top', anchor='w', expand=1, fill='x')
        entries = (self.title, self.image, self.helpurl)
        Pmw.alignlabels(entries)

        # Batch file Locations
        lg = Pmw.Group(self.fmain, tag_text='Location')
        lg.pack(side='top', fill = 'both', expand=1, padx=2*px, pady=py)
        lgrp = lg.interior()
        lglabel = Label(lgrp, text="Indicate the source location of batch files")
        lglabel.pack(side='top', anchor='w')
        srcdir = Entry(lgrp, textvariable=self.pathVar)
        lgbut = Button(lgrp, text="Directory: ",
                       command=Command(getDir,self.pathVar,srcdir))
        lgbut.pack(side='left', padx=px, pady=py)
        srcdir.pack(side='right', fill='x', expand=1)
        self.helpMessage(lgbut, "Tells Spire where to find batch files")

        # Dialogs
        dg = Pmw.Group(self.fmain, tag_text='Dialogs')
        dg.pack(side='top', fill = 'both', expand=1, padx=2*px, pady=py)
        dgrp = dg.interior()
        dgbframe = Frame(dgrp)
        dgbframe.pack(side='left')
        addb = Button(dgbframe, text="new dialog",
                      command = Command(self.editdialog,'new'))
        addb.pack(side='top', padx=px, pady=py)
        editb = Button(dgbframe, text="edit dialog", command=self.editdialog)
        editb.pack(side="top", padx=px, pady=py)

        self.box = Pmw.ScrolledListBox(dgrp, listbox_selectmode=SINGLE,
                                      items=self.dialoglist,
                                      listbox_height=5, vscrollmode='static',
                                      dblclickcommand=self.editdialog)
        self.box.pack(side="right", fill='both', expand=1)
        self.helpMessage(addb, "Create a new dialog")
        self.helpMessage(editb, "Edit the selected dialog")

        # Directories
        gg = Pmw.Group(self.fmain, tag_text='Directories')
        gg.pack(side='top', fill = 'both', expand=1, padx=2*px, pady=py)
        ggrp = gg.interior()
        ggbframe = Frame(ggrp)
        ggbframe.pack(side='left')
        daddb = Button(ggbframe, text="new directory",
                       command=Command(self.editdir, 'new'))
        daddb.pack(side='top', padx=px, pady=py)
        deditb = Button(ggbframe, text="edit directory", command=self.editdir)
        deditb.pack(side='top', padx=px, pady=py)
        treeb = Button(ggbframe, text="read directory", command=self.readDirtree)
        treeb.pack(side='top', padx=px, pady=py)

        self.dirbox = Pmw.ScrolledListBox(ggrp, listbox_selectmode=SINGLE,
                                      items=self.dirlist,
                                      listbox_height=5, vscrollmode='static',
                                      dblclickcommand=self.editdir)
        self.dirbox.pack(side="right", fill='both', expand=1)
        self.helpMessage(daddb, "Create a new directory")
        self.helpMessage(deditb, "Edit the selected directory")
        self.helpMessage(treeb, "Read a project directory tree")


        self.setValues()  # put values in the entries

    def setValues(self):
        " expects the widgets to have been created "
        cfg = self.config
        if hasattr(cfg, 'Title'): self.title.setvalue(cfg.Title)
        if hasattr(cfg, 'Image'): self.image.setvalue(cfg.Image)
        if hasattr(cfg, 'helpurl'): self.helpurl.setvalue(cfg.helpurl)
        if hasattr(cfg, 'path'):
            if type(cfg.path) == type(["list"]) and len(cfg.path) > 0:
                self.pathVar.set(cfg.path[0])
        if hasattr(cfg, 'Dialogs'):
            if 'dialogList' in cfg.Dialogs:
                self.dialoglist = cfg.Dialogs['dialogList']
            else:
                self.dialoglist = cfg.Dialogs.keys()
                self.dialoglist.sort()
            self.box.setlist(self.dialoglist)
        if hasattr(cfg, 'Dirs'):
            self.dirlist = []
            for item in cfg.Dirs:
                dirname = item[0]
                self.dirlist.append(dirname)
            self.dirbox.setlist(self.dirlist)

    def form2config(self):
        " get values from form, put in a Config object "
        C = spiderClasses.Config()
        C.Title = self.title.getvalue()
        C.Image = self.image.getvalue()
        C.helpurl = self.helpurl.getvalue()
        C.path = [self.pathVar.get()]
        C.Dialogs = self.config.Dialogs
        C.Dirs = self.config.Dirs
        return C

    def saveas(self, askload=1):
        default = None
        if hasattr(GB.P, 'config'):
            default = GB.P.config
        filename = askSaveAsFilename(filetypes="*.xml", initialfile=default)
        if filename == "": return

        setconfig = 'False'
        if askload:
            msg = "Load %s into Spire?" % os.path.basename(filename)
            setconfig = askYesorNo(msg, title="set new configuration")

        config = self.form2config()
        config.save2xml(filename, setproject=setconfig)
        self.LocalConfigFilename = filename
        return filename

    def readconfig(self, filename=None):
        if filename == None:
            filename = askfilename()
        if filename == "":
            return
        self.config = readXMLConfig(XMLfile=filename, setproject=0)
        self.setValues()

    def newconfig(self):
        self.config = spiderClasses.Config()
        self.config.Title = ""
        self.config.Image = ""
        self.config.path = [""]
        self.setValues()
    
    def viewconfig(self):
        filename = self.saveas(askload=0)
        fileEdit(filename)
        

    def editdialog(self, mode='edit'):
        dialog = None
        if mode == 'edit':
            d = self.box.getvalue()  # getvalue returns a tuple
            if len(d) > 0:
                dialogname = d[0]
                if dialogname != None and dialogname in self.config.Dialogs:
                        dialog = self.config.Dialogs[dialogname]
        elif mode == 'new':
            dialog = spiderDialog.Dialog()

        wintitle = "Edit Dialog"
        w = newWindow(wintitle)
        if w == 0: return
        # puts data in dialog, not df
        df = spiderDialog.DialogEditForm(w, dialog)
        #if hasattr(self, 'child_windows'):
        #   if df not in self.child_windows:
        #       self.child_windows.append(df)
        #else:
        #   self.child_windows = [df]
        w.wait_window(w)
        if df.result == "ok" and dialog != None:
            self.config.addDialog(dialog)
            if mode == 'new':
                # update the listbox
                dialogname = dialog.name
                if dialogname not in self.dialoglist:
                    self.dialoglist.append(dialogname)
                b = self.box.get() # gets all values
                if dialogname not in b:
                    self.box.component('listbox').insert(END, dialogname)
                    self.box.component('listbox').see(END)

    def readDirtree(self):
        directory = askDirectory()
        #print directory
        if len(directory) > 0:
            tree = read_dirtree(directory)
            t = tree[1]
            dirlist = []
            for item in t:
                if type(item) == type(["list"]):
                    dirlist.append(item)
            self.config.Dirs = dirlist
            self.setValues()

    def editdir(self, mode='edit'):
        dirname = ""
        dircontents = ""
        if mode == 'edit':
            d = self.dirbox.getvalue()  # getvalue returns a tuple
            if len(d) > 0:
                dirname = d[0]
                dircontents = self.getDirContents(dirname)
        dirnameVar = StringVar()
        dircontentsVar = StringVar()
        dirnameVar.set(dirname)
        dircontentsVar.set(dircontents)

        wintitle = "Edit Directory"
        w = newWindow(wintitle)
        if w == 0: return
        self.dirCancel = 0
        self.dirWindow(w, dirnameVar, dircontentsVar)
        w.wait_window(w)

        if self.dirCancel:
            self.dirCancel = 0
            return
        # after return from dirWindow, change class attributes and config contents
        dn = dirnameVar.get()
        dn = os.path.basename(dn)
        b = self.dirbox.get()
        if dn not in b:
            self.dirbox.component('listbox').insert(END, dn)
            self.dirbox.component('listbox').see(END)
        if dn not in self.dirlist:
            self.dirlist.append(dn)
        # list of files
        dc = dircontentsVar.get()
        d = dc.split(",")
        files = []
        for file in d:
            files.append(file)
        dd = addDir2Config(self.config.Dirs, [dn, files])
        if dd != "":
            self.config.Dirs = dd
        #print self.config.Dirs  ###############################

    def getDirContents(self, dirname):
        "returns a string: 'b1.spi, b2.spi,..' "
        d = self.config.Dirs
        for item in d:
            dname = item[0]
            if dirname == dname:
                dirstr = dirlist2string(item[1])
                #s = str(item[1])[1:-1]  # remove list brackets
                #s = s.replace("'","") # remove quotes
                #s = s.replace('"','')
                return dirstr
        return ""

    def dirWindow(self, w, nameVar, contentsVar):
        f1 = Frame(w)
        f1.pack(side='top', fill='both', expand=1)
        dirent = Entry(f1, textvariable=nameVar)
        dirbut = Button(f1, text="Directory\n name  ",
                        command=Command(getDir,nameVar,dirent))
        dirbut.pack(side='left', padx=4, pady=4)
        dirent.pack(side='right', fill='x', expand=1)
        f2 = Frame(w)
        f2.pack(side='top', fill='both', expand=1)
        dcnent = Entry(f2, textvariable=contentsVar)
        dcnbut = Button(f2, text="Directory\ncontents",
                        command=Command(getFiles,None,None,contentsVar))
        dcnbut.pack(side='left', padx=4, pady=4)
        dcnent.pack(side='right', fill='x', expand=1)

        fb = Frame(w, background=GG.bgd01, relief=GG.frelief, borderwidth=GG.brdr)
        fb.pack(side='top', fill='x', expand=0)
        ok = Button(fb, text="Ok", command=w.destroy)
        ok.pack(side='left', padx=4, pady=4)
        done = Button(fb, text="Cancel", command=Command(self.dirdone,w))
        done.pack(side='right', padx=4, pady=4)
        
    def dirdone(self,w):
        self.dirCancel = 1
        w.destroy()

def addDir2Config(dirlist, newdir):
    " dir = [dirname, [list of files]], dirlist is a list of such dirs"
    if type(newdir) != type(["list"]):
        print("addDir2Config: dir must be of type: [dirname, [list of files]]")
        return ""
    newdirname = newdir[0]
    newdirlist = []
    newdirAdded = 0
    for item in dirlist:
        dirname = item[0]
        if dirname == newdirname:
            #print "replacing %s" % newdir
            newdirlist.append(newdir)
            newdirAdded = 1 
        else:
            #print "including %s" % item[0]
            newdirlist.append(item)
    if not newdirAdded:
        #print "adding %s" % newdir
        newdirlist.append(newdir)
    return newdirlist

def dirlist2string(d, slash=1):
    " input is a list of config dir contents: [file, file, [dir, [sub]], file]"
    " only directory names are listed, not their contents."
    dirstr = ""
    for item in d:
        if type(item) == type("string"):
            dirstr += item + ","
        elif type(item) == type(["list"]):
            i = item[0]
            if type(i) == type("string"):
                if slash: i += "/"
                dirstr += i + ","
    dirstr = dirstr[:-1]
    return dirstr

def string2dirlist(s):
    " input is a string of filenames, directories have slashes."
    " output list of config dir contents: [list of files, dirs]"
    dirlist = []
    ss = s.split(",")
    for item in ss:
        if type(item) == type("string"):
            i = item.strip()
            if i[-1] == '/':
                dname = i[:-1]
                i = [dname, []]
            dirlist.append(i)
    return dirlist

    

################################################################

def editConfig(filename=None):
    " edit the config.xml in a text editor "
    if filename == None:
        filename = GB.P.config
    if not os.path.exists(filename):
        GB.errstream("Unable to locate %s" % filename)
        return
    txt = "After making changes to the xml file, you must load the configuration into Spire with the 'Read' button"
    res = askOKorCancel(txt, title='Edit config file')
    if res:
        fileEdit(filename)

def viewConfig(file=None):
    if file == None:
        file = GB.P.config
    if not os.path.exists(file):
        GB.errstream("Unable to locate %s" % file)
        return
    webbrowser.open(file)
    #ew = editWindow(file=file, title=os.path.basename(file))

# Returns text inside tags. Concatenates text.
# If subnode tagname is <spider>, returns inner text,
# other wise returns text inside tag, e.g., <prog>web</prog>
def getText(nodelist):
    rc = ""
    for node in nodelist:
        if node.nodeType == node.ELEMENT_NODE:
            if node.tagName == 'spider':
                rc = rc + getText([node])
            else:
                rc = rc + node.toxml()
        elif node.nodeType == node.TEXT_NODE:
            rc = rc + node.data
    return str(rc.strip())

def getButton(node):
    label = buttontext = "" 
    cmdlist = []
    for g in node.childNodes:
        if g.nodeName == 'label':
            label = getText(g.childNodes)
        elif g.nodeName == 'buttontext':
            buttontext = getText(g.childNodes)
        elif g.nodeName == 'proc':
            cmdlist = [getText(g.childNodes)]
            
    runattr = str(node.getAttribute('run')).strip()
    editattr = str(node.getAttribute('edit')).strip()
    if runattr or editattr: # set only if they == "no"
        if runattr:
            #print "spi.config: button has run: %s" % str(runattr)
            if not runattr.lower() == "no":
                runattr = ""
        elif editattr:
            #print "spi.config: button has edit: %s" % str(editattr)
            if not editattr.lower() == "no":
                editattr = ""
        button = [label, buttontext, cmdlist, (runattr, editattr)]
        #print "getButton: " + str(button)
    else:
        button = [label, buttontext, cmdlist]
    return button

    
def processDialog(node):
    name = title = dir = ""
    cmdlist = []

    for n in node.childNodes:
        if n.nodeName == 'name': name = getText(n.childNodes)
        elif n.nodeName == 'title': title = getText(n.childNodes)
        elif n.nodeName == 'dir': dir = getText(n.childNodes)
        elif n.nodeName == 'help': help = getText(n.childNodes)
        elif n.nodeName == 'button':
            cmdlist.append(getButton(n))
        elif n.nodeName == 'group':
            groupname = str(n.getAttribute("name"))
            buttonlist = []
            for g in n.childNodes:
                if g.nodeName == 'button':
                    buttonlist.append(getButton(g))
            group = [groupname, buttonlist]      
            cmdlist.append(group)

    dialog = spiderDialog.Dialog(name=name, title=title, dir=dir,
                                 help=help, cmdlist=cmdlist)
    #if dialog.name == "Refinement":
    #   for item in cmdlist:
    #       print item

    return dialog

def getDialogs(dom):
    " returns a dictionary of dialogs "
    d = dom.getElementsByTagName("Dialogs")
    if len(d) < 1:
        return []

    Dialogs = { 'dialogList' : [] }
    dialoglist = []
    node = d[0]
    for n in node.childNodes:
        if n.nodeName == 'dialog':
            d = processDialog(n)
            Dialogs[d.name] = d
            dialoglist.append(d.name)
    Dialogs['dialogList'] = dialoglist

    return Dialogs

# processDirs: recursive routine to create directory data structure.
# node : node of a dom parsed by xml.minidom
# d : directory of form [ "dirname", [list, of, files]]
# Doesn't return anything, but keeps inserting stuff into the filelist.
def processDirs(node, d):
    """ create directory data structure from xml text """
    if node.nodeName == 'dir':
        name = str(node.getAttribute("name"))
        new = [name, []]
        for n in node.childNodes:
            processDirs(n,new)
        d[1].append(new)
    elif node.nodeName == '#text':
        v = node.nodeValue
        v = string.split(v,",")
        s = []
        for i in v:
            k = string.strip(i)
            if k != "":
                s.append(str(k))
        d[1] += s

def getDirectories(dom):
    d = dom.getElementsByTagName("Directories")
    if len(d) < 1:
        return []
    node = d[0]
    dirlist = []
    for n in node.childNodes:
        if n.nodeName == 'dir':
            name = str(n.getAttribute("name"))
            u = [name, []]
            processDirs(n, u)
            dirlist.append(u[1][0])
    return dirlist
        
def getLocations(dom, XMLfile=None):
    " returns list of directories from <Locations> "
    path = []
    d = dom.getElementsByTagName("Locations")
    if len(d) < 1:
        return path
    node = d[0]
    
    for node in node.childNodes:
        if node.nodeName == 'location':
            fc = node.firstChild         # text data = 1st child 
            if fc.nodeType == node.TEXT_NODE:
                expanded = os.path.expandvars(fc.data)
                path.append(str(expanded))

    # if 1st char is not "/", use path relative to the XML file
    if XMLfile != None:
        P = []
        xmlpath, xmlbase = os.path.split(XMLfile)
        for loc in path:
            if loc == '.':
                loc = xmlpath
            elif loc[0] != "/":
                loc = os.path.normpath(os.path.join(xmlpath,loc))
            P.append(loc)
    else:
        P = path

    return P
        
def getParameters(dom):
    " returns list of directories from <Parameters> "
    path = []
    d = dom.getElementsByTagName("Parameters")
    if len(d) < 1:
        return path
    node = d[0]
    
    for node in node.childNodes:
        if node.nodeName == 'parm':
            fc = node.firstChild         # text data = 1st child 
            if fc.nodeType == node.TEXT_NODE:
                path.append(str(fc.data))
    return path

def getNodeText(tagText, dom):
    " returns content between <tag>content</tag>, or empty string "
    content = ""
    nd = dom.getElementsByTagName(tagText)
    if nd:
        node = nd[0]
        if node.firstChild.nodeType == node.TEXT_NODE:
            content = str(node.firstChild.data)
    else:
        pass # the node didn't have that tag
    return content

def getMainParameters(dom):
    "returns (title(str), image(str), helpurl(str), params(int), database(int)"
    title = image = help = ""
    useparms = usedatabase = 1  # use them by default
    # get title, image, helpurl from Main tag
    d = dom.getElementsByTagName("Main")
    if len(d) < 1:
        return (title, image, help, useparms, usedatabase)
    node = d[0]  
    for node in node.childNodes:
        if node.nodeName == 'title':
            if node.firstChild.nodeType == node.TEXT_NODE:
                title = node.firstChild.data
        elif node.nodeName == 'image':
            if node.firstChild.nodeType == node.TEXT_NODE:
                image = node.firstChild.data
        elif node.nodeName == 'helpurl':
            if node.firstChild.nodeType == node.TEXT_NODE:
                help = node.firstChild.data
    
    # attributes of Configuration tag (params database)
    useparms = usedatabase = useprojid = 1  # use them by default
    node = dom.getElementsByTagName("Configuration")[0]
    params = str(node.getAttribute("params"))
    database = str(node.getAttribute("database"))

    if params.upper() == "NO": useparms = 0
    if database.upper() == "NO": usedatabase = 0

    return (title, image, help, useparms, usedatabase)

def readXMLConfig(XMLfile=None, setproject=1):
    """ read a spire XML configuration file: returns a Config object  """
    if XMLfile == None or not os.path.exists(XMLfile):
        if os.path.exists(GG.sysprefs.configFile):
            XMLfile = GG.sysprefs.configFile
        else:
            XMLfile = defaultConfig
            
    if XMLfile == None or XMLfile =="":
        GB.errstream("spiderConfig.readXMLConfig: unable to locate a valid config file.")
        return

    try:
        dom = xml.dom.minidom.parse(XMLfile)
    except:
        GB.errstream("spiderConfig.readXMLConfig: unable to parse %s" % (XMLfile))
        displayError("unable to parse %s" % (XMLfile))
        return 0

    C = spiderClasses.Config()   # create an empty instance of Config

    title, image, helpurl, parms, database = getMainParameters(dom)
    if title != "": C.Title = title
    if image != "": C.Image = image
    if helpurl != "": C.helpurl = helpurl
    #helpurl = str(helpurl)
    #if helpurl != "":
    #   GG.HelpURL = helpurl
    #   GG.sysprefs.helpURL = helpurl
    C.useParameterFile = parms
    C.useDatabase = database

    C.path = getLocations(dom, XMLfile)  
    C.Dialogs = getDialogs(dom)
    C.Dirs = getDirectories(dom)
    
    # see if config has optional <Parameters> tag
    p = getParameters(dom)
    if len(p) > 0:
        C.parms = p  # a list of [key value comment] lists
    # <Parameters> are just default settings for a new project,
    # they are saved in params file, not in Configuration.
    
    dom.unlink()  # free up the memory

    if len(C.path) > 0 and len(C.Dialogs) > 0 and len(C.Dirs) > 0:
        if setproject:
            GB.C = C
            GB.outstream("configuration loaded from %s" % XMLfile)
            updateMainMenus()
            if hasProject():
                saveConfig()
        return C
    else:
        GB.outstream("No configuration loaded: required xml tags are empty")
        if not C.path:
            GB.outstream("Unable to parse <Locations>")
        elif not C.Dialogs:
            GB.outstream("Unable to parse <Dialogs>")
        elif not C.Dirs:
            GB.outstream("Unable to parse <Directories>")
        return 0

# ----------------------------------------------------------------------
def prettyxml(file=None):
    if file == None:
        file = GB.P.config
    if not os.path.exists(file):
        print "can't find %s" % file
        return

    try:
        dom = xml.dom.minidom.parse(file)
    except:
        print "spiderConfig.prettyxml: error parsing %s" % file
        return
    
    tw = textWindow(title="Configuration view", font='output')
    tw.write("Reading %s" % file)
    indent = "  "
    newline = ""
    n = dom.toprettyxml(indent=indent, newl=newline)
    p = string.split(n,"\n")

    B = []

    for line in p:
        if string.count(line,'<') == 2 and string.count(line,'>') == 2:
            a = string.find(line,'>')  # end of 1st tag
            s = line[:a+1]   # up to the first tag (with indent)
            line = line[a+1:]
            b = string.find(line,'<')  # start of 2nd tag
            content = string.strip(line[:b])
            new = s + content + line[b:]
            B.append(new)
        else:
            B.append(line)

    for line in B:
        tw.write(line)

# =======================================================================
#
#   saveConfig
#
def saveConfig():
    if not hasConfig(): return
    if not hasattr(GB.P, 'projfile'): return
    if not hasattr(GB.P, 'DB'): return

    GB.DB.put('Config', GB.C)  # puts GB.C under key 'Config'

   
class saveXMLConfig:
    def __call__(self, file=None, config=None):
        self.init(file)
    def __init__(self, file=None, config=None):
        if file == None: file = GG.sysprefs.configFile
        try:
            fp = open(file,'w')
        except:
            GB.errstream("spiderConfig.saveXMLConfig:file open error: %s" % (file))
            return

        if config == None: self.config = GB.C
        else: self.config = config
        C = self.config

        self.indent = 2
        self.B = []  # create the output list of lines
        
        configtag = "<Configuration"
        if hasattr(C, 'useParameterFile') and C.useParameterFile == 0:
            configtag += ' params="no" '
        if hasattr(C, 'useDatabase') and C.useDatabase == 0:
            configtag += ' database="no" '
        configtag += ">"
        self.writeln(configtag)
            
        # write title, image, help tags inside <Main> tag
        self.writeln("<Main>")
        sp = " " * self.indent
        if hasattr(C,'Title'):
            titletxt = sp + "<title>%s</title>" % C.Title
            self.writeln(titletxt)
        if hasattr(C,'Image'):
            titletxt = sp + "<image>%s</image>" % C.Image
            self.writeln(titletxt)     
        titletxt = sp + "<helpurl>%s</helpurl>" % GG.HelpURL
        self.writeln(titletxt)
        self.writeln("</Main>\n")
        
        self.writeLocations()
        self.writeDialogs()
        self.writeDirectories()
        self.writeln("</Configuration>")

        fp.writelines(self.B)
        fp.close()
        GB.outstream("configuration saved to %s" % file)

    def writeln(self, line, indent=0):
        sp = " " * indent
        self.B.append(sp + line + "\n")

    def write(self, line, indent=0):
        sp = " " * indent
        self.B.append(sp + line)

    def writetag(self, tag, data, indent=0):
        sp = " " * indent
        self.B.append(sp + "<%s>%s</%s>\n" % (tag, data, tag))

    def writeLocations(self):
        sp = " " * self.indent
        self.writeln("<Locations>")
        for item in self.config.path:
            self.writeln(sp + "<location>%s</location>" % item)
        self.writeln("</Locations>\n")

    def writeDialogs(self):
        dialogs = self.config.Dialogs 
        dk = dialogs['dialogList']
        #print "writeDialogs: dk %s" % str(dk)
        #print "writeDialogs: dialog keys %s" % str(dialogs.keys())
        if len(dk) == 0:
            return

        di = self.indent
        bi = di * 2
        self.writeln("<Dialogs>")
        for d in dk:
            dialog = dialogs[d]
            self.writeln("<dialog>", indent=di)
            self.writetag('name', dialog.name, indent=di)
            #print "writeDialogs: %s" % dialog.name
            self.writetag('title', dialog.title, indent=di)
            self.writetag('dir', dialog.dir, indent=di)
            self.writetag('help', dialog.help, indent=di)
            for item in dialog.cmdlist:
                if self.isButton(item):
                    self.writeButton(item, indent=bi)
                else:
                    groupname = item[0]
                    self.writeln('<group name="%s">' % groupname, indent=bi)  
                    blist = item[1]
                    for item in blist:
                        self.writeButton(item, indent=bi)
                    self.writeln("</group>", indent=bi)
            self.writeln("</dialog>", indent=di)
        self.writeln("</Dialogs>\n")

    def writeButton(self,button, indent=0):
        sp = " " * indent
        if len(button) > 3:  # if has run or edit attributes set
            run, edit = button[3]
            if run == 'no' and edit == 'no':
                self.writeln(sp + "<button run='no' edit='no'>")
            elif run == 'no':
                self.writeln(sp + "<button run='no'>")
            elif edit == 'no':
                self.writeln(sp + "<button edit='no'>")
        else:
            self.writeln(sp + "<button>")
        self.writetag('label', button[0], indent=indent+2)
        self.writetag('buttontext', button[1], indent=indent+2)
        proclist = button[2]
        self.writetag('proc', stringify(proclist), indent=indent+2)
        self.writeln(sp + "</button>")
        
    def isButton(self,b):
        if len(b) < 3: return 0
        if type(b[1]) == type("string"):
            return 1
        else:
            return 0

    # -----------------------------------------------
    class dirs2xml:
        """ create xml text from directory data structure """
        def __init__(self, data):
            self.text = ""
            for item in data:
                self.processData(item, level=0)
            self.text = string.strip(string.replace(self.text,",</","</"))
            if self.text[-1] == ",":
                self.text = self.text[:-1]
            
        def processData(self, t, level):
            if len(t) < 2: return
            """ recursive function for directories """
            spacer = "    " * level
            if isinstance(t, types.ListType):
                if len(t[1]) == 0:
                    self.text += spacer + '<dir name="%s"/>\n' % (t[0])
                else:
                    self.text += spacer + '<dir name="%s">\n' % (t[0])
                    for item in t[1]:
                        self.processData(item, level=level+1)
                    self.text += '</dir>\n'
            else:
                self.text += t + ","

    def writeDirectories(self):
        self.writeln("<Directories>")
        x = self.dirs2xml(self.config.Dirs)
        self.writeln(x.text)
        self.writeln("</Directories>")
        

