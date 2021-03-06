#!/usr/bin/env python

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

print "tree.py, Modified 2009 Jun 05"
#    TO DO: add menu, save settings
#    TO DO: change depth on the fly
#    TO DO: initial directory
#    TO DO: draw from bottom
#    2009-06-04 -- reads existing selection file
#    2009-06-03 -- saves selection file
#    2009-06-02 -- allows skipped nodes

import sys
from Spider import Spiderutils
from Tkinter import *
import Image
import ImageTk
import os

def backup(filename):
    if os.path.exists(filename):
        found_vacancy = 0
        tiebreaker = 0
        shortdir = os.path.basename(os.path.dirname(filename))
        while not found_vacancy:
            test_filename = filename + '_' + str(tiebreaker)
            if os.path.exists(test_filename):
                tiebreaker += 1
            else:
                found_vacancy = 1
                short_old = os.path.join(shortdir, os.path.basename(filename))
                short_new = os.path.join(shortdir, os.path.basename(test_filename))
                print 'Renamed', short_old, 'to', short_new
                os.rename(filename, test_filename)

class BinaryTreeCanvas:
    def __init__(self, master, classTemplate, max_depth=5, savefilename='outfile.dat', 
	margin_width=3, canvasWidth=1600, labelBorder=3) :

	# store passed values
	self.master        = master
	self.classTemplate = classTemplate
	self.max_depth     = max_depth
	self.savefilename  = savefilename
	self.margin_width  = margin_width
	self.canvasWidth   = canvasWidth
	self.labelBorder   = labelBorder
	
	# initialize
	self.coords_dictionary={}
	self.photo_list=[]
	self.select_dictionary = {}

	# get image dimensions:  ix,iy = im.size  # dimensions
	classname = Spiderutils.template2filename(self.classTemplate,n=1)
	classavg = Image.open(classname)
#	self.xdim,self.ydim = classavg.size
	self.xdim = classavg.size[0] + 2*self.labelBorder
	self.ydim = classavg.size[1] + 2*self.labelBorder + self.margin_width

	# calculate canvas dimensions
	self.canvasx = 2**(self.max_depth-1)*(self.xdim + self.margin_width)
	self.canvasy = self.max_depth * self.ydim

	# define canvas
	self.tree_canvas = Canvas(self.master,height=self.canvasy)
	self.tree_canvas.configure(width=self.canvasx)
	self.tree_canvas.configure(scrollregion=(0,0,self.canvasx,self.canvasy))
	print 'Canvas dimensions:',self.canvasx,self.canvasy

	# scrollbars
	self.HscrollBar = Scrollbar(self.master, command=self.tree_canvas.xview, orient=HORIZONTAL)
	self.tree_canvas.configure(xscrollcommand=self.HscrollBar.set)
	self.HscrollBar.pack(side=BOTTOM, fill=X)
	
	self.VscrollBar = Scrollbar(self.master, command=self.tree_canvas.yview, orient=VERTICAL)
	self.tree_canvas.configure(yscrollcommand=self.VscrollBar.set)
	self.VscrollBar.pack(side=RIGHT, fill=Y)

	# colors
	self.good_color = 'green'
	self.select_flag = 1
	self.bad_color = 'red'

    def drawTree(self) :
	self.class2label = {}  # lookup table to find an image

	# loop through depths, from bottom
	for depthCounter in range(self.max_depth):  # range is 0..max_depth-1
	    currentDepth = depthCounter + 1
	    firstNode = 2**(currentDepth-1)
	    lastNode = 2**(currentDepth) - 1
	    nodesRow = lastNode-firstNode+1
	    bandWidth = self.canvasx / nodesRow
	    nodeCoordy = currentDepth * self.ydim

	    # loop through nodes
	    for rowNode in range(nodesRow):  # range is 0..nodesRow-1
		current_node = rowNode+firstNode  # range is firstNode..lastNode
		nodeCoordx = (rowNode+0.5)*bandWidth

		# write coordinates to dictionary
		self.coords_dictionary[str(current_node)] = [nodeCoordx,nodeCoordy]

		# if not top row, then draw line to parent node
		if currentDepth != 1 :
		    # calculate node# for daughter nodes
		    parentNode = current_node/2  # will convert to INT (rightly so) if odd

		    # get coordinates for daughter nodes
		    parentCoordx = self.coords_dictionary[str(parentNode)][0]
		    parentCoordy = self.coords_dictionary[str(parentNode)][1] - self.ydim + self.margin_width
	
		# check if image exists
		classname = Spiderutils.template2filename(self.classTemplate,n=current_node)
	
		# if file exists, then draw lines and paste image
		if os.path.exists(classname):
		    # draw line to parent
		    if currentDepth != 1 :
			self.tree_canvas.create_line(nodeCoordx,nodeCoordy-self.ydim, parentCoordx,parentCoordy, tag='parent_line')
			self.tree_canvas.lower('parent_line')  # otherwise lines are on top of images

		    # prepare image window and store info
		    classavg = Image.open(classname)
		    Tkimage = ImageTk.PhotoImage(classavg.convert2byte(), palette=256)
		    image_label = Label(self.tree_canvas, image=Tkimage, borderwidth=self.labelBorder)
		    image_label.photo = Tkimage
		    image_label.filenum = current_node
		    self.class2label[current_node] = image_label
		    image_label.bind('<Button-1>', lambda event, w=image_label : self.selectClass(w))
		    self.photo_list.append(image_label)

		    # draw image window
		    self.tree_canvas.create_window(nodeCoordx,nodeCoordy, window=image_label, anchor=S)
	
		    last_node = classname  # necessary?

	# Finish drawing
	self.tree_canvas.pack()
	self.master.bind('<Control-t>', self.test)
	self.master.bind('<Control-s>', self.saveSelections)
	self.master.bind('<Control-r>', self.readSelections)

    def test(self, event=None) :
	print "select_dictionary length:", len(self.select_dictionary)
	print "select_dictionary:", self.select_dictionary

    def selectClass(self, widget) :
	# get current color
	currentColor = widget.cget('background')
	
	# if current color isn't good color, then select
	if currentColor != self.good_color :
	    widget.configure(background=self.good_color)
