
C **********************************************************************
C
C  SOFTMASK                                      APR 2013 ArDean Leith 
C              3D BUG                            MAY 2014 ArDean Leith 
C
C **********************************************************************
C=*  AUTHOR: ArDean Leith                                              *
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
C  SOFTMASK
C
C  PURPOSE:   READS SPIDER IMAGE/VOLUME, CREATES SOFTEDGED GAUSSIAN OR
C             COSINE MASK OUTSIDE OF THRESHOLD VALUE.
C             CAN OPERATE ON IMAGE SERIES
C             CAN USE A SELECTION DOC FILE FOR IMAGE NUMBERS
C
C  NOTE:      SLOW FOR VOLUMES, BUT I DO NOT EXPECT MUCH USE SO NOT
C             OPTIMIZED AT ALL
C
C23456789012345678901234567890123456789012345678901234567890123456789012
C--*********************************************************************

      SUBROUTINE SOFTMASK

      IMPLICIT NONE
      INCLUDE 'CMBLOCK.INC'
      INCLUDE 'CMLIMIT.INC' 

C     DOC FILE POINTER
      REAL,    ALLOCATABLE   :: BUFIMG(:,:,:)
      INTEGER, ALLOCATABLE   :: ISURFX(:),ISURFY(:),ISURFZ(:)
      REAL,    ALLOCATABLE   :: BUF(:)
      INTEGER, ALLOCATABLE   :: ILIST1(:),ILIST2(:)

      CHARACTER (LEN=MAXNAM) :: FILPATIN,FILPATOUT
      CHARACTER (LEN=83)     :: PROMPT

      CHARACTER (LEN=1)      :: MODE,CDUM
      CHARACTER (LEN=1)      :: NULL = CHAR(0)
       
      INTEGER                :: IRTFLG,NX,NY,NZ,ITYPE
      INTEGER                :: MWANT,NOT_USED,IX,IY,IZ,IDISTSQMIN
      INTEGER                :: IXM1,IXP1,IYM1,IYP1,IZM1,IZP1,NSURF
      INTEGER                :: NILMAX,NDUM,IMGNUM,MAXIMIN,NE
      INTEGER                :: NLET,NIMG,LOCAT,LOCAST,NPIX,MAXIMOUT
      INTEGER                :: IMGNUMOUT,NIMGT,NIMGOUT,NC
      INTEGER                :: NINDX1,NINDX2,I,IDISTSQ,NINSIDE
               
      REAL                   :: HW,THRESH,DIST,WGH,DISTY

      INTEGER,PARAMETER      :: LUNIN     = 31 
      INTEGER,PARAMETER      :: LUNOUT    = 32
      INTEGER,PARAMETER      :: LUNDOCSEL = 81
      INTEGER,PARAMETER      :: LUNXM1    = 82
      INTEGER,PARAMETER      :: LUNXM2    = 83
      INTEGER,PARAMETER      :: LUNDOC    = 84

      REAL,   PARAMETER      :: QUADPI    = 3.141592653589793
      REAL,   PARAMETER      :: FLTZER    = 10E-30

      NILMAX  = NIMAXPLUS      ! FROM CMLIMIT
      ALLOCATE(ILIST1(NILMAX),
     &         ILIST2(NILMAX),
     &         STAT=IRTFLG)
      IF (IRTFLG .NE. 0) THEN
          CALL ERRT(46,'SOFTMASK; ILIST1....',2*NILMAX)
          RETURN
      ENDIF

C     OPEN INPUT IMAGE(S) (NOT FOURIER)
      CALL OPFILES(0,LUNIN,LUNDOCSEL,LUNXM1, 
     &             .TRUE.,FILPATIN,NLET, 'O',
     &             ITYPE,NX,NY,NZ,MAXIMIN,
     &             NULL,
     &             .FALSE.,ILIST1,NILMAX, 
     &             NDUM,NIMG,IMGNUM, IRTFLG) 
      IF (IRTFLG .NE. 0) RETURN

      IF (IMAMI .NE. 1) CALL NORM3(LUNIN,NX,NY,NZ,FMAX,FMIN,AV)

      IF ((FMAX - FMIN) < FLTZER) THEN
          CALL ERRT(101,'BLANK FILE',NE)
          GOTO 9999
      ENDIF

      LOCAT  = INDEX(FILPATIN,'@')
      LOCAST = INDEX(FILPATIN,'*')
      IF (NIMG > 0) ILIST2 = ILIST1
  
