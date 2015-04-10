
C++*********************************************************************
C
C COPYTOVOL.F  LONG FILENAMES                      JAN 89 ARDEAN LEITH
C              REWRITE FROM: STACK                 MAY 13 ARDEAN LEITH
C
C **********************************************************************
C=*                                                                    *
C=* This file is part of:   SPIDER - Modular Image Processing System.  *
C=* SPIDER System Authors:  Joachim Frank & ArDean Leith               *
C=* Copyright 1985-2014  Health Research Inc.,                         *
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
C    COPYTOVOL()
C
C    PURPOSE:   STACK 2-D SLICES INTO 3-D IMAGE
C               CAN OPERATE ON IMAGE SERIES
C               CAN USE A SELECTION DOC FILE FOR IMAGE NUMBERS
C
C    PARAMETERS:  REPLACE    FLAG FOR EXISTING VOLUME REPLACEMENT
C
C--*******************************************************************

      SUBROUTINE COPYTOVOL()

      IMPLICIT NONE
      INCLUDE 'CMBLOCK.INC'
      INCLUDE 'CMLIMIT.INC'

      LOGICAL                :: REPLACE

      REAL,    ALLOCATABLE   :: BUFIMG(:)
      INTEGER, ALLOCATABLE   :: ILIST(:),ISLICES(:)
      LOGICAL, ALLOCATABLE   :: LDONE(:)

      CHARACTER (LEN=MAXNAM) :: FILPATIN,FILOUT,FILNAM,FILPAT1,FILNM2
      CHARACTER (LEN=MAXNAM) :: FILOUTPE

      CHARACTER (LEN=1)      :: NULL = CHAR(0)

      INTEGER                :: NILMAX,ITYPE,NX,NY,NZ
      INTEGER                :: IX,IY,IZ,NSL,NPIX,NLETF
      INTEGER                :: NLET,NDUM,NLETV
      INTEGER                :: NIMG,IMGNUM,NUM1,NLET2,NUM2,IVAL,INUM
      INTEGER                :: NINDX,MAXIMIN,MAXIM,IRTFLG
      INTEGER                :: NLETO,LUNOP,NFILLED
      LOGICAL                :: ISOPEN,INLNED,EX

      INTEGER,PARAMETER      :: LUNCP     = 0 
      INTEGER,PARAMETER      :: LUNIN     = 21 
      INTEGER,PARAMETER      :: LUNOUT    = 23
      INTEGER,PARAMETER      :: LUNDOCSEL = 81
      INTEGER,PARAMETER      :: LUNXM1    = 82

      INTEGER                :: lnblnkn
 
      NILMAX  = NIMAXPLUS      ! FROM CMLIMIT
      ALLOCATE(ILIST(NILMAX),
     &         ISLICES(NILMAX),
     &         LDONE(NILMAX),
     &         STAT=IRTFLG)
      IF (IRTFLG .NE. 0) THEN
          CALL ERRT(46,'STACK; ILIST....',3*NILMAX)
          RETURN
      ENDIF

C     OPEN FIRST INPUT IMAGE  (NOT FOURIER)
      CALL OPFILES(0,LUNIN,LUNDOCSEL,LUNXM1, 
     &             .TRUE.,FILPATIN,NLET, 'O',
     &             ITYPE,NX,NY,NZ,MAXIMIN,
     &             NULL,
     &             .FALSE.,ILIST,NILMAX, 
     &             NDUM,NIMG, IMGNUM, IRTFLG) 
      IF (IRTFLG .NE. 0)  GOTO 9999

      IF (NZ > 1) THEN
          CALL ERRT(102,'OPERATION DOES NOT ACCEPT VOLUMES',NZ)
          RETURN
      ENDIF
      !write(6,*) ' Input images:',nimg

C     ALLOCATE IMAGE BUFFER
      NPIX    = NX * NY
      ALLOCATE(BUFIMG(NPIX),STAT=IRTFLG)
      IF (IRTFLG .NE. 0) THEN 
         CALL ERRT(46,'STACK, BUFIMG',NPIX)
         GOTO 9999
      ENDIF

C     SEE IF OUTPUT VOL EXISTS
      CALL FILERD(FILOUT,NLETO,NULL,'OUTPUT VOLUME',IRTFLG)
      IF (IRTFLG .NE. 0) GOTO 9999

      FILOUTPE = FILOUT(1:NLETO) // '.' // DATEXC(1:3)

      CALL INQUIREIF1(LUNOUT,FILOUTPE,NULL,EX,ISOPEN,LUNOP,
     &                   INLNED,IMGNUM,IRTFLG)
      IF (IRTFLG .NE. 0) GOTO 9999

      ITYPE  = 3

      IF (EX) THEN
