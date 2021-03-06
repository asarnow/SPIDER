# SPIDER Batch file functions
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
# runbatch starts batchLoop (separate thread) then returns control to the GUI.
# batchloop calls execBatch for each batch file in the list (sequentially).
# execBatch,
#   - starts an execWindow,
#   - creates the script file, runs the Spider process,
#   - calls checkPid, which monitors the progress of that process.
#   - If the user presses the Stop button, execWin can also cleanup.
import os
import threading
import time

import GB, GG
from spiderUtils import *
from spiderGUtils import *
from spiderFilenums import *
#from spiderExecwin import mkExecWindow, execBatchCleanup
import spiderResult
import spiderBatch
import spiderFilenums
import spiderExecwin
from spiderReplace import batReplace
from spiderClasses import SpiderBatchRun

# ExecBatch is a thread that runs a batch files in the specified directory.
# If it completes successfully, it returns the run ID number (as a string),
# otherwise, it returns the string "-1".
def execBatch(batdir, batfile): 
    if batdir == "" or batdir == None or batfile == "" or batfile == None:
        return -1
    if batdir == ".":
        batdir = GB.P.projdir
    # create a class instance of BatchRun
    br = spiderBatch.BatchRun()
    br.batfile = batfile
    br.dir = batdir
    br.projID = GB.P.ID
    br.host = GB.P.host      
    br.pid = "0"
        
    # get the thread name
    threadname = threading.currentThread().getName()
    batdir = os.path.basename(br.dir)
    
    if os.path.basename(GB.P.projdir) != os.path.basename(batdir):
        execdir = os.path.join(GB.P.projdir,batdir)
    else:
        execdir = GB.P.projdir
    execdir = truepath(execdir)
    
    if not chdir(execdir):
        return -1

    if not os.path.exists(batfile):
        displayError("Unable to find " + batfile)
        return -1

    # check if batch file uses file numbers
    useFileNums = useFileNumbers(os.path.join(execdir,batfile))
    newfilenums = None

    filenumbers = None
    if useFileNums:
        # use values in the File Numbers entry box and temp filenum file
        if GG.prefs.useFilenumsEntry:
            fns = GG.disp_fnums.get() # check the entry box
            if fns == None or fns == "":
                txt = "No file numbers have been specified.\nContinue anyway?"
                if not askOKorCancel(txt,"No file numbers!"):
                    return -1
            else:
                newfilenums = uniqueFilename(prefix='fn', extension=GB.P.dataext)
                readFileNumbers(filenumFile=newfilenums)  # writes entrybox to file
                br.filenumfile = newfilenums
        else:
            readFileNumbers()  # writes to default filenums file

    # change filenumbers file; change EN D --> EN
    # First, save the original batch text
    originalBatch = fileReadLines(batfile)   #savecopy(batfile)
    #print "original batch in " + originalBatch
    ret = batReplace(batfile, filenumfile=newfilenums,
                     deleteResult=GG.prefs.saveResults,
                     netexec=GG.sysprefs.netexec)
    if ret == -1:
        return
    writeResult = int(GG.prefs.saveResults)
    
    runbat,ext = os.path.splitext(batfile)
    ext = ext[1:]   # remove dot from extension

    cmd = GG.sysprefs.spider + " " + ext + "/" + GB.P.dataext + " @" + runbat
    GB.outstream( "\nSending command: %s \n" % cmd)

    # create the execWindow
    ew = spiderExecwin.mkExecWindow(execdir, cmd, br)

    if not writeResult:
        maxResLines = GG.prefs.MaxResultLines
    else:
        maxResLines = 20

    maxlines = GG.prefs.MaxResultLines

    # -----------------------------------------------------------------------
    # --------- above this line is the same as spiderBatch ------------------
    # -----------------------------------------------------------------------
    
    #winid = str(id(ew))  # unique id for this process window
    # make a set of temporary files
    spdout = "spire.out" 
    spderr = "spire.err"  
    delete(spdout)
    delete(spderr)
    br.spdout = spdout
    br.spderr = spderr

    # ############ make the shell script  #####################
    #
    #   #!/bin/csh
    #   cd local_exec_dir
    #   set a="(/path/spider bat/etu @power > $1 ) >&  $2 &"
    #   (eval $a > /dev/null ) >& spdpid
    #   cat spdpid
    #   rm spdpid 
    # The eval cmd sends the PID to stderr (spdpid), so it can be
    # read by the getoutput command. C shell only
    # redirect = ' >& '
    br.script = "spire.csh"  
    shcmd = "#! /bin/csh -f\n"
        
    B = [shcmd]
    setline = 'set a="( %s > %s ) >& %s &"\n' % (cmd, spdout, spderr)
    B.append(setline)
    B.append('(eval $a > /dev/null ) >& spdpid\n')
    B.append('cat spdpid\n')
    B.append('rm spdpid\n')

    if fileWriteLines(br.script, B) != 1:
        spiderExecwin.execBatchCleanup(ew=ew, success=0)
        return -1
    os.chmod(br.script, 0777)
    
    # execute the shell script.
    # rsh host 'cd /path/to/the/execdir; spire.csh'
    host = br.host
    scmd = "%s %s 'cd %s; %s'" % (GB.remotecmd, host, execdir, br.script)
    #print "getSpiderPID before executing script"
    pidlist = getSpiderPID(host) # pidlist without this spider run
    GB.outstream("Sending: %s" % scmd)

    # --------------------------------------------------
    # !!!!!!!!!!!!!! run SPIDER !!!!!!!!!!!!!!!!!!!!!!!!
    # --------------------------------------------------
    shellreturn = getCommandOutput2(scmd)

    # now get pid from shellreturn
    a = string.find(shellreturn, ']') # should have form: "[1] 58988"
    if a > -1:
        pid = shellreturn[a+1:]
        try:
            string.atoi(pid)
            br.pid = string.strip(pid)
            ew.insertpid(pid)
            #GB.outstream( "pid: " + pid + "\n")
        except:
            displayError('Problem with Process ID : ' + pid)
            spiderExecwin.execBatchCleanup(ew,0)
            return -1
    else:
        displayError('Unable to get Process ID from\n' + shellreturn)
        spiderExecwin.execBatchCleanup.cleanup(ew,0)
        return -1

    # Read stdout (spdout) until find "Results file..."    
    while 1:
        if os.path.exists(spdout):
            s = fileReadLines(spdout)
            okdone = 0
            for line in s:
                if string.find(line, "Results file") > -1:
                    okdone = 1
            if okdone:
                spdoutmsg = []
                for line in s:
                    d = string.rstrip(line) + "\n"
                    spdoutmsg.append(d)
                    GB.outstream.write(d)  # write doesn't include '\n'
                break

    # get the actual results filename
    br.resultfile = ""
    for line in spdoutmsg:
        v = line.find("VERSION:")
        if v > 0:
            versionline = string.strip(line[v:])
            a = line.find('UNIX')
            b = line.find('ISSUED')
            if a > -1 and b > -1 and b > a+4:
                spiderversion = string.strip(line[a+4:b])
        elif line.find("Running:") > -1:
            runningline = string.strip(line.replace("Running:", ""))

    (results, xdate, xtime) = spiderResult.getResultsFilename(spdoutmsg)
    br.resultfile = results
                    
    if br.resultfile == "":
        displayError('Results file not found in output')
        spiderExecwin.execBatchCleanup(ew,0)
        return -1
    else: 
        ew.insertres()
        br.date = xdate
        br.time_start = (xdate, xtime)
        # checkPid:  now we wait until the Spider process is done....
        checkPid(br.pid, br.host)

    #try:
        #id(ew)    # check if STOP button was pressed
    #except:
        #spiderExecwin.execBatchCleanup(ew,0)
        #return -1

    # process stderr (spderr) to get terminal condition (NORMAL|ERROR)
    spderr = readStdoutFile(br.spderr)

    # ----- same as spider Batch ----------
    stopline = ""
    for line in spderr:
        if string.find(line,"NORMAL") > -1:
            GB.outstream.write(line, 'green')
            stopline = line
        elif string.find(line,"ERROR") > -1:
            GB.outstream.write(line, 'red')
            stopline = line
        else:
            GB.outstream.write(line)
                   
    # restore the original batch file text
    fileWriteLines(batfile, originalBatch)

    # Successful run - save results to batch run object
    if stopline != "" and string.find(stopline," NORMAL ") > -1: # success
        if ew != None:
            try: ew.quit()
            except: pass

        GB.outstream(br.batfile + " finished successfully.")

        nline = 20  # get last 20 lines
        if maxResLines < 20: nline = maxResLines
        tailres = spiderResult.tailResults(br.resultfile)
        time_end = ()
        for t in tailres:
            if string.find(t,"COMPLETED") > -1:
                tr = string.split(t)
                time_end = (tr[-3],tr[-1])
                break
        if len(time_end) == 0:
            t = nowisthetime()
            time_end = (t[0],t[1])
            
        # Successful run - create a batchRun object (sets b.id)
        #                  ========================
        b = SpiderBatchRun() # spiderResult.readResults(br.resultfile)
        # set default values 
        b.id = makeRunID(br.time_start)
        b.batfile = batfile
        b.dir = batdir
        b.dataext = GB.P.dataext
        b.host = GB.P.host
        b.time_start = (xdate,xtime)
        b.time_end = time_end
        b.projID = GB.P.ID
        b.results = br.resultfile
        B = fileReadLines(batfile)
        b.text = B
        b.filenumbers = ""
        b.parameters = getParms()
        b.spiderversion = spiderversion
        b.spidercmd = [runningline, versionline]

        if useFileNums and filenumbers != None:
            b.filenumbers = filenumbers
        
        GB.outstream.write( 'Reading the results file %s...  ' % b.results)
        [doclist, binlist] = spiderResult.newOutputs(b.results)
        GB.outstream.write( ' done.\n')
        b.outfiles = [doclist, binlist]
        
        nfiles = len(doclist) + len(binlist)
        if nfiles > 1: savetxt = "%d files from " % nfiles
        elif nfiles == 1: savetxt = "%d file from " % nfiles
        else: savetxt = ""
        savetxt += '%s saved to %s\n' % (br.batfile, GB.P.projfile)
                
        saveBatchRun(b)
        GB.outstream(savetxt)
        GG.spidui.write_queue('GG.topwindow.bell()') 

        if windowExists("Project Table") and hasattr(GG,'projectTable'):
            func = GG.projectTable.addRow
            GG.spidui.write_queue([func, (b,)] )  # b = batchrun
            #GG.spidui.write_queue("self.testfunction()")
            GG.spidui.write_queue("GG.projectTable.seeLastRow()")

        if not writeResult:
            delete(br.resultfile)

        spiderExecwin.execBatchCleanup(ew=ew, success=1)
        return b.id      # *******  successful run  *******
           
    else: # error in spider run
        print "%s : error in spider run" % (batfile)
        GG.spidui.write_queue('GG.topwindow.bell()')
        print br.resultfile
        print spderr
    
        m = spiderResult.tailResults(br.resultfile)
        #print m
        for line in m:
            GB.outstream.write(line)
        spiderExecwin.execBatchCleanup(ew=ew, success=0)
        return -1

