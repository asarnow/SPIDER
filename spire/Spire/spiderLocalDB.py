# $Id: spiderLocalDB.py,v 1.1 2012/07/03 14:21:59 leith Exp $
#
# functions for connecting to your site's database

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
# This file should contain site-specific code for establishing
# a database connection.
#
try:
    import MySQLdb
except ImportError, e:
    pass
    #print "import error: %s" % e

import os
import GB

"""
This module contains code that allows Spire to access a MySQL database.

You must first:
- have MySQL installed,
- have the MySQL server started,
- have the Python mySQL interface, MySQLdb, installed
  (download from sourceforge.net/projects/mysql-python)
- MySQL should allow anonymous access to the database and table.
- Edit the _DATABASE, _TABLE, _USER, _PASSWORD, and _MAP variables below to
  reflect your MySQL database.

Copy this file, spiderLocalMysql.py, to spiderLocalDB.py, and run spire.
-----------------------
Using MySQLdb in Python:

    # After importing MySQLdb, create a connection object:
   
    import MySQLdb
    conn=MySQLdb.connect(db=_DATABASE, user=_USER, passwd=_PASSWORD)

    # Then you can perform queries and fetch the results:
    
    c = conn.cursor()
    query = "SELECT spam, eggs, sausage FROM breakfast_table"
    c.execute("%s" % (query,) )
    results = c.fetchall()

See the MySQLdb documentation.
-----------------------------
See the Spire documentation:
www.wadsworth.org/spider_doc/spider/docs/spire/database.html
"""

_DATABASE = 'test_spire'    # eg, for MySQL 'use database' command
_TABLE = 'projects'
_USER = ''
_PASSWORD = ''

########################################################################
# _MAP is a list of (key, column) pairs, in which the keys are VARIABLE
# NAMES EXPECTED BY SPIRE, and columns are the names of columns in the
# MySQL database. DO NOT EDIT THE KEYS.
#
#
# EDIT THE FOLLOWING COLUMN NAMES TO CORRESPOND TO YOUR MySQL DATABASE
# (they should all be strings)
#
######################################################################
#        keys          column names
_MAP = [('id',        'project_id'),  # Project ID number
        ('title',     'Title'),       # Project title
        ('dataext',   'Data_ext'),    # 3-letter SPIDER data extension
        ('projdir',   'Project_dir'), # working directory of project
        ('pixelsize', 'pixelsize'),   # in Angstroms
        ('kv',        'kV'),          # electron voltage
        ('Cs',        'Cs')]          # spherical aberration

# Dictionary of project information for getProjectInfo()
ProjDict = {}
# Column names in MySQL project database
Columns = []

for item in _MAP:
    key = item[0]
    ProjDict[key] = ""   # initialize dictionary with empty strings
    Columns.append(item[1])
    
# Create query to fetch project data
gp = 'SELECT %s, %s, %s, ' % (Columns[1], Columns[2], Columns[3])
gp += '%s, %s, %s ' % (Columns[4], Columns[5], Columns[6])
gp += 'FROM __project_table__ WHERE %s=__project_id__' % (Columns[0])
# __project_table__ and __project_id__ must be replaced
projectquery = gp

