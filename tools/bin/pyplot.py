#! /usr/bin/env python

# SOURCE:  pyplot.py 
# PURPOSE: Graphical interface for gnuplot.
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

from   Tkinter import *
import Pmw
import tkMessageBox  # Used for showerror
from   tkFileDialog import asksaveasfilename, askopenfilename
import Gnuplot, Gnuplot.funcutils
import os
import sys

class MyGnuplotPlot:
    
    # input datafiles in list form
    def __init__(self, master, args):

        self.topwindow = master
        self.topwindow.title('Gnuplot')
        #self.setOptionDB()

        class Dummy: pass
        self.var = Dummy()    # declares var an instance of Class Dummy
                              # used by the Checkbutton widgets
        self.displaylist = []
        self.gnuplot = Gnuplot.Gnuplot()
        
        self.plotstrVar = StringVar() ; self.plotstrVar.set("")
        self.x = StringVar()
        self.x.set("")
        self.y = StringVar()
        self.y.set("")
        self.xrange = ""
        self.yrange = ""
        self.cols = StringVar()
        self.cols.set("1:3")
        self.linestyleVar = StringVar()   ; self.linestyleVar.set('lines')
        self.gridVar = IntVar()           ; self.gridVar.set(0)
        # toggles plot command window
        self.messageVar = IntVar()        ; self.messageVar.set(0)
        
        for f in args:
            self.displaylist.append(f)

        self.makemenu()

        self.cblist = []
        self.sf = Pmw.ScrolledFrame(self.topwindow)
        self.f2 = self.sf.interior()
        self.f2.configure(background='white')

        self.showFiles()

        f3 = Frame(self.topwindow, relief=RAISED, borderwidth=1)
        Label(f3, text="set x range:").grid(row=0, column=0, sticky=W)
        xentry = Entry(f3, width=16, textvariable=self.x)
        xentry.grid(row=0, column=1)
        xentry.bind('<Return>', self.plotSelected)

        Label(f3, text="set y range:").grid(row=1, column=0, sticky=W)
        yentry = Entry(f3, width=16, textvariable=self.y)
        yentry.grid(row=1, column=1)
        yentry.bind('<Return>', self.plotSelected)

        Label(f3, text="set columns:").grid(row=2, column=0, sticky=W)
        centry = Entry(f3, width=16, textvariable=self.cols)
        centry.grid(row=2, column=1)
        centry.bind('<Return>', self.plotSelected)

        f3.pack(side='bottom', fill='x', expand=1, anchor='s')
        # pack the list box last
        self.sf.pack(side=TOP, fill=BOTH, expand=1, padx=5, pady=5, anchor='center')

        #self.plotSelected()  # graph the selected items

    def makemenu(self):
        # ------- create the menu bar -------
        self.mBar = Frame(self.topwindow, relief='raised', borderwidth=1)
        self.mBar.pack(side='top', fill = 'x')

        # Make the File menu
        Filebtn = Menubutton(self.mBar, text='File', underline=0,
                                 relief='flat')
        Filebtn.pack(side=LEFT, padx=5, pady=5)
        Filebtn.menu = Menu(Filebtn, tearoff=0)
        Filebtn.menu.add_command(label='Clear', underline=0,
                                 command=self.uncheck)
        Filebtn.menu.add_command(label='Add', underline=0,
                                 command=self.add_data)
        Filebtn.menu.add_command(label='Save', underline=0,
                                 command=self.save)
        Filebtn.menu.add_command(label='Print', underline=0,
                                 command=self.psprint)
        Filebtn.menu.add_separator()
        Filebtn.menu.add_command(label='Quit', underline=0, command=self.topwindow.quit)
        Filebtn['menu'] = Filebtn.menu

        # Make the Option menu
        Optbtn = Menubutton(self.mBar, text='Options', underline=0, relief='flat')
        Optbtn.pack(side=LEFT, padx=5, pady=5)
        Optbtn.menu = Menu(Optbtn, tearoff=0)

        # the options menu has a submenu for linestyles
        Optbtn.menu.styles = Menu(Optbtn.menu, tearoff=0)
        Optbtn.menu.styles.add_command(label='lines', underline=0,
                                      command=lambda t='lines': self.lineStyles(t))
        Optbtn.menu.styles.add_command(label='points', underline=0,
                                      command=lambda t='points': self.lineStyles(t))
        Optbtn.menu.styles.add_command(label='boxes', underline=0,
                                      command=lambda t='boxes': self.lineStyles(t))
        Optbtn.menu.add_cascade(label='line style', underline=0,
                                menu=Optbtn.menu.styles)
        
        Optbtn.menu.add_checkbutton(label='grid', underline=0, variable=self.gridVar,
                                    command=self.replot)
        Optbtn.menu.add_checkbutton(label='show command', underline=0,
                                    variable=self.messageVar,
                                    command=self.messageWindow)
        Optbtn['menu'] = Optbtn.menu

        # replot button
        replot = Button(self.mBar, text='Replot', command=self.replot)
        replot.pack(side='right', padx=5, pady=5)

        

    def lineStyles(self, t='lines'):
        self.linestyleVar.set(t)
        self.replot()

    def replace(self, filelist):
        self.uncheck()
        self.cblist = []
        self.removeFiles()
        self.displaylist = filelist  #["power/ctf021.hrs", "power/ctf022.hrs"]
        self.showFiles()
        self.selectAll()
        self.plotSelected()

    def removeFiles(self):
        for item in self.cblist:
            item.pack_forget()
            del(item)
            
        keys = self.f2.children.keys()
        for key in keys:
            wgt = self.f2.children[key]
            wgt.pack_forget()
            del(self.f2.children[key])
        self.f2.update_idletasks()
        

    def showFiles(self):
        for item in self.displaylist:
            setattr(self.var, item, IntVar())
            c = Checkbutton(self.f2, text=item, anchor=W,
                            variable=getattr(self.var, item))
            c.deselect()
            self.cblist.append(c)
            c.bind('<ButtonRelease-1>', self.plotSelected)
            
        for item in self.cblist:
            item.pack(side=TOP, anchor='w')
            
    def setOptionDB(self):
        self.topwindow.option_add('*font', 'Arial 12')
        self.topwindow.option_add('*Entry*background', 'white')
        self.topwindow.option_add('*foreground', 'black')
        #self.topwindow.option_add('*background', 'white')

    def set_xrange(self, xstring):
        self.x.set(xstring)
        
    def set_yrange(self, ystring):
        self.y.set(ystring)
        
    def set_columns(self, cstring):
        self.cols.set(cstring)

    def current_list(self):
        vlist = []
        slist = []
        for item in self.displaylist:
            x = getattr(self.var, item)
            y = x.get()
            vlist.append(y)
            
        n = len(self.displaylist)
        for i in range(n):
            if vlist[i] != 0:
                #f = string.split(self.displaylist[i])
                f = self.displaylist[i].split()
                slist.append(f[0])
        slist.sort()
        colstr = self.validateColumns()
        self.cols.set(colstr)
        return slist

    def plotSelected(self,event=None):    # plots the current selected list
        slist = self.current_list()
        self.plotter(slist)

    def selectAll(self):
        for button in self.cblist:
            button.select()

    def add_data(self, datafiles=None):
        if datafiles == None or len(datafiles) == 0:
            datafiles = askopenfilename(multiple=1)
        if datafiles == None or len(datafiles) == 0:
            return
        for item in datafiles:
            #d = os.path.basename(item)
            d = item
            self.add2list(d)

    def add2list(self,item):
        if item not in self.displaylist:
            self.displaylist.append(item)
            setattr(self.var, item, IntVar())
            c = Checkbutton(self.f2, text=item, anchor=W,
                            variable=getattr(self.var, item))
            c.deselect()
            c.bind('<ButtonRelease-1>', self.plotSelected)
            c.pack(side=TOP, anchor='w')
            #self.plotSelected()
        else:
            tkMessageBox.showerror('Error', '%s is already in the list' % item)

    def uncheck(self):
        for item in self.displaylist:
            x = getattr(self.var, item)
            x.set(0)
                
    def save(self):
        self.xrange = self.validateRange('x')
        self.yrange = self.validateRange('y')
        slist = self.current_list()
        if len(slist) == 0: return

        plotstr = self.plotstrVar.get()
        # replace ', \n' with ', \ \n'  (i.e. add slash)
        plotstr = plotstr.replace(",",", \\")

        fname = asksaveasfilename()
        if fname == "": return
        
        fp = open(fname, 'w')
        if self.xrange != "":
            fp.write(self.xrange + "\n")
        if self.yrange != "":
            fp.write(self.yrange + "\n")
        fp.write(plotstr + "\n")
        fp.close()

    def psprint(self):
        pstr = "set term post; set output 'plot.ps'; replot; set output; set terminal x11"
        self.gnuplot(pstr)
        cmd = "lp -ops plot.ps"
        print cmd
        os.system(cmd)
        print os.system("lpstat")
        
    def checkColRange(self,yrange):
        if yrange.find(":") == -1: return -1
        if yrange.find(","): # may be multiple ranges
            cs = yrange.split(",")
            for s in cs:
                if s.find(":") < 0:
                    return -1
                ss = s.split(":")
                try:
                    i = int(ss[0])
                    i = int(ss[1])
                except:
                    return -1
            return 0
        V = yrange.split(":")
        for item in V:
            if item != '':
                try:
                    i = int(item)
                except ValueError, e:
                    return -1
        return 0
        
    def rangeError(self):
        tkMessageBox.showerror('Error', 'Entries must be of the form:\n\tLo:Hi\n where Lo and Hi are numbers')

    def validateColumns(self):
        colstr = self.cols.get()
        if colstr != "":
            if (self.checkColRange(colstr) != 0):
                self.rangeError()
                return self.cols.get()
            
        if colstr == "": colstr = self.cols.get()
        return colstr
        
    def checkRange(self, xyrange):
            if xyrange.find(":") < 0: return -1
            V = xyrange.split(":")
            for item in V:
                if item != '':
                    try:
                        float(item)
                    except ValueError, e:
                        return -1
            return 0
        
    def validateRange(self,xy):
        if xy == 'x':
            self.xrange = self.x.get()
            if self.xrange != "" and self.xrange != None:
                if self.xrange[0] == '[':
                    self.xrange = self.xrange[1:]
                if self.xrange[-1] == ']':
                    self.xrange = self.xrange[:-1]
                if (self.checkRange(self.xrange) != 0):
                    self.rangeError()
                    return ""
                self.xrange = "set xrange[%s]" % (self.xrange)
            return self.xrange
        elif xy == 'y':
            self.yrange = self.y.get()
            if self.yrange != "" and self.yrange != None:
                if self.yrange[0] == '[':
                    self.yrange = self.yrange[1:]
                if self.yrange[-1] == ']':
                    self.yrange = self.yrange[:-1]
                if (self.checkRange(self.yrange) != 0):
                    self.rangeError()
                    return ""
                self.yrange = "set yrange[%s]" % (self.yrange)
            return self.yrange

    def replot(self,event=None):
        "  plots the current selected list "
        self.plotter(self.current_list())
   
        
    def plotter(self,L):
        if len(L) == 0:
            self.gnuplot('clear')
            return
        
        self.xrange = self.validateRange('x')
        if self.xrange != "" and self.xrange != None:
            self.gnuplot(self.xrange)
        else:
            self.gnuplot('set autoscale x')

        self.yrange = self.validateRange('y')
        if self.yrange != "" and self.yrange != None:
            self.gnuplot(self.yrange)
        else:
            self.gnuplot('set autoscale y')

        s = self.linestyleVar.get()
        if s in ['lines', 'points', 'boxes']:
            style = s
        else:
            style = 'lines'

        plotstr = ""
        if self.gridVar.get():
            self.gnuplot('set grid')
        else:
            self.gnuplot('set nogrid')
                
        #colstr = self.validateColumns()
        colstr = self.cols.get()

        if colstr.find(',') > 0:  # there are multiple ranges
            rangelist = colstr.split(',')
        else:
            rangelist = [colstr]

        # Create the plot string that will be sent to gnuplot 
        plotstr = "plot "
        
        for file in L:   # for each file...
            fname = os.path.basename(file)
            
            for cols in rangelist:  # plot each column range
                plotstr += "'%s' using %s title '%s' with %s," % (file,cols,fname,style)
                
        plotstr = plotstr[:-1]  # remove last comma               
                
        self.plotstrVar.set(plotstr.replace(',',',\n'))
        showcmd = self.messageVar.get()
        if showcmd:
            self.displayPlotString(plotstr)
            
        self.gnuplot(plotstr) # send the command to Gnuplot

    def quitmsgwindow(self):
        " called when msg window closed by window manager"
        self.msgwindow.destroy()
        self.messageVar.set(0)

    def messageWindow(self):
        " called by toggle in options menu. Destroys or creates msg window"
        showWindow = self.messageVar.get()

        if showWindow:
            if hasattr(self, 'msgwindow') and self.msgwindow.winfo_exists():
                pass
            else:
                self.msgwindow = Toplevel(self.topwindow)
                self.msglabel = Label(self.msgwindow,
                                      textvariable=self.plotstrVar)
                self.msglabel.pack()
                self.msgwindow.protocol("WM_DELETE_WINDOW", self.quitmsgwindow)

            self.msgwindow.lift()

        else:
            if hasattr(self, 'msgwindow'):
                if self.msgwindow.winfo_exists():
                    self.msgwindow.destroy()
                del(self.msgwindow)

        self.replot()   

    def displayPlotString(self, plotstr="Show gnuplot commands here"):
        if not self.messageVar.get():
            return
        
        qstr = plotstr.replace(',',',\n')
        
        if hasattr(self, 'msgwindow') and self.msgwindow.winfo_exists():
            pass
        else:
            self.msgwindow = Toplevel(self.topwindow)
            self.msglabel = Label(self.msgwindow, textvariable=self.plotstrVar)
            self.msglabel.pack()
        

    def lift(self):
        if self.topwindow.winfo_exists():
            self.topwindow.lift()

    def quit(self):
        del(self.gnuplot)
        self.topwindow.destroy()


#####################################################################
if __name__ == '__main__':
    
    root = Tk()

    filelist = []
    smallflag = 0
    
    nargs = len(sys.argv[1:])     
    if nargs > 0:
        if sys.argv[1] == '-s':
            smallflag = 1
            filelist = sys.argv[2:]
        else:
            filelist = sys.argv[1:]
    else:
        print " Usage: pyplot.py -s files*"
        print "  (optional -s flag for small font)"
        sys.exit()

    if not smallflag:
        Pmw.initialise(root, fontScheme = 'pmw1')
            
    app = MyGnuplotPlot(root,filelist)
    root.mainloop()