C        OUTPUT VOLUME EXISTS ALREADY, OPEN OUTPUT VOLUME TO 
C        REPLACE SLICES
         MAXIM  = 1

         CALL OPFILEC(LUNIN,.FALSE.,FILOUT,LUNOUT,'O',
     &             ITYPE,NX,NY,NZ,
     &             MAXIM,'OUTPUT VOLUME',.FALSE.,IRTFLG)
         IF (IRTFLG .NE. 0)  GOTO 9999

         CALL RDPRAI(ISLICES,NILMAX,NSL, 1,NX,
     &            'OUTPUT SLICE NUMBERS',NULL,IRTFLG)
         IF (IRTFLG .NE. 0) GOTO 9999

      ELSE
C        NEW OUTPUT VOLUME, FILL ALL SLICES
         MAXIM  = 1

         NSL = NILMAX
         CALL RDPRAI(ISLICES,NILMAX,NSL, 1,NIMG,
     &            'OUTPUT SLICE NUMBERS',NULL,IRTFLG)
         IF (IRTFLG .NE. 0) GOTO 9999

         NZ          = MAXVAL(ISLICES(1:NIMG))
         LDONE(1:NZ) = .FALSE.

C        OPEN OUTPUT VOLUME
         CALL OPFILEC(LUNIN,.FALSE.,FILOUT,LUNOUT,'U',
     &                ITYPE,NX,NY,NZ,
     &                MAXIM,'OUTPUT VOLUME',.FALSE.,IRTFLG)
         IF (IRTFLG .NE. 0)  GOTO 9999

      ENDIF

      IF (NSL < NIMG) THEN
         CALL ERRT(102,'INSUFFICIENT SLICES',NSL)
         GOTO 9999
      ENDIF

      NLETV = lnblnkn(FILOUT)
        
      IF (VERBOSE) WRITE(NOUT,*) ' '

      NINDX = 1

      DO 

         IZ = ISLICES(NINDX)       ! OUTPUT SLICE

         IF (.NOT. EX) THEN
C           FILLING AN EMPTY VOLUME
            LDONE(IZ) = .TRUE.
         ENDIF

C        PUT FILE NUMBER INTO PATTERN
         CALL FILGET(FILPATIN,FILNAM,NLET,ILIST(NINDX),IRTFLG)
         IF (IRTFLG .NE. 0) GOTO 9999 

         NLETF = lnblnkn(FILNAM)
         IF (VERBOSE) WRITE(6,'(1X,4A,I6)')
     &                FILNAM(:NLETF),'  --> ',
     &                FILOUT(:NLETV),'   Z:',IZ

C        READ INPUT IMAGE
         CALL REDVOL(LUNIN,NX,NY, 1,1,BUFIMG,IRTFLG)
         IF (IRTFLG .NE. 0) GOTO 9999 

C        SAVE OUTPUT IMAGE AS VOLUME SLICE
         CALL WRTVOL(LUNOUT,NX,NY, IZ,IZ,BUFIMG,IRTFLG)
         IF (IRTFLG .NE. 0) GOTO 9999 

         
         IF (NINDX >= NIMG) EXIT      ! END OF INPUT LIST

C        OPEN NEXT INPUT FILE 
         CALL NEXTFILE(NINDX, ILIST, 
     &                 .FALSE.,LUNXM1,
     &                 NIMG, MAXIMIN,   
     &                 LUNIN,LUNCP, 
     &                 FILPATIN,'O',
     &                 IMGNUM, IRTFLG) 

         IF (IRTFLG < 0) EXIT         ! END OF INPUT FILES

         IF (IRTFLG .NE. 0) GOTO 9999    ! ERROR

      ENDDO

      IF (.NOT. EX) THEN
C        FILLING AN EMPTY VOLUME

         NFILLED = COUNT(MASK = (LDONE(1:NZ) .EQV. .TRUE. ))
         IF (NFILLED < NZ) THEN
            CALL ERRT(102,'HAS UNFILLED SLICES', NZ-NFILLED)
            GOTO 9999
         ENDIF
      ENDIF

9999  IF (ALLOCATED(BUFIMG))  DEALLOCATE(BUFIMG)
      IF (ALLOCATED(ILIST))   DEALLOCATE(ILIST)
      IF (ALLOCATED(LDONE))   DEALLOCATE(LDONE)
      IF (ALLOCATED(ISLICES)) DEALLOCATE(ISLICES)

      IF (VERBOSE) WRITE(NOUT,*) ' '

      CLOSE(LUNIN)
      CLOSE(LUNOUT)
      CLOSE(LUNXM1)
      
      END










