#!/usr/bin/env python
#
# SOURCE:  install.py
#
# PURPOSE: Installs SPIDER python tools.
#          Puts executables in directory: tools/bin

import  os,sys, glob
from    commands import getoutput
from    shutil import copy, copytree, rmtree
import  findprog, testinstall

# 20 apps
apps = ['binarytree.py',               'montagefromdoc.py',
        'classavg.py',                 'montage.py',
        'ctfcircle.py',                'pyplot.py',
        'ctfdemo.py',                  'qview.py',
        'ctfgroup.py',                 'scatter.py', 
        'ctfmatch.py',                 'spiconvert.py',
        'emancoords2spiderdoc.py',     'verifybyview.py',
        'emanrctcoords2spiderdoc.py',  'viewstack.py',
        'mkapps.py',                   'xmippsel2spiderdoc.py',
        'mkfilenums.py',               'xplor.py']


tools_install_dir = os.getcwd()
bindir            = os.path.join(tools_install_dir, "bin")
pybindir          = os.path.join(tools_install_dir, "bin-python")

# Python executable for tools
Pythonprog        = os.path.join(pybindir, "python")

if not os.path.exists(Pythonprog):
    print " Unable to find executable python: %s" % Pythonprog
    sys.exit(1)
    
# Test if packages required for tools are present ---------------------
res = testinstall.testinstall()

# Create executable tool scripts  -------------------------------------
for app in apps:
    appscript, ext = os.path.splitext(app)
    app_path  = os.path.join(bindir,app)
    app_short = os.path.join(bindir,appscript)
    
    if ext != ".py" or not os.path.exists(app_path):
        print " Not found: %s" % app
        continue

    txt   = "#!/bin/sh\n\n"
    txt  += 'exec "%s" "%s" "$@"' % (Pythonprog, app_path)
              
    print " Creating script: %s" % appscript
    try:
        fp = open(app_short, 'w')
        fp.write(txt)
        fp.close()
        os.chmod(app_short, 0775)
	
    except:
        print " Unable to create: %s script" % app_short

      
# Add to path in shell startup script -------------------------------

path = os.environ['PATH']
if bindir in path:
    print " Setup complete"    # Done
    sys.exit()

print " Executables in %s must be in your path." % (bindir)    
print " You can either"
print " 1) Add %s to your path, or" % bindir
print " 2) Copy the files in %s to another directory located on your path" % bindir

shell = os.environ['SHELL']
if shell[-3:] == 'csh':
    cshrc = os.path.expanduser("~" + os.environ['USER'] + "/.cshrc")
    print #cshrc
    if os.path.exists(cshrc):
        print " The following line can be added to your .cshrc file:"
        newpath = " set path =(%s $path)" % bindir
        print newpath
        yn = raw_input(" Shall I add it for you? (y/n): ")
        yn = yn.lower()
        if yn == 'y' or yn == 'yes' or yn == 'Y':
            old_cshrc = cshrc + ".old"
            copy(cshrc, old_cshrc)
            fp = open(cshrc,"a")
            fp.write("\n# added by SPIDER python tools installation %s\n" % date)
            fp.write(newpath + "\n")
            fp.close()
            print " Installation complete. Type:"
            print " source %s" % cshrc
            print " to be able to run SPIDER python tools"
            
elif shell[-4:] == 'bash':
    bashrc = os.path.expanduser("~" + os.environ['USER'] + "/.bashrc")
    print #bashrc
    if os.path.exists(bashrc):
        print " The following line can be added to your .bashrc file:"
        newpath = "export PATH=%s:$PATH" % bindir
        print newpath
        yn = raw_input(" Shall I add it for you? (y/n): ")
        yn = yn.lower()
        if yn == 'y' or yn == 'yes':
            old_bashrc = bashrc + ".old"
            copy(bashrc, old_bashrc)
            fp = open(bashrc,"a")
            fp.write("\n# added by SPIDER python tools installation %s \n" % date)
            fp.write(newpath + "\n")
            fp.close()
            print " Installation complete. Type:"
            print " source %s" % bashrc
            print " to be able to run SPIDER python tools"







 
  
  
  
  