"""
spiderDatabase class: the following attributes and methods are required:

  Attributes - set in __init__() as self.id, etc
 
     id : Project ID number (as a string) set from global variable GB.P.ID
     
     databaseName : a name to present to users, e.g. "the project database".
     
     projectquery : an SQL query that fetches data required by Spire (see below).

  Methods (the (self) argument is not shown):

    __init__ : it should set/create the above attributes, as well as the
               dictionary returned by getProjectInfo()

    isExtDatabaseAlive() : returns 1 or 0 depending on whether it can
                           successfully connect.

    sendQuery(query) : returns result of the input SQL statement.

    getProjectInfo() : obtains project information required by Spire. It must
                       return a dictionary (or zero if there is an error).
                       The dictionary keys must be:
                       'id', 'title', 'dataext', 'projdir', 'pixelsize', 'kv', 'Cs'
                       The value for each key is obtained from the database.

    upload(upload_object) : given an uploadable object, establish a connection
                            and insert data into appropriate places.
    
"""
class spiderDatabase:
    
    def __init__(self):
        " set attributes "
        self.id = GB.P.ID            # project id
        self.DATABASE = _DATABASE
        self.TABLE = _TABLE
        self.USER = _USER
        self.PASSWORD  = _PASSWORD
        self.databaseName = "the MySQL database"
        
        qy = projectquery.replace('__project_table__', self.TABLE)
        self.projectquery = qy.replace('__project_id__', self.id)
        
        self.connection = None
        self.Map = _MAP
        self.ProjDict = ProjDict

    def connect(self):
        " sets self.connection object "
        if self.connection != None and self.connection.open:
            return 1
        try:
            self.connection=MySQLdb.connect(db=self.DATABASE,
                                            user=self.USER,
                                            passwd=self.PASSWORD)
            return 1
        except:
            return 0

    def isExtDatabaseAlive(self):    
        if self.connect():
            self.connection.close()
            return 1
        else:
            return 0

    def close(self):
        self.connection.close()

    def sendQuery(self,qstring):
        if not self.connect():
            return "Unable to connect to %s" % self.databaseName
        c = self.connection.cursor()
        c.execute("%s" % (qstring,) )
        q = c.fetchall()
        c.close()
        if len(q) > 0:
            return q[0]  # because database fetch returns a ( (tuple), )
        else:
            return ""
    
    def getProjectInfo(self):
        if not self.connect():
            GB.errstream("Unable to connect to %s" % self.databaseName)
            return
        
        output = self.sendQuery(self.projectquery)
        self.connection.close()
        #print "output %s" % str(output)
        if len(output) > 5:
            self.ProjDict['title'] = output[0]
            self.ProjDict['dataext'] = output[1]
            self.ProjDict['projdir'] = output[2]
            self.ProjDict['pixelsize'] = output[3]
            self.ProjDict['kv'] = output[4]
            self.ProjDict['Cs'] = output[5]
            return self.ProjDict
        else:
            GB.errstream("Database error: %s" % str(output))
            return 0

    def upload(self, uploadobj, outputfunction):
        output = outputfunction
        if not self.connect():
            output("Unable to connect to database")
            return
        for item in uploadobj:
            table = item[0]
            column = item[1]
            dtype = item[3]
            value = item[4]
            if dtype == 'text_file' or dtype == 'binary':
                filename = value
            
            if dtype == 'string':
                sqlstr = "UPDATE %s set %s = %s where Project_ID = %s"\
                         ";" % (table, column, value, GB.P.ID)
                res =self.sendQuery(sqlstr)
                if res != "": output(res)
                
            elif dtype == 'text_file' or dtype == 'binary':
                if os.path.exists(filename):
                    try:
                        if dtype == 'binary':
                            fp = open(filename, 'rb')
                        else:
                            fp = open(filename)
                        F = fp.read() # read in entire file as a string
                        fp.close()
                    except:
                        output("unable to open %s for reading" % filename)
                        continue
                else:
                    output("unable to find %s" % filename)
                    continue
                sqlstr = "UPDATE %s set %s = %s where Project_ID = %s"\
                         ";" % (table, column, MySQLdb.string_literal(F), GB.P.ID)
                res =self.sendQuery(sqlstr)
                if res != "": output(res)
                         
##########################################################################
# upload section : transfer data to the external database
#
# specify data to be loaded. Each item is a list:
#
# [table, column, prompt, type, default]
#
#  table : database table to insert into
#  column: column_name to insert into
#  prompt: a more user-friendly descriptive label
#  type : must be one of ("string", "text_file", "binary")
#         string is a value, such as "15.6A",
#         text_file is a text file to be inserted in its entirety,
#         binary is a binary file (image, volume) to be loaded.
#  default: default file for text & binary, leave "" for string
table = 'projects'
upload_data = [
    [table, 'Resolution',   'Resolution',    "string",    ""],
    [table, 'res_curve',  'resolution curve', "text_file", "Reconstruction/combires"],
    [table, 'res_plot',   'resolution plot', "text_file", "Reconstruction/plot_res"],
    [table, 'res_image', 'image of resolution curve', 'binary', 'Refinement/plot01.gif']
    ]
    
