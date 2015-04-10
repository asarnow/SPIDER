
C++*********************************************************************
C
C APMASTER_TOOL.F   FROM APMASTER                  OCT 2010 ARDEAN LEITH
C                   APSH_TOOL                      FEB 2011 ARDEAN LEITH
C                   APRINGS_INIT_PLANS PARAMS      JUN 2011 ARDEAN LEITH
C
C **********************************************************************
C=* This file is part of:   SPIDER - Modular Image Processing System.  *
C=* Authors: J. Frank & A. Leith                                       *
C=* Copyright 1985-2011  Health Research Inc.,                         *
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
C=* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU  *
C=* General Public License for more details.                           *
C=* You should have received a copy of the GNU General Public License  *
C=* along with this program. If not, see <http://www.gnu.org/licenses> *
C=*                                                                    *
C **********************************************************************
C
C    APMASTER_TOOL(MODE,CTYPE)                                  
C
C    PURPOSE: 'AP TOOL'  -- SAMPLE PARAMETER INFLUENCE ON ALIGNMENT
C
C23456789 123456789 123456789 123456789 123456789 123456789 123456789 12
C--*********************************************************************

        SUBROUTINE APMASTER_TOOL(MODE,CTYPE)

        INCLUDE 'CMLIMIT.INC'
        INCLUDE 'CMBLOCK.INC'

        INTEGER, ALLOCATABLE   :: IMGLST(:)
        INTEGER, ALLOCATABLE   :: NUMR(:,:)
        REAL,    ALLOCATABLE   :: CIRCREF(:,:)

        CHARACTER (LEN=MAXNAM) :: FILNAM,REFANGDOC,REFPAT,EXPPAT,OUTANG

	CHARACTER(LEN=*)       :: CTYPE
	CHARACTER(LEN=1)       :: MODE,NULL,ANS,YN
	CHARACTER(LEN=1)       :: SHORRING
	CHARACTER(LEN=210)     :: COMMEN
        LOGICAL                :: CKMIRROR,WINDOW,NEWFILE,WEIGHT
        REAL                   :: VALUES(4)

        INTEGER, PARAMETER     :: NPLANS = 14
#ifndef SP_32
        INTEGER *8             :: IASK8,IOK
        INTEGER *8             :: FFTW_PLANS(NPLANS)
#else
        INTEGER *4             :: IASK8,IOK
        INTEGER *4             :: FFTW_PLANS(NPLANS)
#endif

	DATA  LUNREF,LUNEXP,LUNRING/50,51,52/
	DATA  INPIC,INANG,NDOC,NSCF/77,78,55,50/ !USED IN CALLED ROUTINE

#ifndef SP_LIBFFTW3
        CALL ERRT(101,'ONLY WORKS WITH FFTW3',NDUM)
        RETURN
#endif

        CALL SET_MPI(ICOMM,MYPID,MPIERR) ! SETS ICOMM AND MYPID 
        NULL   = CHAR(0)

        CALL RDPRMC(SHORRING,NLET,.TRUE.,
     &             'EVALUATE SHIFT OR RINGS (SH/RI)',NULL,IRTFLG)
        IF (IRTFLG .NE. 0) RETURN

        NILMAX = NIMAX
C       ASK FOR TEMPLATE AND NUMBERS FOR REFERENCE IMAGES
        CALL FILELIST(.TRUE.,LUNREF,REFPAT,NLET,INUMBR,NILMAX,NUMREF,
     &           'TEMPLATE FOR REFERENCE IMAGES',IRTFLG)
        IF (IRTFLG .NE. 0) RETURN

        IF (MYPID .LE. 0) WRITE(NOUT,2001) NUMREF
2001    FORMAT('  Number of reference images: ',I7)

C       NUMREF - TOTAL NUMBER OF REF. IMAGES
        IF (NUMREF .LE. 0)  THEN
           CALL ERRT(101,'No reference images',IDUM)
           GOTO 9999
        ENDIF

C       GET FIRST REFERENCE IMAGE TO DETERMINE DIMENSIONS
        NLET = 0
        CALL FILGET(REFPAT,FILNAM,NLET,INUMBR(1),INTFLG)

        MAXIM = 0
        CALL OPFILEC(0,.FALSE.,FILNAM,LUNREF,'O',IFORM,NSAM,NROW,NSLICE,
     &               MAXIM,' ',.FALSE.,IRTFLG)
        IF (IRTFLG .NE. 0)  GOTO 9999
        CLOSE(LUNREF)

        ISHRANGEX =  5
        IF (SHORRING .EQ. 'S') THEN
           CALL RDPRI1S(ISHRANGEX,NOT_USED,
     &               'MAX TRANSLATION SEARCH RANGE',IRTFLG)
           IF (IRTFLG .NE. 0)  GOTO 9999
           ISHRANGEX = MAX(ISHRANGEX,1)       
           ISHRANGEY = ISHRANGEX  

        ELSEIF (SHORRING .EQ. 'R') THEN
           CALL RDPRI1S(ISHRANGEX,NOT_USED,
     &                  'TRANSLATION SEARCH RANGE',IRTFLG)
           IF (IRTFLG .NE. 0)  GOTO 9999
           ISHRANGEX = MAX(ISHRANGEX,1)       
           ISHRANGEY = ISHRANGEX
        ENDIF

