C++*********************************************************************
C                                                                      *
C    AP_SH_TOOL.F    FROM APSH_PSC                  SEP 10 ARDEAN LEITH *
C                    APSH_TOOL,GETANGAS             FEB 11 ARDEAN LEITH
C                                                                      *
C **********************************************************************
C=* This file is part of:                                              * 
C=* SPIDER - Modular Image Processing System.                          *
C=* Authors: J. Frank & A. Leith                                       *
C=* Copyright 1985-2011  Health Research Inc.                          *
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
C=*                                                                    *
C=* You should have received a copy of the GNU General Public License  *
C=* along with this program. If not, see <http://www.gnu.org/licenses> *       
C=*                                                                    *
C **********************************************************************
C
C  APSH_TOOL 
C  
C  PURPOSE: FIND ROTATIONAL AND SHIFT PARAMETERS TO ALIGN A SERIES OF
C           REFERENCE IMAGES WITH SAMPLE IMAGES
C           USES COEFFICIENTS, TRANSPOSED RINGS, AND
C           COMPLEX FORTRAN VARIABLES.

C  SOME PARAMETERS:
C       IREFLIST            LIST OF REF. IMAGE FILE NUMBERS   (INPUT)
C       NUMREF              NO. OF IMAGES                     (INPUT)
C       IEXPLIST            LIST OF EXP. IMAGE FILE NUMBERS   (INPUT)
C       NUMEXP              NO. OF IMAGES                     (INPUT)
C       NSAM,NROW           ACTUAL (NOT-WINDOWED) IMAGE SIZE  (INPUT)
C       REFANGDOC           REF. ANGLES FILE NAME             (INPUT)
C       REFPAT              REF. IMAGE SERIES FILE TEMPLATE   (INPUT)
C       EXPPAT              EXP. IMAGE SERIES FILE TEMPLATE   (INPUT)
C
C23456789012345678901234567890123456789012345678901234567890123456789012
C--*********************************************************************

cpgi$g opt=3

C     **************** APSH_SAM_INFO **********************************


      MODULE APSH_SAM_INFO 

C     PURPOSE: INITIALIZES SAMPLING COUNTERS

         INTEGER,PARAMETER  :: NSIZES = 40
         INTEGER,PARAMETER  :: NSTEPZ = 8
         INTEGER,PARAMETER  :: NSKIPZ = 8

         REAL               :: CC_BAD_Z(0:NSIZES,NSTEPZ) ! SUM OF BAD SIZE CC
         INTEGER            :: NN_GUD_Z(0:NSIZES,NSTEPZ) ! # OF GOOD SIZES
         INTEGER            :: NN_SAM_Z(0:NSIZES,NSTEPZ) ! # OF SIZE SAMPLES
         INTEGER            :: NN_BORDR(0:NSIZES,NSTEPZ) ! # OF SIZE SAMPLES

         REAL               :: QSTEP(0:NSIZES,NSTEPZ)   
         INTEGER            :: IQX(0:NSIZES,NSTEPZ)   
         INTEGER            :: IQY(0:NSIZES,NSTEPZ)   


         INTEGER            :: NN_GUD_R(NSKIPZ)          ! # OF GOOD SKIPS
         REAL               :: SU_GUD_R(NSKIPZ)          ! SUM OF CC

         REAL               :: CC_SAM_R(NSKIPZ)          ! TOP CC 
         REAL               :: CC_TOP_R(NSKIPZ)          ! TOP CC's OTHER SKIPS 
         REAL               :: CM_SAM_R(NSKIPZ)          ! TOP NOSKIP CC
         INTEGER            :: IR_SAM_R(NSKIPZ)          ! REF #
         INTEGER            :: IX_SAM_R(NSKIPZ)          ! X SHIFT 
         INTEGER            :: IY_SAM_R(NSKIPZ)          ! Y SHIFT
         INTEGER            :: IA_SAM_R(NSKIPZ)          ! ROT #
 
         INTEGER            :: LOCBEST(-NSIZES:NSIZES,-NSIZES:NSIZES)
         INTEGER            :: LOCBESTA(-NSIZES:NSIZES,-NSIZES:NSIZES)

         INTEGER            :: NN_SAM_R                  ! # (=#EXP)                  

      END MODULE APSH_SAM_INFO


C     **************** APSH_TOOL *************************************

        SUBROUTINE APSH_TOOL(IREFLIST,NUMREF,IEXPLIST,NUMEXP, 
     &               NSAM,NROW,ISHRANGEX,ISHRANGEY,ISTEP,
     &               NRING,LCIRC,NUMR,CIRCREF,
     &               REFANGDOC,FFTW_PLANS,
     &               REFPAT,EXPPAT,CKMIRROR,LUNDOC,SHORRING)


        INCLUDE 'CMLIMIT.INC'
        INCLUDE 'CMBLOCK.INC'

	INTEGER              :: IREFLIST(NUMREF) 
	INTEGER              :: IEXPLIST(NUMEXP)
        INTEGER              :: NUMR(3,NRING)
	REAL                 :: CIRCREF(LCIRC,NUMREF)
	LOGICAL              :: CIRCREF_IN_CORE
        LOGICAL              :: CKMIRROR
	LOGICAL              :: MIRRORNEW
	LOGICAL              :: GOTREFANG
        LOGICAL              :: WEIGHT
        INTEGER *8           :: FFTW_PLANS(*) ! STRUCTURE POINTERS

        CHARACTER (LEN=1)    :: SCRFILE,SHORRING,MODE
        CHARACTER (LEN=*)    :: REFANGDOC,REFPAT,EXPPAT 

        INTEGER              :: LUNDOC
        LOGICAL              :: TRANS         ! FLAG FOR REFORMED RINGS
        LOGICAL              :: CPLX          ! FLAG FOR COMPLEX CROSRNG

C       AUTOMATIC ARRAYS
	REAL                 :: ANGOUT(3)

C       ALLOCATED ARRAYS
	REAL,    ALLOCATABLE :: ABUF(:,:)
	REAL,    ALLOCATABLE :: ANGREF(:,:)
        REAL,    ALLOCATABLE :: COEFFS(:,:)
        INTEGER, ALLOCATABLE :: IXY(:,:)

	REAL                 :: ANGEXP(8,1)
        INTEGER              :: ITMAX

        INTEGER, PARAMETER   :: NLISTMAX = 15
        REAL                 :: PARLIST(NLISTMAX)
        REAL                 :: ADUM

        REAL,    PARAMETER   :: QUADPI     = 3.1415926535897932384626
        REAL,    PARAMETER   :: DGR_TO_RAD = (QUADPI/180)

        INTEGER, PARAMETER   :: LUNT       = 77
        INTEGER, PARAMETER   :: INANG      = 78
        INTEGER, PARAMETER   :: LUNRING    = 50
 
        INTEGER              :: NBORDER    = 0    ! # BORDER PIXELS
        INTEGER              :: NSUBPIX    = 0    ! # SUBPIX PIXELS
        INTEGER              :: MYPID      = -1   ! NOT FOR MPI

        SCRFILE         = CHAR(0)             ! NO REF. RINGS FILE
        CIRCREF_IN_CORE = .TRUE.              ! INCORE REF. RINGS
        MODE            = 'F'                 ! FULL CIRCLE

C       SET TYPE OF OUTPUT DOC FILES WANTED
        NWANTOUT = 15

        IF (SHORRING .EQ. 'S' .OR. SHORRING .EQ. 'R') THEN
C          INITIALIZE CCROT SAMPLING COUNTERS
           CALL APSH_SAM_INIT()
        ENDIF