# ----- end of execBatch

# returns tuple: (year, mo, day, hr, min, sec, weekday, day#, dst)
def checkPid(pid, host):  # pid is a string
    sleeptime = 0.5 # seconds - put in GB

    while 1:
        time.sleep(sleeptime)
        pidlist = getSpiderPID(host)
        if pid in pidlist:
            continue
        else:
            return time.localtime(time.time())


# returns a list of PIDs running spider
def getSpiderPID(host):   # =None, user=None):
    #if host == None: host = gethostname()  # not used?
    user = os.environ["USER"]
    cmd = makeCommand("ps -u %s | grep spider" % user)
    #print "getSpiderPID: " + cmd
    out,err = getCommandOutput(cmd)
    if len(out) == 0:
        return []
    
    B = []
    k = string.split(out,'\n')
    for line in k:
        i = string.strip(line)
        if i != "":
            B.append(i)

    if len(B) == 0:
        return []
	
    S = []
    for item in B:
        s = string.split(item)
        d = s[0]
        try:
            pid = string.atoi(d)   # see if it's a digit
            S.append(d)
        except ValueError,IndexError:
            pass      
    return S

def readStdoutFile(spdfile):
    E = []
    if os.path.exists(spdfile):
        s = fileReadLines(spdfile)
        for line in s:
            d = string.replace(line, "\012", "\n")
            E.append(d)
    return E 
  