C       VERIFY SEARCH RANGE
	IF (ISHRANGEX .GT. NSAM/2-2)  THEN
	   CALL ERRT(102,'X SEARCH MUST BE LESS THAN',NSAM/2-2)
           GOTO 9999
	ELSEIF (ISHRANGEY .GT. NSAM/2-2)  THEN
	   CALL ERRT(102,'Y SEARCH MUST BE LESS THAN',NSAM/2-2)
           GOTO 9999
        ENDIF

        IRAY = 1
        MR   = 5
        NR   = MIN(NSAM/2-1, NROW/2-1)

        IF (SHORRING .EQ. 'S') THEN
C          EVALUATING SHIFT 
           VALUES(1) = MR
           VALUES(2) = NR
           VALUES(3) = ISKIP
           VALUES(4) = IRAY

           CALL RDPRA('FIRST, LAST RING, RING STEP & RAY STEP',
     &                 4,0,.TRUE.,VALUES,NGOT,IRTFLG)
           IF (IRTFLG .NE. 0) RETURN

           IF (NGOT .GT. 0) THEN
C             COPY THE RETURNED VALUES 
              IF (NGOT .GE. 1) MR    = VALUES(1)
              IF (NGOT .GE. 2) NR    = VALUES(2)
              IF (NGOT .GE. 3) ISKIP = VALUES(3)
              IF (NGOT .GE. 4) IRAY  = VALUES(4)
              ISKIP = MAX(1,ISKIP)
              IF (IRAY .NE. 1 .AND. IRAY .NE. 2 .AND. 
     &            IRAY .NE. 4 .AND. IRAY .NE. 8) THEN
	         CALL ERRT(101,'RAY STEP MUST BE 1,2,4, OR 8',NE)
                 GOTO 9999
              ENDIF
           ENDIF
           ISTEP = 1
        ELSE
C          EVALUATING RINGS 
           CALL RDPRIS(MR,NR,NOT_USED,'FIRST, LAST RING',IRTFLG)
           IF (IRTFLG .NE. 0) RETURN
           ISKIP = 1
           ISTEP = 1
        ENDIF 

        NRAD = MIN(NSAM/2-1, NROW/2-1)

	IF (MR .LE. 0) THEN
	   CALL ERRT(101,'FIRST RING MUST BE > 0',NE)
	   GOTO 9999
	ELSEIF (NR .LT. MR)  THEN 
	   CALL ERRT(102,'LAST RING MUST BE > ',MR)
	   GOTO 9999
	ELSEIF (NR .GE. NRAD)  THEN 
	   CALL ERRT(102,'LAST RING MUST BE < ',NRAD)
	   GOTO 9999
	ENDIF

C       CHECK SEARCH RANGE AND STEP SIZE TOGETHER
	IF ((ISHRANGEX+NR) .GT. (NRAD-1))  THEN
	   CALL ERRT(102,'LAST RING + X TRANSLATION MUST BE <',NRAD)
           GOTO 9999
	ELSEIF ((ISHRANGEY+NR) .GT. (NRAD-1))  THEN
	   CALL ERRT(102,'LAST RING + Y TRANSLATION MUST BE <',NRAD)
           GOTO 9999
        ENDIF

        REFANGDOC = NULL
C       GET NAME OF REFERENCE IMAGES ANGLES DOCUMENT FILE
        CALL FILERD(REFANGDOC,NREFA,NULL,
     &		'REFERENCE IMAGES ANGLES DOCUMENT',IRTFLG)
C       FILERD WILL RETURN IRTFLG=1 IF "*" !!!!
        IF (REFANGDOC(:1) .EQ. '*' .OR. NREFA.LE.0)REFANGDOC = NULL

C       FIND NUMBER OF REFERENCE-RINGS
        NRING=0
        DO I=MR,NR,ISKIP
           NRING = NRING + 1
        ENDDO

        ALLOCATE(NUMR(3,NRING),STAT=IRTFLG)
        IF (IRTFLG .NE. 0) THEN
            CALL ERRT(46,'NUMR',3*NRING)
            GOTO 9999
        ENDIF

C       INITIALIZE NUMR ARRAY WITH RING RADII
        NRING = 0
        DO I=MR,NR,ISKIP
           NRING         = NRING+1
           NUMR(1,NRING) = I
        ENDDO
 
C       CALCULATES NUMR & LCIRC, EACH RING HAS FFT PAD OF 2 FLOATS
        CALL ALPRBS_Q_NEW(NUMR,NRING,LCIRC,MODE,IRAY)

        IASK8 = (LCIRC * NUMREF)*4
        CALL BIGALLOC(IASK8,IOK,.FALSE.,.FALSE.,IRTFLG)

        NTOT = LCIRC * NUMREF 
        ALLOCATE(CIRCREF(LCIRC,NUMREF),IMGLST(NILMAX),STAT=IRTFLG)
        IF (IRTFLG .NE. 0) THEN 
           CALL  ERRT(46,'CIRCREF & IMGLST',NTOT+NILMAX)
           GOTO 9999
        ENDIF
        IF (MYPID .LE. 0) WRITE(NOUT,91) LCIRC,NUMREF,NTOT
