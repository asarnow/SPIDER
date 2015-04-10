
C++*********************************************************************
C
C HIST.F                   FMINT FOR HIST RANGE  JUN  2000  ArDean Leith
C                          NaN OK                JAN  2001  ArDean Leith
C                          OLD MODE BUG          JAN  2002  ArDean Leith
C                          FNUMEL OVERFLOW BUG   JUL  2002  ArDean Leith
C                          INTEGER OUTPUT        OCT  2002  ArDean Leith
C
C **********************************************************************
C=*                                                                    *
C=* This file is part of:   SPIDER - Modular Image Processing System.  *
C=* SPIDER System Authors:  Joachim Frank & ArDean Leith               *
C=* Copyright 1985-2010  Health Research Inc.,                         *
C=* Riverview Center, 150 Broadway, Suite 560, Menands, NY 12204.      *
C=* Email: spider@wadsworth.org                                        *
C=*                                                                    *
C=* SPIDER is free software; you can redistribute it and/or            *
C=* modify it under the terms of the GNU General Public License as     *
C=* published by the Free Software Foundation; either version 2 of the *
C=* License, or (at your option) any later version.                    *
C=*                                                                    *
C=* SPIDER is distributed in the hope that it will be useful,          *
C=* but WITHOUT ANY WARRANTY; without even the implied warranty of     *
C=* merchantability or fitness for a particular purpose.  See the GNU  *
C=* General Public License for more details.                           *
C=* You should have received a copy of the GNU General Public License  *
C=* along with this program. If not, see <http://www.gnu.org/licenses> *
C=*                                                                    *
C **********************************************************************
C
C    HIST(LUN,LUNMA,LUNDOC,NX,NY,NZ,IDUST,HMIN,HMAX)
C
C    PURPOSE:    COMPUTE 128 PLACE HISTOGRAM FROM IMAGE RECORDS, 
C                DISPLAY HISTOGRAM ON LINE PRINTER, TERMINAL, OR
C                IN DOC. FILE AND, OPTIONALLY, REMOVE DATA THAT ARE 
C                OUT OF A SPECIFIED STATISTICAL RANGE.
C
C    PARAMETERS:  LUN        IO UNIT NUMBER OF IMAGE FILE
C                 LUNMA      IO UNIT NUMBER FOR MASK FILE
C                 LUNDOC     IO UNIT NUMBER FOR DOCUMENT FILE
C                 NX,NY,NZ   DIMENSIONS OF IMAGE
C                 HMIN,HMAX  HIST. MIN & MAX                    (RET.)
C                 HSIG,HMODE HIST. S.D. & MODE (USED BY DUST)
C
C23456789 123456789 123456789 123456789 123456789 123456789 123456789 12
C--*********************************************************************

      SUBROUTINE HISTOG()

      IMPLICIT NONE
      INCLUDE 'CMLIMIT.INC'
      INCLUDE 'CMBLOCK.INC'

      LOGICAL                :: ASKNAM,MASK,FOUROK,ADDEXT
      LOGICAL                :: ISOLD,APPEND,MESSAGE,NEWFILE,USEMASK
      LOGICAL                :: USERANGE

      CHARACTER *1           :: ANS
      CHARACTER *1           :: NULL = CHAR(0)
      CHARACTER (LEN=MAXNAM) :: DOCNAM,FILNAM
      CHARACTER (LEN=50)     :: COMMENT
                       
      REAL                   :: HMIN,HMAX,HSIG,HMODE
      INTEGER                :: LUN,LUNDOC,LUNMA,LUNRET
      INTEGER                :: MAXIM,MAXIM2,NLET,ITYPE,NX,NY,NZ,IRTFLG
      INTEGER                :: NXM,NYM,NZM,ITYPEM
      INTEGER                :: NOT_USED,NBINS,NDEV,IDEV,LUNDRET

      LUN      = 21
      LUNMA    = 22
      LUNDOC   = 80

      USERANGE = (FCHAR(4:4) == 'R')

      ASKNAM   = .TRUE.
      ADDEXT   = .TRUE.
      ISOLD    = .FALSE.
      APPEND   = .FALSE. 
      MESSAGE  = .TRUE. 

      MAXIM    = 0
      FOUROK   = .FALSE.
          