C       INITIALIZE CCROT STATISTICS COUNTERS
        ANGDIFTHR   = 0.0
        CALL  AP_STAT_ADD(-1,CCROT,ANGDIF,ANGDIFTHR,CCROTLAS,
     &                   CCROTAVG,IBIGANGDIF,ANGDIFAVG,IMPROVCCROT,
     &                   CCROTIMPROV,IWORSECCROT,CCROTWORSE)

        NRAYSC      = NUMR(3,NRING) / 2     ! # OF RAYS   (FOURIER)
        CALL FLUSHRESULTS()
 
	ALLOCATE(ABUF(NSAM,NROW), 
     &           COEFFS(6,LCIRC),
     &           IXY(2,LCIRC),      
     &           STAT=IRTFLG)
	IF (IRTFLG .NE. 0) THEN
           MWANT = NSAM*NROW + 6*LCIRC + 2*LCIRC   
           CALL  ERRT(46,'ABUF...',MWANT)
           GOTO 9999
        ENDIF 
        IXY    = -100      ! FOR HANDLING CIRC PADS
        COEFFS = 0.0
        WEIGHT = .TRUE.    ! REF. IMAGES HAVE WEIGHTED FFT'S
        TRANS  = .FALSE.   ! USE NON-REFORMED RINGS/RAYS
        CPLX   = .TRUE.    ! USE COMPLEX CROSRNG

C       READ REFERENCE IMAGES INTO REFERENCE RINGS ARRAY (CIRCREF) OR
C       CREATE REFERENCE RINGS FILE FOR LATER READING
C       SAVES COEFFS FOR LATER USE 
        CALL APRINGS_NEW_COEF(IREFLIST,NUMREF,  NSAM,NROW,
     &                       NRING,LCIRC,NUMR, NDUM,NRAYSC,
     &                       COEFFS,IXY,
     &                       MODE,FFTW_PLANS,
     &                       REFPAT,LUNT, CIRCREF,CIRCREF_IN_CORE,
     &                       LUNRING,SCRFILE, WEIGHT, TRANS,IRTFLG)

       !call chkring(2,.false., circref,lcirc, numr,nring, ndum,ndum)
       !call chkray (2,.false., circref,lcirc, numr,nring, ndum,ndum)

C       ALWAYS USES REFANGLES FILE
        GOTREFANG = .TRUE.
	ALLOCATE(ANGREF(3,NUMREF), STAT=IRTFLG)
	IF (IRTFLG .NE. 0) THEN
            CALL ERRT(46,'ANGREF',3*NUMREF)
            GOTO 9999
        ENDIF 

C       READ REF. ANGLES INTO ANGREF
        CALL AP_GETANGAS(IREFLIST,NUMREF,0,REFANGDOC,REFPAT,
     &                   LUNT,INANG,3,ANGREF,GOTREFANG,NGOTREF,
     &                  .FALSE.,FDUM,IRTFLG)
        IF (IRTFLG .NE. 0) GOTO 9999

        IF (VERBOSE .AND. SHORRING .EQ. 'R')  WRITE(6,*) ' '

        NGOTPAR = 0

C       LOOP OVER ALL EXPERIMENTAL (SAMPLE) IMAGES -----------------
        NUMTH   = 1
        FRACSAY = FLOAT(NUMEXP) / 20.0  ! PRINT OUT AFTER EVERY 5%

 	DO IEXP=1,NUMEXP

C          LOAD EXP. IMAGE DATA FOR THIS IMAGE
	   CALL AP_GETDATA(IEXPLIST,NUMEXP,
     &                     NSAM,NROW, NSAM,NROW,0.0,
     &                     NUMTH,EXPPAT,LUNT, IEXP,IEXP,
     &                     .TRUE.,  ABUF,  
     &                     .FALSE.,ADUM,ADUM, IRTFLG)
           IF (IRTFLG .NE. 0) GOTO 9999


           IF (VERBOSE .AND. SHORRING .EQ. 'R') THEN
              WRITE(6,'(A,I5,A)') ' IMAGE:',IEXP,' -----'
           ENDIF

 	   CALL APRQ2_SAM(ABUF,CIRCREF,NUMR,
     &	            NSAM,NROW,ISHRANGEX,ISHRANGEY,ISTEP,
     &	            LCIRC,NRING,NUMREF,
     &              IREF,CCROT,
     &              RANGNEW,XSHNEW,
     &              YSHNEW,NPROJ,
     &              CKMIRROR,FFTW_PLANS,SHORRING,
     &              COEFFS,IXY,NRAYSC,TRANS,CPLX,
     &              NBORDER,NSUBPIX)

C          CCROT   - NOT-NORMALIZED CORRELATION COEFFICIENT.
C          RANGNEW - PSI ANGLE. (IN=PLANE ROTATION) RANGNEW
C          XSHNEW  - SX SHIFT  (NOT FOR ALIGNMENT!!!)
C          YSHNEW  - SY SHIFT  (NOT FOR ALIGNMENT!!!)
         
C          IREF      = # OF MOST SIMILAR REFERENCE PROJECTION.
C                      (<0 IF MIRRORED, 0 IF NO SIMILAR IMAGE )
           MIRRORNEW = (IREF .LT. 0)
           IREF      = ABS(IREF)
           IMGREF    = IREFLIST(IREF)
           IMGEXP    = IEXPLIST(IEXP)
           PEAKV     = 1.0

           CALL AP_END(IEXP,IMGEXP,IMGREF,
     &                ANGREF(1,IREF),DUMMY,
     &                ANGEXP(1,IEXP), DUMMY,ISHRANGEX,
     &                GOTREFANG, NGOTPAR, CCROT,PEAKV,
     &                RANGNEW,XSHNEW,YSHNEW, MIRRORNEW,REFPAT,
     &                NPROJ, 'SH', LUNDOC,PARLIST)

           CALL AP_STAT_ADD(NGOTPAR,CCROT,PARLIST(10),
     &                      ANGDIFTHR,ANGEXP(8,IEXP),
     &                      CCROTAVG,IBIGANGDIF,ANGDIFAVG,IMPROVCCROT,
     &                      CCROTIMPROV,IWORSECCROT,CCROTWORSE)

C          PRINT OUT REPORTS EVERY SO OFTEN AND AT END
           IF (SHORRING .EQ. 'R') THEN
              IF (IEXP .EQ. NUMEXP) THEN
                 CALL APSH_SKIP_REPORT(8)
                 EXIT
              ELSEIF (VERBOSE .AND. IEXP > FRACSAY) THEN
                 WRITE(6,'(A,I6)') ' Finished image:',IEXP
                 FRACSAY = FRACSAY + FLOAT(NUMEXP) / 20.0
                 CALL APSH_SKIP_REPORT(8)
              ENDIF

           ELSEIF (SHORRING .EQ. 'S') THEN
C             SIZE AND STEP REPORT
              ITMAX = MAX(ISHRANGEX,ISHRANGEY)
              IF (IEXP .EQ. NUMEXP) THEN
                 CALL APSH_SAM_REPORT(ITMAX,ISHRANGEX,ISHRANGEY)
                 EXIT
              ELSEIF (VERBOSE .AND. IEXP > FRACSAY) THEN
                 WRITE(6,'(A,I6)') ' Finished image:',IEXP
                 FRACSAY = FRACSAY + FLOAT(NUMEXP) / 20.0
                 CALL APSH_SAM_REPORT(ITMAX,ISHRANGEX,ISHRANGEY)
              ENDIF
           ENDIF
 	ENDDO

        WRITE(6,90) NUMEXP,NUMREF
90      FORMAT(/,' EXP. IMAGES:',I5,'  REFERENCES:',I5)