91      FORMAT('  ALLOCATED: CIRCREF(',I8,' X ',I8,'): ',I10) 
 
C       GET LIST OF EXPERIMENTAL IMAGES TO BE ALIGNED
        CALL FILELIST(.TRUE.,LUNEXP,EXPPAT,NLEP,
     &         IMGLST,NILMAX,NUMEXP,
     &        'TEMPLATE FOR IMAGE SERIES TO BE ALIGNED',IRTFLG)
        IF (IRTFLG .NE. 0) GOTO 9999

        IF (MYPID .LE. 0) WRITE(NOUT,2002) NUMEXP
2002    FORMAT('  Number of experimental images: ',I6)

        CALL RDPRI1S(IMIRROR,NOT_USED,
     &         'CHECK MIRRORED POSITIONS (0=NOCHECK / 1=CHECK)?',IRTFLG)
        IF (IRTFLG .NE. 0) GOTO 9999
        CKMIRROR = (IMIRROR .NE. 0)

C       OPEN OUTPUT DOC FILE (FOR APPENDING)
        NOUTANG = NDOC
        CALL OPENDOC(OUTANG,.TRUE.,NLET,NDOC,NOUTANG,.TRUE.,
     &           'OUTPUT ALIGNMENT DOCUMENT',.FALSE.,.TRUE.,.TRUE.,
     &            NEWFILE,IRTFLG)

        COMMEN ='                 ' //
     &         'PSI,        THE,         PHI,         REF#,     '//
     &         '  EXP#,     CUM. {INPLANE,    SX,         SY},  '//
     &         '      NPROJ,        DIFF,       CCROT,   '//
     &         '   INPLANE,        SX,         SY,         MIR-CC'
        CALL LUNDOCPUTCOM(NOUTANG,COMMEN,IRTFLG)

C       INITIALIZE FFTW3 PLANS FOR USE WITHIN OMP || SECTIONS
        CALL APRINGS_INIT_PLANS(NUMR,NRING,
     &                          FFTW_PLANS,NPLANS,NSAM,NROW,IRTFLG)

        IF (MYPID .LE. 0 .AND. SHORRING .EQ. 'S') 
     &     WRITE(6,*) 'Calling: APSH_TOOL  For Shifts ----------'
        IF (MYPID .LE. 0 .AND. SHORRING .EQ. 'R') 
     &     WRITE(6,*) 'Calling: APSH_TOOL  For Rings ----------'
        IF (MYPID .LE. 0 .AND. SHORRING .EQ. 'S') 
     &     WRITE(NOUT,*) 'Calling: APSH_TOOL  For Shifts ----------'
        IF (MYPID .LE. 0 .AND. SHORRING .EQ. 'R') 
     &     WRITE(NOUT,*) 'Calling: APSH_TOOL  For Rings ----------'

        ANGRES = 360.0 / (FLOAT(NUMR(3,NRING)) -2)
        WRITE(NOUT,987) ANGRES,NUMR(3,NRING)-2
        WRITE(6,987) ANGRES,NUMR(3,NRING)-2
987     FORMAT(/' Angular resolution:',F6.2,
     &          ' Degrees,   Circumference:',I5)
        ! write(6,"a") "  skip,  ref,  irot,  sx,  sy"

        CALL APSH_TOOL(INUMBR,NUMREF,IMGLST,NUMEXP, 
     &               NSAM,NROW,ISHRANGEX,ISHRANGEY,ISTEP,
     &               NRING,LCIRC,NUMR,CIRCREF,
     &               REFANGDOC,FFTW_PLANS,
     &               REFPAT,EXPPAT,CKMIRROR,NOUTANG,SHORRING)
        WRITE(6,*) ' '

C       UNALLOCATE FFTW3 PLANS (TO REMOVE MEMORY LEAK)
9989    CALL FFTW3_KILLPLANS(FFTW_PLANS,NPLANS,IRTFLG)

9999    IF (ALLOCATED(IMGLST))  DEALLOCATE(IMGLST)
        IF (ALLOCATED(NUMR))    DEALLOCATE(NUMR)
        IF (ALLOCATED(CIRCREF)) DEALLOCATE(CIRCREF)
        CLOSE(NDOC)

        !ANGIN = 1
        !ANGOUT = ANG_N(ANGIN,'F',512)
        !WRITE(6,*) 'ANG: ',ANGIN,' = ',ANGOUT
        !ANGIN = 2
        !ANGOUT = ANG_N(ANGIN,'F',512)
        !WRITE(6,*) 'ANG: ',ANGIN,' = ',ANGOUT
        !ANGIN = 512
        !ANGOUT = ANG_N(ANGIN,'F',512)
        !WRITE(6,*) 'ANG: ',ANGIN,' = ',ANGOUT

        END