C     OPEN INPUT FILE, FOURIER NOT ALLOWED 
      CALL OPFILEC(0,ASKNAM,FILNAM,LUN,'O',ITYPE,
     &             NX,NY,NZ,
     &             MAXIM,'INPUT',FOUROK,IRTFLG)
        IF (IRTFLG .NE. 0) RETURN

C     MAKE SURE STATISTICS ARE CURRENT
      IF (IMAMI .NE. 1) CALL NORM3(LUN,NX,NY,NZ,FMAX,FMIN,AV)
      HMAX = FMAX
      HMIN = FMIN

C     GET MASK NAME 
      CALL OPFILEC(0,ASKNAM,FILNAM,LUNMA,'O',ITYPEM,
     &             NXM,NYM,NZM,MAXIM2,
     &            'MASK FILE (* IF NONE)~',FOUROK,IRTFLG)

      IF (IRTFLG == -1) THEN
C        NO MASK WANTED
         USEMASK = .FALSE.
      ELSEIF (IRTFLG .NE. 0) THEN
C        ERROR
         GOTO 9000
      ELSE
         USEMASK = .TRUE.

C        IMAGES NUST HAVE SAME DIMENSIONS
         CALL SIZCHK(NOT_USED,NX, NY, NZ,ITYPE,
     &                   NXM,NYM,NZM, ITYPEM,IRTFLG) 
         IF (IRTFLG .NE. 0) GOTO 9000 

      ENDIF

C     ASK USER FOR HISTOGRAM SINK
      CALL RDPRMC(ANS,NLET,.TRUE.,
     &      'OUTPUT TO RESULTS FILE, DOC. FILE, OR TERMINAL? (R/D/T)',
     &       NULL,IRTFLG)

      NDEV = 6
      IF  (ANS == 'T') THEN
C        OUTPUT TO TERMINAL, NOT RESULTS FILE
         NBINS   = 70
         NDEV    = 6   ! 6 IS TERMINAL, NDAT IS RESULTS FILE OUTPUT
         IDEV    = 0   ! 0 IS TERMINAL, 1 IS LINE PRINTER OUTPUT
         LUNDRET = 0   ! NO DOC FILE


      ELSEIF  (ANS == 'R') THEN
C        OUTPUT TO RESULTS FILE
         NBINS   = 128
         NDEV    = NDAT ! 6 IS TERMINAL, NDAT IS RESULTS FILE OUTPUT
         IDEV    = 1    ! 0 IS TERMINAL, 1 IS LINE PRINTER OUTPUT
         LUNDRET = 0    ! NO DOC FILE

      ELSEIF  (ANS == 'D') THEN
        NBINS   = 128

        CALL OPENDOC(DOCNAM,ADDEXT,NLET,LUNDOC,LUNDRET,ASKNAM,
     &           'OUTPUT DOC FILE',ISOLD,APPEND,MESSAGE,
     &            NEWFILE,IRTFLG)
         IF (IRTFLG .NE. 0) GOTO 9000

C                   123456789 123456789 123456789 123456789 123456789 
         COMMENT = ' BIN      BOUNDARY  OCCUPANCY'

         CALL LUNDOCPUTCOM(LUNDOC,COMMENT,IRTFLG)
      ENDIF

      CALL  RDPRI1S(NBINS,NOT_USED,'NUMBER OF HISTOGRAM BINS',IRTFLG)
      IF (IRTFLG .NE. 0) GOTO 9000

      IF (USERANGE) THEN
         CALL RDPRM2S(HMIN,HMAX,NOT_USED,
     &                'HISTOGRAM RANGE (MIN ... MAX)',IRTFLG)
         IF (IRTFLG .NE. 0) GOTO 9000
      ENDIF


      CALL HISTOG1(LUN,LUNMA,LUNDRET, NX,NY,NZ, 
     &             NBINS,USEMASK,NDEV,IDEV, 
     &             HMIN,HMAX,HSIG,HMODE)
  