C     SINGLE IMAGE/VOLUME OPERATION 
      IF (NIMG <= 1) IMGNUM = 0
 
      NPIX = NX * NY * NZ        
      ALLOCATE(BUFIMG(NX,NY,NZ), 
     &         ISURFX(NPIX), ISURFY(NPIX), ISURFZ(NPIX),
     &         BUF(NX), 
     &         STAT=IRTFLG)
        IF (IRTFLG .NE. 0) THEN 
           MWANT = NPIX*4 + NX
           CALL ERRT(46,'SOFTMASK; SLICE1...,',MWANT)
           GOTO 9999
        ENDIF

C     OPEN OUTPUT IMAGE(S)
      PROMPT    = 'OUTPUT FILE NAME OR TEMPLATE (E.G. IMG@****)~'
      IF (LOCAST == 0)  PROMPT = 'OUTPUT'
      IF (LOCAST == 0 .AND. LOCAT > 0) PROMPT = 'OUTPUT STACK'
 
      MAXIMOUT  = -1           ! ALLOW BARE STACK
      IMGNUMOUT = IMGNUM       ! IMAGE # WANTED
      NIMGT     = -NIMG        ! USE FIRST LIST FOR OUTPUT

      CALL OPFILES(LUNIN,LUNOUT,LUNDOCSEL,LUNXM2,
     &            .TRUE.,FILPATOUT,NLET, 'U',
     &            ITYPE,NX,NY,NZ,MAXIMOUT,
     &            PROMPT,
     &            .FALSE., ILIST2,NIMGT, 
     &            NDUM,NIMGOUT, IMGNUMOUT, IRTFLG) 

      IF (IRTFLG .NE. 0) GOTO 9999
      !write(6,*)'output Image #:',IMGNUMOUT,NIMG,maximout,filpatout(:11)
      !write(6,*) 'fchar:',fchar(1:10)

      CALL RDPRMC(MODE,NC,.TRUE.,
     &            'GAUSSIAN or COSINE SOFTMASK (G,C)',CDUM,IRTFLG)
      IF (IRTFLG .NE. 0) GOTO 9999

C     FIND THRESHOLD LEVEL FOR MASKING            
      CALL RDPRM1S(THRESH,NOT_USED,'THRESHOLD LEVEL',IRTFLG)
      IF (IRTFLG .NE. 0) GOTO 9999

      IF (MODE == 'C' ) THEN
C        COSINE EDGE MASKING

	 CALL RDPRM1S(HW,NOT_USED,'WIDTH',IRTFLG)
         IF (IRTFLG .NE. 0) GOTO 9999

      ELSE IF (MODE == 'G' ) THEN
C        GAUSSIAN EDGE MASKING

	 CALL RDPRM1S(HW,NOT_USED,'HALFWIDTH',IRTFLG)
         IF (IRTFLG .NE. 0) GOTO 9999
         HW = -1.0 / (HW**2)
      ENDIF

      NINDX1  = 1
      NINDX2  = 1

      DO 

C       READ IMAGE OR VOLUME
        CALL REDVOL(LUNIN, NX,NY, 1,NZ, BUFIMG,IRTFLG)
        IF (IRTFLG .NE. 0) GOTO 9999 

        NSURF   = 0
        NINSIDE = 0

        IF (NZ > 1) THEN
C         VOLUME
          !write(nout,*)  'Image #:',IMGNUM,nx,ny,nz

          DO IZ = 1,NZ
             DO IY = 1, NY
                DO IX = 1, NX

                   IF (BUFIMG(IX,IY,IZ) >= THRESH) THEN
C                     ON SURFACE OF, OR INSIDE OBJECT AREA

                      NINSIDE = NINSIDE + 1

                      IXM1 = MAX(MOD(IX-1,NX),1)
                      IXP1 = MOD(IX+1,NX)

                      IYM1 = MAX(MOD(IY-1,NY),1)
                      IYP1 = MOD(IY+1,NY)

                      IZM1 = MAX(MOD(IZ-1,NZ),1)
                      IZP1 = MOD(IZ+1,NZ)

                      IF ((BUFIMG(IX,  IYM1,IZ)   < THRESH) .OR.
     &                    (BUFIMG(IX,  IYP1,IZ)   < THRESH) .OR.
     &                    (BUFIMG(IXM1,IY,  IZ)   < THRESH) .OR.
     &                    (BUFIMG(IXP1,IY,  IZ)   < THRESH) .OR.
     &                    (BUFIMG(IX,  IY,  IZM1) < THRESH) .OR.
     &                    (BUFIMG(IX,  IY,  IZP1) < THRESH)) THEN