C      SAVE CCROT & ANGULAR DISPLACEMENT STATISTICS IN DOC FILE
       CALL AP_STAT(NUMEXP,ANGDIFTHR,IBIGANGDIF,
     &                 ANGDIFAVG, CCROTAVG,
     &                 IMPROVCCROT,CCROTIMPROV,
     &                 IWORSECCROT,CCROTWORSE,
     &                 NBORDER,NSUBPIX,LUNDOC)

9999    CONTINUE

C       DEALLOCATE  ARRAYS
	IF (ALLOCATED(ABUF))       DEALLOCATE(ABUF)
	IF (ALLOCATED(ANGREF))     DEALLOCATE(ANGREF)
        IF (ALLOCATED(COEFFS))     DEALLOCATE(COEFFS)
        IF (ALLOCATED(IXY))        DEALLOCATE(IXY)

	END



C+**********************************************************************
C
C APRQ2_SAM.F
C 
C  PURPOSE:  compares one exp image vs all ref images to obtain
c            best cc val for the exp image.  returns alignment
c            parameters for best match
c
C  PARAMETERS:   IDIS    NUMBER OF  MOST SIMILAR REF. PROJ.   (OUTPUT)
C                            (NEGATIVE IF MIRRORED)
C                CCROT    CORR COEFF.                         (OUTPUT)
C                RANGNEW  INPLANE ANGLE                       (OUTPUT)
C                XSHSUM   SHIFT                               (OUTPUT)
C                YSHSUM   SHIFT                               (OUTPUT)
C                NPROJ                                        (OUTPUT)
C
C-**********************************************************************

	SUBROUTINE APRQ2_SAM(EXPBUF,CIRCREF,NUMR,
     &	             NSAM,NROW,ISHRANGEX,ISHRANGEY,ISTEP,
     &	             LCIRC,NRING,NUMREF,
     &               IDIS,CCROT,RANGNEW,XSHSUM,YSHSUM,NPROJ,
     &               CKMIRROR,FFTW_PLANS,SHORRING,
     &               COEFFS,IXY,NRAYSC, TRANS,CPLX,
     &               NBORDER,NSUBPIX)

C       NOTE: RUNS WITHIN OMP PARALLEL SECTION OF CODE!

        USE APSH_SAM_INFO

	REAL                   :: EXPBUF(NSAM,NROW)
        REAL                   :: CIRCREF(LCIRC,NUMREF)
        INTEGER                :: NUMR(3,NRING) 
        REAL                   :: COEFFS(6,LCIRC)
        INTEGER                :: IXY(2,LCIRC)

        CHARACTER (LEN=1)      :: MODE,SHORRING
        INTEGER *8             :: FFTW_PLANS(*)  ! STRUCTURE POINTERS
        LOGICAL                :: TRANS          ! TRANSFORMED RAYS
        LOGICAL                :: CPLX           ! COMPLEX CROSRNG

C       AUTOMATIC ARRAYS
	REAL                   ::  CC_NOW(-ISHRANGEX:ISHRANGEX,
     &                                    -ISHRANGEY:ISHRANGEY)
	REAL                   :: CC_BEST(-ISHRANGEX:ISHRANGEX,
     &                                    -ISHRANGEY:ISHRANGEY)

	REAL                   :: CC(-ISTEP:ISTEP,-ISTEP:ISTEP)
	REAL                   :: CCP(-1:1,-1:1)
        REAL                   :: CIRCEXP(LCIRC),CIRCT(LCIRC)
        !!REAL                 :: QU(2*NRAYSC),QM(2*NRAYSC)

	REAL                   :: CCROT, CCOA
        LOGICAL                :: CKMIRROR,MIRRORED
        LOGICAL                :: ISMIRRORED,USE_UN,USE_MIR

        REAL                   :: WR(1)
 	REAL                   :: ROTMP

        INTEGER                :: NSKIP           ! MAXIMUM RING SKIP 1...4
        INTEGER                :: NASKIP(NSKIPZ)  ! ROTATION
	REAL                   :: CCSKIP(NSKIPZ)  ! CC VALUE 
	REAL                   :: CCSKIPA(NSKIPZ) ! CC VALUE 

        REAL, PARAMETER        :: QUADPI     = 3.1415926535
        REAL, PARAMETER        :: DGR_TO_RAD = (QUADPI/180)

        LOGICAL, PARAMETER     :: USE_OMP    = .FALSE.


        WR(1)  = 0.0                ! DUMMY VALUE FLAG FOR APRINGS CALL
        NRAYS  = NUMR(3,NRING) - 2  ! ACTUAL LENGTH OF LONGEST RING

	QSTEP  = 0                  ! ARRAY INITIALIZED EACH IMG
	IQX    = -999999            ! ARRAY INITIALIZED EACH IMG
        IQY    = -999999            ! ARRAY INITIALIZED EACH IMG

        MODE   = 'F'
        NPROJ  = NUMREF
	CCROT  = -HUGE(CCROT)
        NSKIP  = 1
        IF (SHORRING .EQ. 'R') THEN
           NSKIP = NSKIPZ
           CALL APSH_SKIP_INIT()   ! ZERO FOR THIS EXP. IMAGE
        ENDIF

C       SEARCH BOTH MIRRORED & NON-MIRRORED IF CHKMIR
        USE_UN  = .TRUE.
        USE_MIR = CKMIRROR

C       COMPARE EXP. IMAGE WITH ALL REFERENCE IMAGES ------------------
	DO IR=1,NUMREF

c          GO THROUGH CENTERS FOR SHIFT ALIGNMENT
	   DO JT= -ISHRANGEY,ISHRANGEY,ISTEP
	      CNR2 = NROW / 2 + 1 + JT

	      DO IT= -ISHRANGEX,ISHRANGEX,ISTEP
	         CNS2 = NSAM / 2 + 1 + IT

C                NORMALIZE IMAGE VALUES UNDER THE MASK OVER VARIANCE RANGE
C                INTERPOLATE TO POLAR COORD., CREATE FOURIER OF RINGS.
C                NO WEIGHTING OF RINGS        

                 CALL APRINGS_ONE_COEF(EXPBUF, NSAM,NROW, CNS2,CNR2, 
     &                              NUMR,NRING, NDUM,NRAYSC,
     &                              COEFFS,IXY,
     &                              .FALSE., WR, FFTW_PLANS, TRANS,
     &                              CIRCT,LCIRC, CIRCEXP, IRTFLG)

C                COMPARE EXP. IMAGE WITH REFERENCE IMAGE
C                USING COEF & COMPLEX VARIABLES

                 IF (SHORRING .EQ. 'S') THEN
                    CALL CROSRNG_2C(CIRCREF(1,IR),CIRCEXP,LCIRC/2,
     &                        NRING, NRAYS,NUMR,
     &                        USE_OMP,FFTW_PLANS(1),
     &                        USE_UN,USE_MIR,
     &                        ISMIRRORED,CCOA,POS_MAX,MAXL)

                    CC_NOW(IT,JT) = CCOA    ! SAVE CC FOR THIS REF

                 ELSEIF (SHORRING .EQ. 'R') THEN
                    
                    CALL CROSRNG_2C_TOOL(CIRCREF(1,IR),CIRCEXP,LCIRC/2,
     &                        NRING, NRAYS,NUMR, 
     &                        USE_OMP,FFTW_PLANS(1),
     &                        USE_UN,USE_MIR,
     &                        ISMIRRORED,CCOA,POS_MAX,
     &                        NASKIP,CCSKIP,CCSKIPA,NSKIP,
     &                        IR,IT,JT)

                    !write(6,921) ir,it,jt,ccoa,POS_MAX,NASKIP(ISKIP)