9000  CLOSE(LUN)
      CLOSE(LUNMA)
      CLOSE(LUNDOC)

      END


C     ------------------------ HISTOG1  -----------------------

      SUBROUTINE HISTOG1(LUN,LUNMA,LUNDOC, NX,NY,NZ, 
     &                   NBINS,USEMASK,NDEV,IDEV,
     &                   HMIN,HMAX,HSIG,HMODE)

      INCLUDE 'CMBLOCK.INC'

      INTEGER          :: LUN,LUNMA,LUNDOC, NX,NY,NZ, NBINS
      LOGICAL          :: USEMASK
      INTEGER          :: NDEV,IDEV
      REAL             :: HMIN,HMAX,HSIG,HMODE

      REAL             :: FREQ(NBINS)
      REAL             :: PLIST(2)
      DOUBLE PRECISION :: HAV, HAV2, DTOP, FNUMEL
      CHARACTER *1     :: NULL = CHAR(0)

      INTEGER          :: NREC

C     ZERO THE HISTOGRAM FREQUENCIES
      FREQ = 0.0 

      NREC = NZ * NY
      IF (USEMASK) THEN
C        HISTOGRAM UNDER MASK ONLY, DETERMINE RANGE UNDER MASK
         CALL HISTMINMAX1(LUN,LUNMA,NX,NREC,HMIN,HMAX)
      ENDIF

      HDIFF  = HMAX - HMIN
      FF     = (NBINS - 1.0) / HDIFF
      BSIZ   = 1.0 / FF
      FNUMEL = 0.0
      HAV    = 0.0
      HAV2   = 0.0

      CALL HISTIMAGE1(LUN,LUNMA,NX,NREC,FREQ,
     &               FNUMEL,HAV,HAV2,HMIN,FF,NBINS,USEMASK)

      IF (LUNDOC > 0) THEN
C        OUTPUT TO DOC FILE
         PLIST(2) = HMIN

         DO IBIN =1,NBINS
            PLIST(1) = HMIN + (BSIZ *(IBIN - 1))
            PLIST(2) = FREQ(IBIN)

            CALL LUNDOCWRTDAT(LUNDOC,IBIN,PLIST,2,IRTFLG)
         ENDDO

      ELSE
C        OUTPUT TO RESULTS FILE OR TERMINAL 

C        GRAPHX IN GRAPHS USES FMIN & FMAX FOR HISTOGRAM LABELS
         FMINT = FMIN
         FMIN  = HMIN
         FMAXT = FMAX
         FMAX  = HMAX

         CALL GRAPHS(NDEV,FREQ,NBINS,1,IDEV,1.0,IRTFLG)
         FMIN = FMINT
         FMAX = FMAXT

         WRITE(NDEV,*) ' '
         IF (IRTFLG .NE. 0) THEN
            CALL ERRT(100,'HIST',NE)
            RETURN
         ENDIF
      ENDIF

C     FIND MAXIMUM FREQUENCY OCCURING IN HISTOGRAM (HISMAX) & LOCATION
      HISMAX = FREQ(1)
      MAXBIN = 1
      DO  IBIN = 2,NBINS
         IF (FREQ(IBIN) >= HISMAX) THEN
            HISMAX = FREQ(IBIN)
            MAXBIN = IBIN
         ENDIF
      ENDDO

C     CONVERT LOCATION MAXBIN TO CORRESPONDING IMAGE INTENSITY (MODE)
      IF (MAXBIN == 1) THEN
C        SUB-BIN ESTIMATE OF MODE
         BMODE  = 0.5

      ELSEIF (MAXBIN == NBINS) THEN
