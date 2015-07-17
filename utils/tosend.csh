#! /bin/csh
#
# SOURCE:  /usr8/spider/utils/tosend.csh
#
# PURPOSE: Update local copy of SPIDER distribution        
#          The distribution copy is currently in:  /usr8/send/spider/...
#
# NEXT:    The combined SPIDER/WB distribution can then be placed in a compressed
#            tar archive and put in the download directory on the
#            external SPIDER website.
#
# AUTHOR:  ArDean Leith                May 1994
#          FFTW added                  Nov 2005
#          Removed onecpp.perl call    Mar 2008
#          Nextresults                 Feb 2009
#          Rewrite for Linux & rsync   Mar 2009
#          Rewrite for /usr8           Jul 2010

echo 
echo "Did you run: /usr8/spider/docs/techs/recon/spr2tar.csh         first?"
echo "Did you run: /usr8/spider/docs/techs/recon1/Utils/spr2tar.csh  first?"
echo "Did you run: /usr8/spider/utils/create-tools-dist.csh          first?"
echo 

# Set some variables for input locations
set spiroot    = /usr8/spider    

set srcdir     = $spiroot/src
set bindir     = $spiroot/bin
set mandir     = $spiroot/man
set procdir    = $spiroot/proc
set docdir     = $spiroot/docs
set tipsdir    = $spiroot/docs/tips
set pubsubdir  = $spiroot/pubsub
set fftwdir    = $spiroot/fftw
set toolsdir   = $spiroot/tools
set spiredir   = $spiroot/spire 
   
set jwebdir    = /usr8/web/jweb 

# Set some variables for output locations
set destroot   = /usr8/send     

set srcdest    = $destroot/spider/src
set docdest    = $destroot/spider/docs 
set mandest    = $destroot/spider/man
set procdest   = $destroot/spider/proc
set bindest    = $destroot/spider/bin
set fftwdest   = $destroot/spider/fftw
set pubsubdest = $destroot/spider/pubsub
set spiredest  = $destroot/spider/spire
set toolsdest  = $destroot/spider/tools
set jwebdest   = $destroot/web/jweb

# Make necessary dir
mkdir -p $destroot/spider $srcdest $docdest $mandest 
mkdir -p $procdest $fftwdest $pubsubdest
mkdir -p $destroot $jwebdest

# Set rsync = verbose, compressed, update, 
#             preserve executability, preserve time, follow Symlinks
set sendit  = 'rsync -zuEtL --out-format="%n%L"  '

set excludes = "--exclude="RCS" --exclude="old" --exclude="rejects" --exclude="res" --exclude="rep" --exclude="Attic" "  


# ------------------ Copy source files --------------------------------

echo  'Copying src files. xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'

$sendit   $srcdir/*.f   \
          $srcdir/*.INC \
          $srcdir/Make* \
          $srcdir/*.inc \
          $srcdir/Nextversion   $srcdest

# Replace Makebody.inc with distribution version
$sendit $srcdir/Makebody.inc.send $srcdest/Makebody.inc

$sendit $srcdir/Makefile_samples/* $srcdest/Makefile_samples
 
# --------------------- Copy man files ---------------------------

echo 'Copying man files. xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'


$sendit   $mandir/*.man    \
          $mandir/*.also   \
          $mandir/*.gif    \
          $mandir/*spi     \
          $mandir/convert* \
          $mandir/Nextresults   $mandest

# For Nextresults
$sendit   $mandir/Nextresults   $bindest

# Copy external tip files -------------------------------------------
echo "Copying external docs/tips files xxxxxxxxxxxxxxxxxxxx" 
$sendit -d $tipsdir                    $docdest
$sendit    $tipsdir/index_send.html    $docdest/tips/index.html 
$sendit    $tipsdir/utilities.html      \
           $tipsdir/spiprogramming.html \
           $tipsdir/timebprp.spi        \
           $tipsdir/timing.html        $docdest/tips            
##$sendit $excludes -r  $tipsdir/batch  $docdest/tips  removed feb 2013
 
# --------------------- Copy PubSub* files ---------------------------
echo 'Copying pubsub files. xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'

$sendit $excludes  $pubsubdir/*   $pubsubdest

# --------------------- Copy proc files ---------------------------
echo 'Copying proc files. xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'

$sendit  $excludes       \
         $procdir/*.dat  \
         $procdir/*.bat  \
         $procdir/*.spi  \
         $procdir/*.py   \
         $procdir/*.img  \
         $procdir/*.tom  \
         $procdir/*.perl      $procdest

# --------------------- Copy Python tools files ----------------------

echo 'Copying Python tools files  xxxxxxxxxxxxxxxxxxx'
$sendit -r $excludes \
           $toolsdir/readme*      \
           $toolsdir/install.html \
           $toolsdir/docs         \
           $toolsdir/tools.tar       $toolsdest

# --------------------- Copy Spire files ---------------------------

echo 'Copying Spire distribution files. xxxxxxxxxxxxxxxxxxx'
$sendit -r $spiredir/readme*                      $spiredest
$sendit -r $spiredir/doc                          $spiredest
$sendit -r $spiredir/tosend/spire_linux-1.5.5.tar $spiredest

# --------------------- Copy JWeb files ---------------------------

echo 'Copying JWeb Linux, & Windows files. xxxxxxxxxxxxxxxx'
$sendit -r  $excludes       \
            $jwebdir/linux  \
            $jwebdir/win    \
            $jwebdir/src    $jwebdest

# --------------------- Copy  html doc files --------------------------

echo 'Copying html doc & tech files. xxxxxxxxxxxxxxxxxxxxxx'
$sendit $excludes -r --exclude="res" --exclude="rep"  --exclude="tips"   \
           --exclude="/noupdate"     --exclude="/tmp"                    \
           --exclude="/batcharch"    --exclude="bzvol.dat"               \
           --exclude="oldzidoc.html" --exclude="techs/lgstr/tomo/data"   \
           --exclude="techs/lgstr/tomo/output"                           \
           $docdir/* $docdest

# ----------------------------------------------------------------

echo ' '
echo "GREAT: SPIDER copied successfully to: distribution dir"
echo ' '
echo "Update FFTW files with: send-fftw.sh "
echo "Update executables with make in src dir."
echo "Update executables from OSX spider" 
echo "Update Web  with:       /usr8/web/tosend/tosend.sh "
echo "touch /usr8/send/spider/bin/CONTAINS_SPIDER_RELEASE_22.00"
echo "Archive and compress the distribution in: /usr8/send "  
echo "set wwwdir = spider-stage:/export/apache/vhosts/spider.wadsworth.org/htdocs/spider_doc/spider "   
echo "scp -p /usr8/send/spiderweb.22.00.tar.gz  $wwwdir/download"
echo "Edit: /usr8/spider/docs/spi-download.html"
echo "scp -p /usr8/spider/docs/spi-download.html  $wwwdir/docs"
echo "Update external web pages using: /usr8/spider/utils/wwwupdate.sh"

echo ' '
exit 0