C                        THIS IS A SURFACE VOXEL

                         NSURF         = NSURF + 1
                         ISURFX(NSURF) = IX
                         ISURFY(NSURF) = IY
                         ISURFZ(NSURF) = IZ
                      ENDIF
                   ENDIF
                ENDDO
             ENDDO
          ENDDO

          IF (VERBOSE .AND. IMGNUM > 0) THEN
             WRITE(NOUT,91) IMGNUM,NINSIDE,NSURF 
91           FORMAT('  IMAGE:',I6,
     &              '  OBJECT VOXELS: ',I7,'  SURFACE VOXELS: ',I7)

          ELSEIF (VERBOSE) THEN
             WRITE(NOUT,92) NINSIDE,NSURF 
92           FORMAT('  OBJECT VOXELS: ',I7,'  SURFACE VOXELS: ',I7)
          ENDIF


          DO IZ = 1,NZ
             DO IY = 1, NY
                DO IX = 1, NX

                   IF (BUFIMG(IX,IY,IZ) >= THRESH) THEN
C                     IN 100% AREA 

                      BUF(IX) =  BUFIMG(IX,IY,IZ)

                   ELSE
C                     NOT IN 100% MASK AREA 
   
                      IDISTSQMIN = HUGE(IDISTSQMIN)
                      DO I = 1,NSURF

                         IDISTSQ = (IX - ISURFX(I))**2 + 
     &                             (IY - ISURFY(I))**2 +
     &                             (IZ - ISURFZ(I))**2

                         IF (IDISTSQ < IDISTSQMIN) THEN
C                           DISTANCE IS LESS THAN PREVIOUS CLOSEST

                            IDISTSQMIN = IDISTSQ
                         ENDIF
                      ENDDO   ! END OF: DO I = 1,NSURF

                      DIST = SQRT(FLOAT(IDISTSQMIN))

	              IF (MODE == 'C' ) THEN
C                        COSINE EDGE MASKING

		         BUF(IX)  = (1.0 + 
     &                     COS(QUADPI*MIN(1.0, DIST/HW))) * 0.5

                      ELSE IF (MODE == 'G' ) THEN