C        SUB-BIN ESTIMATE OF MODE 
C        (MAYBE THIS SHOULD AVERAGE ALL BINS AT END WITH SAME NUMBER?)
         BMODE  = FLOAT(NBINS) - 0.5
      ELSE
C        SUB-BIN ESTIMATE OF MODE
         YM1    = FREQ(MAXBIN-1)
         YP1    = FREQ(MAXBIN+1)
         BMODE  = FLOAT(MAXBIN-1) + (YM1-YP1)*0.5/ (YM1+YP1-2.*HISMAX)
      ENDIF
      HMODE = HMIN + BMODE * BSIZ

      DTOP  = HAV2 - HAV * HAV / FNUMEL
      IF (DTOP < 0.0) THEN
C        SQRT OF NEGATIVE NUMBER
         WRITE(NOUT,*) '*** in HIST, SQRT(',DTOP,') IMPOSSIBLE' 
         CALL ERRT(100,'HIST',NE)
         RETURN

      ELSEIF (FNUMEL == 1) THEN
         WRITE(NOUT,*) '*** CAN NOT DETERMINE S.D. (ONLY ONE PIXEL) ' 
         CALL ERRT(100,'HIST',NE)
         RETURN
      ENDIF

      HAV    = HAV  / FNUMEL
      HSIG   = DSQRT(DTOP / (FNUMEL - 1))
      FNPIX  = NX * NY * NZ
      FNBINS = NBINS

      WRITE(NDEV,*) ' '

      IBIG = HUGE(IBIG)
      IF (FNPIX < IBIG) THEN
         NPIX  = NX * NY * NZ
         NUMEL = FNUMEL
         WRITE(NDEV,90) FMIN,FMAX,HMIN,HMAX,NPIX,NUMEL,
     &               NBINS,BSIZ,HAV,HMODE,HSIG

90       FORMAT(
     &    '  FILE RANGE:        ',1PG11.4,'   .........     ',1PG11.4,/,
     &    '  HISTOGRAM RANGE:   ',1PG11.4,'   .........     ',1PG11.4,/,
     &    '  TOTAL PIXELS:      ',I11,    '   PIXELS IN HIST.: ',I11,/,
     &    '  NO. OF BINS:       ',I11,    '   BIN SIZE:     ',1PG11.4,/,
     &    '  HIST. MEAN:        ',1PG11.4,'   HIST. MODE:   ',1PG11.4,/,
     &    '  HIST. S.D.:        ',1PG11.4/)
      ELSE
        WRITE(NDEV,91) FMIN,FMAX,HMIN,HMAX,FNPIX,FNUMEL,
     &               FNBINS,BSIZ,HAV,HMODE,HSIG

91      FORMAT(
     &  '  FILE RANGE:        ',1PG11.4,'   .........     ',1PG11.4,/,
     &  '  HISTOGRAM RANGE:   ',1PG11.4,'   .........     ',1PG11.4,/,
     &  '  TOTAL PIXELS:      ',1PG11.4,'   PIXELS IN HIST.: ',1PG11.4,/,
     &  '  NO. OF BINS:       ',1PG11.4,'   BIN SIZE:     ',1PG11.4,/,
     &  '  HIST. MEAN:        ',1PG11.4,'   HIST. MODE:   ',1PG11.4,/,
     &  '  HIST. S.D.:        ',1PG11.4/)
      ENDIF

      WRITE(NDEV,*) ' '

      IF (NDEV .NE. NOUT) THEN
         WRITE(NOUT,*) ' '
         IF (FNPIX < IBIG) THEN
            WRITE(NOUT,90) FMIN,FMAX,HMIN,HMAX,NPIX,
     &                     NUMEL,NBINS,BSIZ,HAV,HMODE,HSIG
         ELSE
            WRITE(NOUT,91) FMIN,FMAX,HMIN,HMAX,NPIX,
     &                     FNUMEL,FNBINS,BSIZ,HAV,HMODE,HSIG
         ENDIF
         WRITE(NOUT,*) ' '
      ENDIF

      END