#	    print "filenum:", widget.filenum
	    self.select_dictionary[widget.filenum] = self.select_flag
	else : # deselect
	    widget.configure(background=self.bad_color)
	    del self.select_dictionary[widget.filenum]

    def saveSelections(self, event=None) :
	headers = ['class_num']
	spiderDictionary = {}
	key = 0
	selectKeys = self.select_dictionary.keys()
	selectKeys.sort()
#	print "keys:", selectKeys

	for counter in selectKeys:
	    key = key + 1
	    spiderDictionary[key] = [counter, self.select_dictionary[counter]]
#	    print "spiderDictionary:", key, counter, self.select_dictionary[counter]

	# if non-empty, backup prior versions
	if len(self.select_dictionary) > 0 : backup(self.savefilename)

	if Spiderutils.writeSpiderDocFile(self.savefilename, spiderDictionary, headers=headers, append=1):
	    print 'Wrote', key, 'keys to %s' % os.path.basename(self.savefilename)
	else:
#	    showerror("Error!", "Unable to write to %s" % os.path.basename(self.savefilename))
	    print "Unable to write to", self.savefilename

    def readSelections(self, event=None) :
	if os.path.exists(self.savefilename):
	    goodclassdoc = Spiderutils.readSpiderDocFile(self.savefilename)
	    goodclasskeys = goodclassdoc.keys()
	    found_counter = 0

	    for key in goodclasskeys :
		filenumber = int(goodclassdoc[key][0])
		classnum   = int(goodclassdoc[key][1])

		# map particle to label and goodclass_label.configure
		if self.class2label.has_key(filenumber) :
#		    print "readSelections", key, filenumber, classnum, "found"
		    goodclass_label = self.class2label[filenumber]
		    goodclass_label.configure(background=self.good_color)
#		    goodclass_label.selectvalue = self.select_flag
		    self.select_dictionary[filenumber] = self.select_flag
		    found_counter = found_counter + 1
		else :
		    print "WARNING readSelections: image", key, filenumber, "not found"
	    print found_counter, "keys found"

	else:
	    print outfile, 'does not exist'

if __name__ == "__main__":

    argCounter = 0

    argCounter = argCounter + 1
    if sys.argv[argCounter:] :
        file_example = sys.argv[argCounter:]
        nodeTemplate = Spiderutils.name2template(file_example[0])
    #    print 'file template:', nodeTemplate
    else :
        print
        print "syntax: tree.py node_img001.ext {selectfile.ext max_depth margin_width canvas_width}"
        print
        sys.exit()

    argCounter = argCounter + 1
    if sys.argv[argCounter:] :
        max_depth = int(sys.argv[argCounter])
    else :
	max_depth = 5
    print 'max_depth:', max_depth

    argCounter = argCounter + 1
    if sys.argv[argCounter:] :
        savefilename = sys.argv[argCounter]
    else :
    #    print "template:", nodeTemplate
        extension = os.path.splitext(nodeTemplate)[1]
        savefilename = 'goodnodes' + extension
    print 'savefilename:', savefilename

    argCounter = argCounter + 1
    if sys.argv[argCounter:] :
        margin_width = int(sys.argv[argCounter])
	print 'margin_width:', margin_width

    argCounter = argCounter + 1
    if sys.argv[argCounter:] :
        canvasWidth = int(sys.argv[argCounter])
	print 'canvas_width:', canvasWidth

    argCounter = argCounter + 1
    if sys.argv[argCounter:] :
        labelBorder = int(sys.argv[argCounter])
	print 'image_border:', labelBorder

    root = Tk()
    root.title('tree.py')

    tree = BinaryTreeCanvas(root, nodeTemplate, max_depth=max_depth, savefilename=savefilename)
#        margin_width=margin_width, canvasWidth=canvasWidth, labelBorder=labelBorder)
    tree.drawTree()

    root.mainloop()