c921                 format(' ir:',i5,' (',i3,',',i3,'):',f12.4,2x,1f8.2,i6)

                 ENDIF                   ! END OF: IF (SHORRING .EQ. 'S')

                 IF (CCOA .GE. CCROT)  THEN
C                   GOOD MATCH WITH NEW (MIRRORED OR NOT) POSITION 
	            CCROT   = CCOA
	            IBE     = IR
	            ISX     = IT
	            ISY     = JT
	            RANGNEW = ANG_N(POS_MAX,MODE,NRAYS)
	            IDIS    = IR
                    IF (ISMIRRORED) IDIS = -IR
	         ENDIF ! END OF: IF (CCOA .GE.....

              ENDDO    ! END OF: DO IT=-ISHRANGEX,ISHRANGEX...
	   ENDDO       ! END OF: DO JT=-ISHRANGEY,ISHRANGEY...

           IF (SHORRING .EQ. 'S') THEN
C             SAVES THE CC VALUES FOR SHIFTS FROM EACH REF. IMAGE
              CALL APSH_SAM_SH(CC_NOW,ISHRANGEX,ISHRANGEY)
              !write(6,*) 'ccnow:',CC_NOW(-1:1,-1:1)
           ENDIF

C          IF THIS IS BEST REF SO FAR, SAVE CC MATRIX FOR THIS REF
           IF (SHORRING .EQ. 'S' .AND. IBE .EQ. IR)  CC_BEST = CC_NOW    

        ENDDO       ! END OF:  DO IR=1,... --------------------- REFS.
 
        IF (SHORRING .EQ. 'S') THEN
C          SAMPLE BEST CC VALUES FROM CURRENT EXP. IMAGE
           CALL APSH_SAM_SIZE(CC_BEST,CCROT, ISX,ISY,
     &                        ISHRANGEX,ISHRANGEY)

        ELSEIF (SHORRING .EQ. 'R') THEN
C          SAMPLE BEST CC VALUES FROM CURRENT EXP IMAGE
           CALL APSH_SAM_SKIPS(NSKIP)
        ENDIF

        SX    = -ISX              ! BEST X SHIFT, CHANGE SIGN
        SY    = -ISY              ! BEST Y SHIFT, CHANGE SIGN
 
        IF (ABS(ISX).EQ.ISHRANGEX .OR. ABS(ISY).EQ.ISHRANGEY)THEN
C          THIS IS A BORDER PIXEL
           NBORDER = NBORDER + 1
        ENDIF

C       DID NOT CHANGE ORDER OF SHIFT & ROTATION. (UNLIKE AP SH!!!!!)
C       DO NOT USE THESE FOR ALIGNMENT

	XSHSUM = SX
	YSHSUM = SY

9999    CONTINUE

	END

C************************ APSH_SKIP_INIT ******************************

        SUBROUTINE APSH_SKIP_INIT()

        USE APSH_SAM_INFO

        IMPLICIT NONE

        CC_SAM_R = 0.0           ! ZERO CC ARRAY

        END

C************************* APSH_SAM_SKIP ******************************


        SUBROUTINE APSH_SAM_SKIP(CCSKIP,NASKIP,CCSKIPA,NSKIP, 
     &                           IR,ISX,ISY, QQ,NRAYS)

C       PURPOSE: CHECKS RING SKIPS FOR THIS REF. IMAGE TO RECORD 
C                PARAMETERS FOR HIGHER CC'S, CALLED IN CROSNG FOR EACH
C                EACH SHIFTED EXP - REF IMAGE COMPARISON.

        USE APSH_SAM_INFO

        IMPLICIT NONE

	REAL, INTENT(IN)      :: CCSKIP(NSKIP)  ! SAMPLED TOP CC VALUE
	INTEGER, INTENT(IN)   :: NASKIP(NSKIP)  ! SAMPLED TOP ROTATION
	REAL, INTENT(IN)      :: CCSKIPA(NSKIP) ! SAMPLED TOP NO-SKIP CC VALUE

        INTEGER, INTENT(IN)   :: NSKIP,IR,ISX,ISY

	REAL, INTENT(IN)      :: QQ(*)          ! unused FFT'D CCROT RETURN FOR NO SKIP
        INTEGER, INTENT(IN)   :: NRAYS

        REAL                  :: CCONE,CCNOW,CCTOP,CCOLD,tmp 
        INTEGER               :: ISKIP,IROT,IROTSAV
        LOGICAL               :: SAVEALL

        REAL                  :: CCSET           ! FUNCTION

        SAVEALL = .FALSE.

        DO ISKIP = 1,NSKIP             ! LOOP OVER SKIPS

           CCONE = CCSKIPA(ISKIP)       ! CURRENT 1-SKIP CC OF BEST CC FOR THIS SKIP
           CCNOW = CCSKIP(ISKIP)        ! CURRENT BEST CC FOR THIS SKIP
           CCTOP = CC_SAM_R(ISKIP)      ! TOP CC FOR THIS SKIP 
           IROT  = NASKIP(ISKIP)        ! CURRENT ROTATION # FOR THIS SKIP
           CCOLD = CM_SAM_R(ISKIP)      ! TOP 1-SKIP CC

           IF (CCNOW > CCTOP) THEN
C             HIGHEST CC SO FAR FOR THIS SKIP, RECORD IT

              CM_SAM_R(ISKIP) = CCONE  ! TOP NO-SKIP CC
              CC_SAM_R(ISKIP) = CCNOW  ! TOP CC

              IR_SAM_R(ISKIP) = IR     ! REF #
              IX_SAM_R(ISKIP) = ISX    ! X SHIFT
              IY_SAM_R(ISKIP) = ISY    ! Y SHIFT
              IA_SAM_R(ISKIP) = IROT   ! ROTATION

              IF (ISKIP .EQ. 1) THEN
                 CC_TOP_R(1:NSKIP) = CCSKIPA(1:NSKIP)   ! TOP CC's OTHER SKIPS 
              ENDIF

c             write(6,98)iskip,ccnow,cctop, ccone,ccold,
c     &                  irot,isx,isy,ccskipa(1:4)
c98           format(i5,f8.1,' >> ',f8.1,2x,f8.1,' >> ',f8.1,
c     &              3i5,2x,4f9.1) 
 
           ENDIF
        ENDDO                          ! END OF: DO ISKIP =1..
       
        END
!     &     iskip, tmp, cc_top_r(iskip),irotsav,naskip(1:4),ccskipa(1:4)
!99            format(i5,f10.1,' --> ',f10.1, i5,':',4i5,':',4f9.1) 

#ifdef NEVER
 
 
#endif

C*************************** RINGS  ***********************************
C************************ APSH_SAM_SKIPS ******************************


        SUBROUTINE APSH_SAM_SKIPS(NSKIP)

C       PURPOSE: CHECKS CURRENT RING SKIPS TO RECORD SUCCESS AT 
C                FINDING HIGHEST CC'S & SUM THE CC'S THAT WERE FOUND.
C                CALLED AFTER EACH EXP. IMAGE

        USE APSH_SAM_INFO

        IMPLICIT NONE
        INTEGER, INTENT(IN) :: NSKIP

        INTEGER             :: ISKIP, IAT,IRT,IXT,IYT,I

        DO ISKIP = 1,NSKIP         ! LOOP OVER SKIPS

           IRT = IR_SAM_R(ISKIP)   ! REFERENCE #
           IXT = IX_SAM_R(ISKIP)   ! X SHIFT
           IYT = IY_SAM_R(ISKIP)   ! Y SHIFT
           IAT = IA_SAM_R(ISKIP)   ! ROTATION #

c           IF (ISKIP .EQ. 1) THEN
c              write(6,90)iskip,irt,iat,ixt,iyt,cm_sam_r(iskip),
c     &                   (cc_top_r(i),i=2,5)
c           ELSE
c              write(6,90)iskip,irt,iat,ixt,iyt,cm_sam_r(iskip)
c           ENDIF
90         FORMAT(' Skip:',i2,'  Ref:',i5,
     &            '  Rot:',i5,' (',i3,',',i3,'):',10(f8.2,2x))

           IF (IAT .EQ. IA_SAM_R(1)  .AND.
     &         IRT .EQ. IR_SAM_R(1)  .AND.
     &         IXT .EQ. IX_SAM_R(1)  .AND.
     &         IYT .EQ. IY_SAM_R(1) ) THEN

C             IS SAME REF, ROTATION, & SHIFT AS THE BEST MATCH!
              NN_GUD_R(ISKIP) = NN_GUD_R(ISKIP)+1 !  # OF BEST SKIPS

           ENDIF 

C          UPDATE CUMULATIVE SUM OF NO-SKIP CC'S                           
           SU_GUD_R(ISKIP) = SU_GUD_R(ISKIP) + CM_SAM_R(ISKIP) 

        ENDDO                         ! END OF: DO ISKIP =1..

        NN_SAM_R = NN_SAM_R + 1       ! # OF CC'S
        
        END

C*********************** APSH_SKIP_REPORT ******************************

        SUBROUTINE APSH_SKIP_REPORT(NSKIP)

C       PURPOSE: REPORTS SAMPLING COUNTERS FOR RING SKIPS

        USE APSH_SAM_INFO

        IMPLICIT NONE

        INCLUDE 'CMLIMIT.INC'
        INCLUDE 'CMBLOCK.INC'

        INTEGER,INTENT(IN) :: NSKIP

        INTEGER            :: ISKIP,NTOT,NGUD,ITIME
        REAL               :: PERGUD,PERBEST
        REAL               :: SUMCC

        WRITE(6,*)    ' '
        WRITE(6,*)    '    SKIP   #BEST   %BEST    %BEST RELATIVE'
        WRITE(6,*)    '     AMT   FOUND   FOUND      CC     TIME'
        WRITE(NOUT,*) ' '
        WRITE(NOUT,*) '    SKIP   #BEST   %BEST    %BEST RELATIVE'
        WRITE(NOUT,*) '     AMT   FOUND   FOUND      CC     TIME'

        NTOT   = NN_SAM_R

        DO ISKIP = 1,NSKIP     ! LOOP OVER ALL SKIPS

           SUMCC  = SU_GUD_R(ISKIP)

C          NUMBER OF TOP CC'S FOUND
           NGUD   = NN_GUD_R(ISKIP)
           PERGUD = 0.0
           IF (NTOT .GT. 0) THEN
              PERGUD = (FLOAT(NGUD) / FLOAT(NTOT)) * 100.0
           ENDIF

C          PERCENT OF THE TOP CC 
           PERBEST = 0.0
           IF (NTOT .GT. 0) THEN
              PERBEST = SU_GUD_R(ISKIP) / SU_GUD_R(1) * 100.0 
           ENDIF

C          RELATIVE TIME FOR RUNNING
           ITIME = ANINT((FLOAT(NSKIP) / FLOAT(ISKIP)) * 100.0)    
                 
           WRITE(6,90)   ISKIP,NGUD,PERGUD,PERBEST,ITIME
           WRITE(NOUT,90)ISKIP,NGUD,PERGUD,PERBEST,ITIME
90         FORMAT('  ',I6,3X, I5,3X, F5.1,'%',3X,F5.1,'%', 3X,I3)

        ENDDO          ! END OF: DO ISKIP = 2,NSKIP

        END 

C*************************** SHIFTS  **********************************
C*************************** APSH_SAM_SH ******************************

        SUBROUTINE APSH_SAM_SH(CC_NOW,ISHRANGEX,ISHRANGEY)

C       PURPOSE: CHECKS SIZE & SHIFT STEPS TO SEE WHAT HIGHER CC'S 
C                WERE MISSED, RUNS FOR EACH REF IMAGE vs EXP IMAGE.
C                CC_NOW CONTAINS THE CURRENT CC's FOR ALL SHIFTS OF
C                THIS PAIR OF IMAGES
    
        USE APSH_SAM_INFO

        IMPLICIT NONE
	REAL, INTENT(IN)                :: CC_NOW(-ISHRANGEX:ISHRANGEX,
     &                                            -ISHRANGEY:ISHRANGEY)
        INTEGER, INTENT(IN)             :: ISHRANGEX,ISHRANGEY

        REAL                            :: QST,QHI   
        INTEGER                         :: ISZ,ISTEP,IDX,J,I,NSTEPMAX
        INTEGER                         :: IHI,JHI,itmax
        INTEGER                         :: MAXL_ARRAY(2)

        QST = CC_NOW(0,0)

        IF (QST > QSTEP(0,1)) THEN
C          CENTRAL LOCATION IS MORE THAN CURRENT HIGH CC FOR STEP: 1
           QSTEP(0,1) = QST                ! HIGHEST CC 
           IQX(0,1)   = 0                  ! X LOCATION OF HIGHEST
           IQY(0,1)   = 0                  ! Y LOCATION OF HIGHEST
        ENDIF

        DO ISZ = 1,ISHRANGEX               ! LOOP TILL MAX SIZE
          NSTEPMAX = MIN(ISZ,NSTEPZ)
          DO ISTEP = 1,NSTEPMAX            ! LOOP OVER STEPS WITHIN SIZE

              IDX = MOD(ISZ,ISTEP)         ! STEPS THAT COVER THIS SIZE
              IF (IDX .NE. 0) CYCLE        ! NOT A VALID STEP

              DO J = -ISZ,ISZ,ISTEP        ! LOOP OVER SHIFTS IN Y
                 DO I = -ISZ,ISZ,ISTEP     ! LOOP OVER SHIFTS IN X

                    QST = CC_NOW(I,J)

                    IF (QST > QSTEP(ISZ,ISTEP)) THEN
C                      LOCATION IS MORE THAN CURRENT HIGH CC
                       QSTEP(ISZ,ISTEP) = QST  ! HIGHEST CC 
                       IQX(ISZ,ISTEP)   = I    ! X LOCATION OF HIGHEST
                       IQY(ISZ,ISTEP)   = J    ! Y LOCATION OF HIGHEST
                    ENDIF
                 ENDDO                     ! END OF : DO I = -ISZ
              ENDDO                        ! END OF : DO J = -ISZ
           ENDDO                           ! END OF : DO ISTEP = 1,NSTEPMAX
        ENDDO                              ! END OF : DO ISZ = 1,ISHRANGEX

C       FILL IN LOCATION OF BEST MATCH ARRAY
        MAXL_ARRAY = MAXLOC(CC_NOW)  ! RETURNS ARRAY OF LENGTH: 2 
        IHI        = MAXL_ARRAY(1) - ISHRANGEX - 1
        JHI        = MAXL_ARRAY(2) - ISHRANGEY - 1 
        !write(6,*) ' ihi,jhi:',ihi,jhi,cc_now(ihi,jhi)
        LOCBESTA(IHI,JHI) = LOCBESTA(IHI,JHI) + 1

        !write(6,*) ' qstep(2):',qstep(2,1:2),iqx(2,1:2),iqy(2,1:2)
        itmax = max(ishrangex,ishrangey)
        !call apsh_sam_report(itmax,ishrangex,ishrangey)
        !stop

        END

C************************** APSH_SAM_SIZE ******************************


        SUBROUTINE APSH_SAM_SIZE(CC_BEST,QMAX,ISX,ISY,
     &                           ISHRANGEX,ISHRANGEY)

C       PURPOSE: CHECKS SIZE & SHIFT STEPS TO SEE WHAT HIGHER CC'S 
C                WERE MISSED.  RUNS ONCE FOR EACH EXP IMAGE.
C                FINDS STATS FOR THIS EXP IMAGE VS ALL REF IMAGES.

        USE APSH_SAM_INFO

        IMPLICIT NONE

	REAL, INTENT(IN)           :: CC_BEST(-ISHRANGEX:ISHRANGEX,
     &                                        -ISHRANGEY:ISHRANGEY)
        REAL, INTENT(IN)           :: QMAX   
        INTEGER, INTENT(IN)        :: ISX,ISY
        INTEGER, INTENT(IN)        :: ISHRANGEX,ISHRANGEY

C       AUTOMATIC
        REAL                       :: QST   
        
        INTEGER                    :: ISZ,ISTEP,IDX,J,I
        INTEGER                    :: IHI_X,IHI_Y,NSTEPMAX

C       SPECIAL CHECK FOR A 1 ELEMENT SIZE
        QST           = CC_BEST(0,0)
        NN_SAM_Z(0,1) = NN_SAM_Z(0,1) + 1 ! # OF SHIFTS SAMPLED

        IF (QST >= QMAX) THEN
C          FOUND BEST  CC AT THE CENTER 
           NN_GUD_Z(0,1) = NN_GUD_Z(0,1) + 1  ! # OF BESTS
        ELSE
           CC_BAD_Z(0,1) = CC_BAD_Z(0,1) + QST / QMAX
        ENDIF

C       CHECK > 1 ELEMENT SIZES

        DO ISZ = 1,ISHRANGEX           ! LOOP TILL MAX SIZE
           NSTEPMAX = MIN(ISZ,NSTEPZ)

           DO ISTEP = 1,NSTEPMAX       ! LOOP OVER STEPS WITHIN SIZE

              IDX = MOD(ISZ,ISTEP)     ! WHiCH STEPS COVER THIS SIZE
              IF (IDX .NE. 0) CYCLE    ! NOT A VALID STEP

              QST   = QSTEP(ISZ,ISTEP) ! TOP CC FOR THIS SIZE & SHIFT
              IHI_X = IQX(ISZ,ISTEP)   ! X LOCATION FOR THIS TOP CC
              IHI_Y = IQY(ISZ,ISTEP)   ! Y LOCATION FOR THIS TOP CC

              NN_SAM_Z(ISZ,ISTEP) = NN_SAM_Z(ISZ,ISTEP) + 1 !   # OF  SAMPLES

              IF (ABS(IHI_X) .EQ. ISZ .OR.  ABS(IHI_Y) .EQ. ISZ) THEN
C                 ON BORDER. INCREMENT # OF BORDER PIXELS
                  NN_BORDR(ISZ,ISTEP)  = NN_BORDR(ISZ,ISTEP) + 1
              ENDIF 

#ifdef NEVER  
              if (isz.eq.4 .and. istep.eq.2) THEN
                 write(6,'(a,3i5,2x,2f8.1,2x,4i5)') 
     &                 '  :',isz,istep,nn_sam_z(isz,istep),qst,qmax,
     &                      isx,isy,  ihi_x,ihi_y
                 write(6,*) ' a:',abs(ihi_x - isx),'<=',istep
                 write(6,*) ' b:',abs(ihi_y - isy),'<=',istep
                 write(6,*) ' c:',ihi_x,'>', -ishrangex
                 write(6,*) ' d:',ihi_x,'<',  ishrangex
                 write(6,*) ' e:',ihi_y,'>', -ishrangey
                 write(6,*) ' f:',ihi_y,'<',  ishrangey
              endif 
#endif 
              IF (QST >= QMAX) THEN
C                LANDED DIRECTLY ON HIGHEST CC 

                 NN_GUD_Z(ISZ,ISTEP) = NN_GUD_Z(ISZ,ISTEP) + 1  ! # OF FINDS

              ELSEIF (ABS(IHI_X - ISX) <= ISTEP .AND.
     &                ABS(IHI_Y - ISY) <= ISTEP .AND.
     &                   (IHI_X > -ISZ )  .AND.
     &                   (IHI_X <  ISZ  ) .AND.
     &                   (IHI_Y > -ISZ)   .AND.
     &                   (IHI_Y <  ISZ )) THEN
C                WITHIN ISTEP OF HIGHEST CC, WILL BE FOUND IN CALLER
                 !write(6,91)isz,istep,isx,isy,ihi_x,ihi_y
 91              format(' For size:',i2,' Step:',i2, 
     &                  '   Will find: (',i2,',',i2,
     &                  ')  From: (',i2,',',i2,')')
       
                 NN_GUD_Z(ISZ,ISTEP) = NN_GUD_Z(ISZ,ISTEP) + 1  ! # OF FINDS

              ELSE
C                FOUND A POORER CC
                 CC_BAD_Z(ISZ,ISTEP) = CC_BAD_Z(ISZ,ISTEP) + QST / QMAX
               ENDIF
           ENDDO                          ! END OF : DO ISTEP = 1,NSKIPS
        ENDDO                             ! END OF : DO ISZ = 1,ISHRANGEX

C       FILL IN ARRAY LOCATION OF BEST MATCH 
        IHI_X                = IQX(ISHRANGEX,1)   ! X LOC. FOR TOP CC
        IHI_Y                = IQY(ISHRANGEX,1)   ! Y LOC. FOR TOP CC
        LOCBEST(IHI_X,IHI_Y) = LOCBEST(IHI_X,IHI_Y) + 1

        END

C************************* APSH_SAM_INIT ******************************

        SUBROUTINE APSH_SAM_INIT()

        USE APSH_SAM_INFO

        IMPLICIT NONE

        CC_BAD_Z = 0.0   ! TOTAL CC FOR EACH SIZE         (ARRAY)
        NN_GUD_Z = 0     ! # OF BEST VALUES FOR EACH SKIP (ARRAY)
        NN_SAM_Z = 0     ! # OF SHIFTS IN SAMPLE          (ARRAY)
        NN_BORDR = 0     ! # OF BORDER PIXELS             (ARRAY)

        NN_SAM_R = 0     ! # OF SKIP SAMPLES (SHOULD = NUMEXP)
        LOCBESTA = 0     ! # OF BEST AT THIS LOCATION (ALL PAIRS)
        LOCBEST  = 0     ! # OF BEST AT THIS LOCATION (BEST PAIRS)
        END


C*********************** APSH_SAM_REPORT ******************************

        SUBROUTINE APSH_SAM_REPORT(ISIZES,ISHRANGEX,ISHRANGEY)

C       PURPOSE: REPORTS SAMPLING COUNTERS

        USE APSH_SAM_INFO

        IMPLICIT NONE

        INCLUDE 'CMLIMIT.INC'
        INCLUDE 'CMBLOCK.INC'

        INTEGER            :: ISIZES,ISHRANGEX,ISHRANGEY

        INTEGER            :: NSTEPMAX
        INTEGER            :: ISIZ,ISTEP,IT,ITIME,NSIZ,I,NBAD,NTOT,NGUD
        INTEGER            :: NBORD,J,ISHS,NLETS
        REAL               :: PERGUD,AVGCC,PERBORD

C                                   123456789012
        CHARACTER (LEN=12) :: FMT = '(041(I3,1X))'

        WRITE(6,*) ' '
        WRITE(6,*) '  ' //
     &       'SHIFT  STEP  #BEST  %BEST         %CC      %ON    TIME'
        WRITE(6,*) '  ' //
     &       'RANGE  AMT   FOUND  FOUND         MAX     BORDER'
        WRITE(NOUT,*)    ' '
        WRITE(NOUT,*) '  ' //
     &       'SHIFT  STEP  #BEST  %BEST         %CC      %ON    TIME'
        WRITE(NOUT,*) '  ' //
     &       'RANGE  AMT   FOUND  FOUND         MAX     BORDER'

        DO ISIZ = 0,ISIZES     ! LOOP OVER ALL SIZES

           IF (ISIZ .EQ. 0) THEN
              ITIME  = 1
              ISTEP  = 0
              NTOT   = NN_SAM_Z(0,1)
              NGUD   = NN_GUD_Z(0,1)

              NBAD   = NN_SAM_Z(0,1) - NGUD
              PERGUD = FLOAT(NGUD) / FLOAT(NBAD) * 100.0
              AVGCC  = 0.0
              IF (NBAD > 0) AVGCC  = CC_BAD_Z(0,1) / NBAD * 100.0
              PERBORD = 100.0

              WRITE(6,90)ISIZ,ISTEP,NGUD,PERGUD,AVGCC,PERBORD,ITIME
              WRITE(6,*)' '
              WRITE(NOUT,90)ISIZ,ISTEP,NGUD,PERGUD,AVGCC,PERBORD,ITIME
              WRITE(NOUT,*)' '

              CYCLE
           ENDIF

           NSTEPMAX = MIN(ISIZ,NSTEPZ)
           DO ISTEP = 1,NSTEPMAX           ! LOOP OVER STEPS WITHIN SIZE

              IT = MOD(ISIZ,ISTEP) 
              IF (IT > 0) CYCLE   ! NOT A VALID SKIP
 
              NTOT = NN_SAM_Z(ISIZ,ISTEP)
              NGUD = NN_GUD_Z(ISIZ,ISTEP)
              NBAD = NTOT - NGUD

              PERGUD =  0.0
              IF (NTOT .GT. 0) THEN
                  PERGUD = (FLOAT(NGUD) / FLOAT(NTOT)) * 100.0
              ENDIF

              AVGCC =  100.0
              IF (NBAD .GT. 0) THEN
                 AVGCC = CC_BAD_Z(ISIZ,ISTEP) / FLOAT(NBAD) * 100.0
              ENDIF

              PERBORD =  0.0
              NBORD   = NN_BORDR(ISIZ,ISTEP)
              IF (NTOT .GT. 0) THEN
                 PERBORD = (FLOAT(NBORD) / FLOAT(NTOT)) * 100.0
              ENDIF

              ITIME = (2*(ISIZ/ISTEP) + 1) **2 ! + (ISTEP*2+1) **2
              NSIZ  =  2*ISIZ + 1              ! UNUSED
                 
              WRITE(6,90)ISIZ,ISTEP,NGUD,PERGUD,AVGCC,PERBORD,ITIME
              WRITE(NOUT,90)ISIZ,ISTEP,NGUD,PERGUD,AVGCC,PERBORD,ITIME
90            FORMAT(' ',I6,I5,I7,3X,F5.1,'%',2X,F10.1,'%',3X,
     &               ' ',F5.1,'%',2X,I4)

           ENDDO       ! END OF: DO ISTEP = 1,ISIZ
           WRITE(6,*) ' '
           WRITE(NOUT,*) ' '
        ENDDO          ! END OF: DO ISIZ = 1,ISIZES

        ISHS = 2 * ISHRANGEX + 1
        CALL INTTOCHAR(ISHS,FMT(3:5),NLETS,3)

#ifdef NEVER
        WRITE(6,*)' '
        WRITE(6,*)  "' LOCATION OF MAX CC'S, FOR ALL REFS"
        WRITE(6,*)' '
        WRITE(NOUT,*)' '
        WRITE(NOUT,*)" LOCATION OF MAX CC'S, FOR ALL REFS"
        WRITE(NOUT,*)' '

        DO J=-ISHRANGEY,ISHRANGEY   ! NEED RUNTIME FORMATTING
           WRITE(6,FMT)    (LOCBESTA(I,J),I=-ISHRANGEX,ISHRANGEX)
           WRITE(NOUT,FMT) (LOCBESTA(I,J),I=-ISHRANGEX,ISHRANGEX)
        ENDDO 
#endif

        WRITE(6,*)' '
        WRITE(6,*)   " LOCATION OF MAX CC'S, FOR BEST REFS"
        WRITE(6,*)' '
        WRITE(NOUT,*)' '
        WRITE(NOUT,*)" LOCATION OF MAX CC'S, FOR BEST REFS"
        WRITE(NOUT,*)' '


        DO J=-ISHRANGEY,ISHRANGEY   ! NEED RUNTIME FORMATTING
           WRITE(6,FMT)    (LOCBEST(I,J),I=-ISHRANGEX,ISHRANGEX)
           WRITE(NOUT,FMT) (LOCBEST(I,J),I=-ISHRANGEX,ISHRANGEX)
        ENDDO 
        WRITE(6,*)    ' '
        WRITE(NOUT,*) ' '

        END



C++*********************************************************************
C
C  CROSRNG_2C_TOOL.F   
C              TRAP FOR COMPILER ERROR ON ALTIX   FEB 2005 ARDEAN LEITH
C              REWRITE USING CROSRNG_COM          FEB 2008 ARDEAN LEITH
C              REWRITE USING FFTW3 RINGS          FEB 2008 ARDEAN LEITH
C              REMOVED TT                         JUN 2010 ARDEAN LEITH
C              CONSOLIDATES CROSRNG_E & _M        JUN 2010 ARDEAN LEITH
C
C **********************************************************************
C
C CROSRNG_2C_TOOL(CIRCR,CIRCE,LCIRC, NRING,NRAYS,NUMR,
C           USE_OMP,FFTW3PLAN,   USE_UN,USE_MIR,                         
C           ISMIRRORED,QMAX,POS_MAX)
C
C PURPOSE: CROSS CORRELATION OF RADIAL RINGS FOR USE IN ROTATIONAL
C          ALIGNMENT.  CHECKS BOTH STRAIGHT & MIRRORED POSITIONS
C          USES NUMR TABLE FOR MAPPING INTO Q ARRAY 
C          USES SIMPLIFIED LOGIC FOR BOUNDARY VALUES, FLOATING PT. ARITH.
C
C PARAMETERS:
C    CIRCR      - FT OF RINGS MULTIPLIED BY WEIGHTS           (SENT)
C    CIRCE      - FT OF RINGS MULTIPLIED BY WEIGHTS           (SENT)
C    LCIRC      - SIZE OF CIRCS ARRAYS                        (SENT)
C    NRING      - NUMBER OF RINGS                             (SENT)
C    NRAYS     - LONGEST RING                                (SENT)
C    NUMR       - RING LOCATION POINTERS                      (SENT)
C    USE_OMP    - USE || OMP                                  (SENT)
C    FFTW3PLAN  - PLAN FOR REVERSE FFT OF RING                (SENT)
C    USE_UN     - USE UN MIRRORED                             (SENT)
C    USE_MIR    - USE MIRRORED                                (SENT)
C    ISMIRRORED -                                             (RETURNED)
C    QMAX       - CC MAX                                      (RETURNED)
C    POS_MAX    - POSITION OF CC MAX                          (RETURNED)
C
C  NOTES: AUG 04 ATTEMPTED SPEEDUP USING 
C       PREMULTIPLY  ARRAYS ie( CIRC12 = CIRC1 * CIRC2) much slower
C       VARIOUS  OTHER ATTEMPTS  FAILED TO YIELD IMPROVEMENT
C       THIS IS A VERY IMPORTANT COMPUTE DEMAND IN ALIGNMENT & REFINE.
C       OPTIONAL LIMIT ON ANGULAR SEARCH SHOULD BE ADDED.
C       COMPLEX ARRAY ARE USUALLY SLOWER in 2010
C
C       THE UNEVEN POLAR SAMPLING IN THE FOURIER DOMAIN, IS DUE TO THE 
C       INNER RINGS HAVING HAD DENSER SAMPLING, THE VALUES AT THE 
C       HIGHER FREQUENCIES WOULD HAVE BEEN ZERO ANYWAYS, SO THERE IS 
C       NO NEED TO "INCLUDE" THEM. 

C23456789012345678901234567890123456789012345678901234567890123456789012
C--*********************************************************************

cpgi$g opt=3

C       USES COMPLEX VARIABLES INTERNALLY

        SUBROUTINE CROSRNG_2C_TOOL(CIRCR,CIRCE,LCIRCD2, 
     &                        NRING,NRAYS,NUMR, 
     &                        USE_OMP,FFTW3PLAN,
     &                        USE_UN,USE_MIR,                         
     &                        ISMIRRORED,QMAX,POS_MAX,
     &                        NASKIP,CCSKIP,CCSKIPA,NSKIP,
     &                        IR,IT,JT)
        IMPLICIT NONE

        COMPLEX,       INTENT(IN)  :: CIRCE(LCIRCD2), CIRCR(LCIRCD2)
        INTEGER,       INTENT(IN)  :: LCIRCD2
        INTEGER,       INTENT(IN)  :: NUMR(3,NRING)
        INTEGER,       INTENT(IN)  :: NRING,NRAYS,NSKIP
        INTEGER,       INTENT(OUT) :: NASKIP(NSKIP)
        REAL,          INTENT(OUT) :: CCSKIP(NSKIP)
        REAL,          INTENT(OUT) :: CCSKIPA(NSKIP)
        LOGICAL,       INTENT(IN)  :: USE_OMP
        INTEGER*8,     INTENT(IN)  :: FFTW3PLAN  ! STRUCTURE POINTER
        LOGICAL,       INTENT(IN)  :: USE_UN,USE_MIR
        LOGICAL,       INTENT(OUT) :: ISMIRRORED
        REAL,          INTENT(OUT) :: QMAX
        REAL,          INTENT(OUT) :: POS_MAX
        INTEGER,       INTENT(IN)  :: IR,IT,JT

C       AUTOMATIC ARRAYS
        COMPLEX                    :: QU(NRAYS/2+1),QM(NRAYS/2+1)

        REAL                       :: QMAXU,QMAXM
        REAL                       :: POS_MAXU,POS_MAXM
        INTEGER                    :: ISKIP,I,IGOM1,NVAL,J,JC
        INTEGER                    :: MAXLU,MAXLM,MAXT

        REAL                       :: CCSET  ! FUNCTION


        DO ISKIP = NSKIP,1,-1      ! LOOP OVER ALL RING SKIP AMOUNTS

           IF (USE_UN) THEN
C             ZERO WHOLE QU ARRAY, STRAIGHT  = CIRCR * CONJG(CIRCE)
	      QU = 0.0D0
           ENDIF

           IF (USE_MIR) THEN
C             ZERO QM ARRAY,  QM - MIRRORED  = CONJG(CIRCR) * CONJG(CIRCE)
	      QM = 0.0D0
           ENDIF

           DO I=1,NRING,ISKIP   ! LOOP OVER RINGS WITH SKIPPING

	      IGOM1 = NUMR(2,I) / 2  
              NVAL  = NUMR(3,I) / 2     

	      IF (USE_UN .AND. USE_MIR)  THEN
	         DO J=1,NVAL
	            JC    = J + IGOM1

C                   NON MIRRORED RING SET 
                    QU(J) = QU(J) +       CIRCR(JC)  * CONJG(CIRCE(JC))

C                   MIRRORED RING SET 
                    QM(J) = QM(J) + CONJG(CIRCR(JC)) * CONJG(CIRCE(JC))
 	         ENDDO

              ELSEIF (USE_UN) THEN
	         DO J=1,NVAL
	            JC    = J + IGOM1
                    QU(J) = QU(J) +        CIRCR(JC) * CONJG(CIRCE(JC))
	         ENDDO

              ELSEIF (USE_MIR) THEN
	         DO J=1,NVAL
	            JC    = J + IGOM1
                    QM(J) = QM(J) + CONJG(CIRCR(JC)) * CONJG(CIRCE(JC))
	         ENDDO
              ENDIF
	   ENDDO    ! END OF: DO I=1,NRING

           QMAXU = 0.0
           QMAXM = 0.0

           IF (USE_UN) THEN
C             FOR UN-MIRRORED
              CALL CROSRNG_COM_R(QU,NRAYS,FFTW3PLAN,
     &                           QMAXU,POS_MAXU,MAXLU)
           ENDIF

           IF (USE_MIR) THEN
C             FOR MIRRORED
              CALL CROSRNG_COM_R(QM,NRAYS,FFTW3PLAN,
     &                           QMAXM,POS_MAXM,MAXLM)
           ENDIF

           IF (QMAXM .GT. QMAXU) THEN
              ISMIRRORED  = .TRUE.
              QMAX        = QMAXM
              POS_MAX     = POS_MAXM
              MAXT        = MAXLM
           ELSE
              ISMIRRORED  = .FALSE.
              QMAX        = QMAXU
              POS_MAX     = POS_MAXU
              MAXT        = MAXLU
           ENDIF

           NASKIP(ISKIP)  = MAXT      ! LOCATION OF MAX CC
           CCSKIP(ISKIP)  = QMAX      ! VALUE OF MAX CC FOR THIS SKIP

        ENDDO                         ! END OF: DO ISKIP 

C       SAVE THE CORRESPONDING MAX NO-SKIP CC
        DO ISKIP = 1,NSKIP
           IF (ISMIRRORED) THEN
              CCSKIPA(ISKIP) = CCSET(QM,NASKIP(ISKIP),NRAYS) 
           ELSE
              CCSKIPA(ISKIP) = CCSET(QU,NASKIP(ISKIP),NRAYS) 
           ENDIF
        ENDDO

C       SAVE STATS IF THIS IS BEST CC SO FAR 
        IF (ISMIRRORED) THEN
           CALL APSH_SAM_SKIP(CCSKIP,NASKIP,CCSKIPA,NSKIP,
     &                     IR,IT,JT, QM,NRAYS)
        ELSE
           CALL APSH_SAM_SKIP(CCSKIP,NASKIP,CCSKIPA,NSKIP,
     &                     IR,IT,JT, QU,NRAYS)
        ENDIF

        END

C************************** CCSET ************************************

C       KLUDGE TO USE REAL VARIABLE ARRAY

        REAL FUNCTION CCSET(QQ,NTSKIP,NRAYS)
        IMPLICIT NONE

        REAL,     INTENT(IN)  :: QQ(*)
        INTEGER,  INTENT(IN)  :: NTSKIP,NRAYS  

C       SAVE THE EQUIVALENT TOP NO-SKIP CC
        CCSET  = 1.00048 *  QQ(NTSKIP) / (NRAYS) ! HACK TO = PRE FFTW3

        END