C     -------------------- HISTIMAGE1 --------------------------------

      SUBROUTINE HISTIMAGE1(LUN,LUNMA,NX,NREC,FREQ,
     &                     FNUMEL,HAV,HAV2,HMIN,FF,NBINS,MASK)

      IMPLICIT NONE
      INCLUDE 'CMBLOCK.INC'


      INTEGER          :: LUN,LUNMA,NX,NREC
      REAL             :: FREQ(NBINS)
      DOUBLE PRECISION :: FNUMEL,HAV, HAV2
      REAL             :: HMIN,FF
      INTEGER          :: NBINS
      LOGICAL          :: MASK

      REAL             :: BUFMASK(NX), REDBUF(NX)
      INTEGER          :: IRECT,ISAM,JBIN
      REAL             :: BVAL

C     GET HISTOGRAM FROM IMAGE VALUES

      IF (MASK) THEN
C        MASKED, HANDLES NaN for NOT MASK OK
         DO  IRECT=1,NREC
            CALL REDLIN(LUN,REDBUF,NX,IRECT)
            CALL REDLIN(LUNMA,BUFMASK,NX,IRECT)
            DO  ISAM = 1,NX
               IF (BUFMASK(ISAM) >= 0.5) THEN
C                 HISTOGRAM THIS PIXEL, MASK HAS POSITIVE VALUE)

C                 FIND BIN NUMBER
                  BVAL = REDBUF(ISAM)
                  JBIN = INT((BVAL - HMIN) * FF) + 1.5

                  IF (JBIN >= 1 .AND. JBIN <= NBINS) THEN
C                    WITHIN HISTOGRAM RANGE
                     FREQ(JBIN) = FREQ(JBIN) + 1.0
                     FNUMEL     = FNUMEL + 1
                     HAV        = HAV  + BVAL 
                     HAV2       = HAV2 + DBLE(BVAL) * DBLE(BVAL)
                  ENDIF
              ENDIF
           ENDDO
         ENDDO
      ELSE
C        NO MASK
         DO  IRECT=1,NREC
            CALL REDLIN(LUN,REDBUF,NX,IRECT)

            DO  ISAM = 1,NX
C              HISTOGRAM THIS PIXEL 

C              FIND BIN NUMBER
               BVAL = REDBUF(ISAM)
               JBIN = INT((BVAL - HMIN) * FF) + 1.5

               IF (JBIN >=1 .AND. JBIN <= NBINS) THEN
C                 WITHIN HISTOGRAM RANGE
                  FREQ(JBIN) = FREQ(JBIN) + 1.0
                  FNUMEL     = FNUMEL + 1
                  HAV        = HAV  + BVAL 
                  HAV2       = HAV2 + DBLE(BVAL) * DBLE(BVAL)
               ENDIF
           ENDDO
         ENDDO
      ENDIF

      END

C     -------------------- HISTMINMAX --------------------------------

      SUBROUTINE HISTMINMAX1(LUN,LUNMA,NX,NREC,
     &                      HMIN,HMAX)

      IMPLICIT NONE
      INCLUDE 'CMBLOCK.INC'

      INTEGER :: LUN,LUNMA,NX,NREC
      REAL    :: HMIN,HMAX

      REAL    :: BUFMASK(NX), REDBUF(NX)
      INTEGER :: IRECT,ISAM
      REAL    :: BVAL


C     DETERMINE PIXLE VALUE RANGE UNDER MASK
      DO IRECT=1, NREC
         CALL REDLIN(LUN,  REDBUF,NX,IRECT)
         CALL REDLIN(LUNMA,BUFMASK,NX,IRECT)

         DO  ISAM = 1,NX
            IF (BUFMASK(ISAM) >= 0.5) THEN
C              PIXEL HAS POSITIVE MASK VALUE
               BVAL = REDBUF(ISAM)
               IF (BVAL < HMIN) HMIN = BVAL
               IF (BVAL > HMAX) HMAX = BVAL
            ENDIF
         ENDDO
      ENDDO

      END