C                        GAUSSIAN EDGE MASKING

		         WGH  = HW * DIST **2

		         IF (WGH < -50.0)  THEN
		            BUF(IX) = 0.0
		         ELSE
		            BUF(IX) = EXP(WGH)
		         ENDIF
                      ENDIF
                   ENDIF       ! END OF: (BUFIMG(IX,IY,IZ) < THRESH....
	        ENDDO          ! END OF:DO IX = 1, NX

C               SAVE OUTPUT VOL
                CALL WRTLIN(LUNOUT,BUF,NX,(IZ -1)*NY+IY)
 
	     ENDDO          ! END OF:DO IY = 1, NY
	  ENDDO             ! END OF:DO IZ = 1, NZ
 
        ELSE
C         IMAGE xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
          !write(nout,*)  'Image #:',IMGNUM,thresh

          IZ = 1
          DO IY = 1, NY
             DO IX = 1, NX

                !write(6,*) 'Image #:',ix,iy,bufimg(ix,iy,iz)

                IF (BUFIMG(IX,IY,IZ) >= THRESH) THEN
C                  ON SURFACE OF, OR INSIDE OBJECT AREA

                   NINSIDE = NINSIDE + 1

                   IXM1 = MAX(MOD(IX-1,NX),1)
                   IXP1 = MOD(IX+1,NX)

                   IYM1 = MAX(MOD(IY-1,NY),1)
                   IYP1 = MOD(IY+1,NY)

                   IF ((BUFIMG(IX,  IYM1,IZ) < THRESH) .OR.
     &                 (BUFIMG(IX,  IYP1,IZ) < THRESH) .OR.
     &                 (BUFIMG(IXM1,IY,  IZ) < THRESH) .OR.
     &                 (BUFIMG(IXP1,IY,  IZ) < THRESH)) THEN
C                      THIS IS A SURFACE PIXEL

                       NSURF         = NSURF + 1
                       ISURFX(NSURF) = IX
                       ISURFY(NSURF) = IY
                   ENDIF
                ENDIF
             ENDDO
          ENDDO

          !write(6,'(a,(5i5))') ' surfx:',isurfx(1:5)
          !write(6,'(a,(5i5))') ' surfy:',isurfy(1:5)

          IF (VERBOSE .AND. IMGNUM > 0) THEN
             WRITE(NOUT,94) IMGNUM,NINSIDE,NSURF 
94           FORMAT('  IMAGE:',I6,
     &              '  OBJECT PIXELS:',I7,'  SURFACE PIXELS: ',I7)

          ELSEIF (VERBOSE) THEN
             WRITE(NOUT,95) NINSIDE,NSURF 
95           FORMAT('  OBJECT PIXELS:',I7,'  SURFACE PIXELS: ',I7)
          ENDIF

          DO IY = 1, NY
             DO IX = 1, NX

                IF (BUFIMG(IX,IY,IZ) >= THRESH) THEN
C                  IN 100% AREA 

                   BUF(IX) = BUFIMG(IX,IY,IZ)
                   !if(iy == 80)write(6,*)  'Ix:',ix,iy,buf(ix)

                ELSE
C                  NOT IN 100% MASK AREA 
   
                   IDISTSQMIN = HUGE(IDISTSQMIN)
                   DO I = 1,NSURF

                      IDISTSQ = (IX - ISURFX(I))**2 + 
     &                          (IY - ISURFY(I))**2
                      !if(iy == 80)write(6,*) 'I:',IDISTSQ

C                     IF DISTANCE IS LESS THAN PREVIOUS CLOSEST
                      IF (IDISTSQ < IDISTSQMIN) IDISTSQMIN = IDISTSQ

                   ENDDO   ! END OF: DO I = 1,NSURF

                   DIST = SQRT(FLOAT(IDISTSQMIN))

	           IF (MODE == 'C' ) THEN
C                     COSINE EDGE MASKING

		      BUF(IX)  = (1.0 + 
     &                    COS(QUADPI*MIN(1.0, DIST/HW))) * 0.5

                   ELSE IF (MODE == 'G' ) THEN
C                     GAUSSIAN EDGE MASKING

		      WGH  = HW * DIST **2

		      IF (WGH < -50.0)  THEN
		         BUF(IX) = 0.0
		      ELSE
		         BUF(IX) = EXP(WGH)
		      ENDIF
                      !if(iy == 80)write(6,*)'v:',ix,iy,dist,wgh,buf(ix)

                   ENDIF

                ENDIF    ! END OF: (BUFIMG(IX,IY,IZ) < THRESH....
	     ENDDO       ! END OF:DO IX = 1, NX

C            SAVE OUTPUT IMAGE
             CALL WRTLIN(LUNOUT,BUF,NX,IY)
 
	   ENDDO         ! END OF:DO IY = 1, NY
        ENDIF     


C       SET OPERATION LINE REGISTERS
        CALL REG_SET_NSEL(1,2,FLOAT(NINSIDE),FLOAT(NSURF),
     &                    0.0,0.0,0.0,IRTFLG)

        IF (NINDX1 >= NIMG) EXIT      ! END OF INPUT LIST
             
C       OPEN NEXT SET OF I/O FILES 
        !write(6,*) NINDX1, NINDX2,NIMG,NIMGOUT,MAXIMIN,MAXIMOUT
        !write(6,*) LUNIN,LUNIN,LUNOUT, FILPATIN,FILPATOUT,IMGNUM,IMGNUMOUT
        CALL NEXTFILES(NINDX1, NINDX2, ILIST1,ILIST2, 
     &                 .FALSE.,LUNDOC,LUNXM2,
     &                  NIMG,NIMGOUT,   
     &                  MAXIMIN,MAXIMOUT,   
     &                  LUNIN,LUNIN,LUNOUT, FILPATIN,FILPATOUT,
     &                  IMGNUM,IMGNUMOUT, IRTFLG) 

          !write(6,'(A,5i6)')
      !&       ' Nextfiles imgnum,imgnumout,nindx1,nindx2,irtflg:',
      !&                   imgnum,imgnumout,nindx1,nindx2,irtflg

         IF (IRTFLG == -99) THEN
             CALL ERRT(102,'INSUFFICIENT OUTPUT FILE NAMES',NINDX2)
             EXIT         
         ELSEIF (IRTFLG < 0) THEN
             EXIT         ! END OF INPUT FILES
         ENDIF
         IF (IRTFLG .NE. 0) GOTO 9999    ! ERROR

      ENDDO

9999  IF (ALLOCATED(BUFIMG))  DEALLOCATE(BUFIMG)
      IF (ALLOCATED(BUF))     DEALLOCATE(BUF)
      IF (ALLOCATED(ILIST1))  DEALLOCATE(ILIST1)
      IF (ALLOCATED(ILIST2))  DEALLOCATE(ILIST2)
      IF (ALLOCATED(ISURFX))  DEALLOCATE(ISURFX)
      IF (ALLOCATED(ISURFY))  DEALLOCATE(ISURFY)
      IF (ALLOCATED(ISURFZ))  DEALLOCATE(ISURFZ)

      IF (VERBOSE) WRITE(NOUT,*) ' '

      CLOSE(LUNIN)
      CLOSE(LUNOUT)
      CLOSE(LUNXM1)
      CLOSE(LUNXM2)
      
      END












