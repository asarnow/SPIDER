

C++*********************************************************************
C
C  ORMAP.F   FROM: APSH_SS                      DEC 2012 ARDEAN LEITH
C
C **********************************************************************
C=*                                                                    *
C=* This file is part of:   SPIDER - Modular Image Processing System.  *
C=* SPIDER System Authors:  Joachim Frank & ArDean Leith               *
C=* Copyright 1985-201e  Health Research Inc.,                         *
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
C ORMAP()
C
C PURPOSE: FIND ROTATION TO ALIGN A REFERENCE IMAGES WITH A
C          SAMPLE IMAGES. DOES A CROSS CORRELATION OF RADIAL RINGS 
C          USES NUMR TABLE FOR MAPPING INTO Q ARRAY 
C          CREATES POLAR MAP. 
C
C VARIAGLES:
C    CIRCR      - FT OF RINGS MULTIPLIED BY WEIGHTS            
C    CIRCE      - FT OF RINGS MULTIPLIED BY WEIGHTS            
C    LCIRC      - SIZE OF CIRCS ARRAYS                         
C    NRING      - NUMBER OF RINGS                              
C    MAXRAYS    - LONGEST RING                                
C    NUMR       - RING LOCATION POINTERS                      
C    FFTW3PLAN  - PLAN FOR REVERSE FFT OF RING                 
C    QMAX       - CC MAX                                        
C    POS_MAX    - POSITION OF CC MAX                           
C
C    THE UNEVEN POLAR SAMPLING IN THE FOURIER DOMAIN, IS DUE TO THE 
C    INNER RINGS HAVING HAD DENSER SAMPLING, THE VALUES AT THE 
C    HIGHER FREQUENCIES WOULD HAVE BEEN ZERO ANYWAYS, SO THERE IS 
C    NO NEED TO "INCLUDE" THEM. 
C
C  OPERATIONS:  'OR MAP'
C
C23456789012345678901234567890123456789012345678901234567890123456789012
C--*********************************************************************

cpgi$g opt=3
       SUBROUTINE ORMAP()

        IMPLICIT NONE

        INCLUDE 'SETNUMRINGS.INC'

	INCLUDE 'CMBLOCK.INC'
        INCLUDE 'CMLIMIT.INC'

	INTEGER               :: NX,NY,NZ,MR,NR,ISKIP,NOT_USED
        INTEGER               :: UNUSED,MAXIM
	INTEGER               :: NRING,LCIRC
  
        REAL                  :: NXR,NYR,NZR
        INTEGER               :: IRTFLG,NDUM,MWANT,MAXRING,I
        INTEGER               :: MAXRAYS,NPLANS,NRAD,NE
        REAL                  :: CNR2,CNS2
        CHARACTER(LEN=MAXNAM) :: FILREF,FILEXP

C       ALLOCATED ARRAYS
        INTEGER*8,ALLOCATABLE :: FFTW_PLANS(:)
	REAL,     ALLOCATABLE :: CIRCEXP(:), CIRCREF(:)
	REAL,     ALLOCATABLE :: XBUF(:,:)
	INTEGER,  ALLOCATABLE :: NUMR(:,:)
        REAL,     ALLOCATABLE :: WRE(:),WRR(:)
 
	CHARACTER (LEN=1)     :: MODE = 'F'   ! FULL CIRCLE

        LOGICAL, PARAMETER    :: MPIBCAST   = .FALSE.
        LOGICAL, PARAMETER    :: USE_OMP    = .FALSE.
        LOGICAL, PARAMETER    :: WANT_STATS = .FALSE.

        INTEGER, PARAMETER    :: IRAYSKIP = 1   ! RAY SKIP
        INTEGER, PARAMETER    :: LUNREF   = 20
        INTEGER, PARAMETER    :: LUNEXP   = 21
        INTEGER, PARAMETER    :: LUNRING  = 70  ! UNUSED
        INTEGER, PARAMETER    :: LUNPOL   = 22
        INTEGER, PARAMETER    :: LUNGP    = 71
        INTEGER, PARAMETER    :: LUNGPD   = 72


C       OPEN EXP. IMAGE FILE ---------------------------------
        MAXIM    = 0  ! NOT A STACK OP
        CALL OPFILEC(0,.TRUE.,FILEXP,LUNEXP,'O',
     &               IFORM,NX,NY,NZ,
     &               MAXIM,'EXPERIMENTAL IMAGE~',.FALSE.,IRTFLG)
        IF (IRTFLG .NE. 0) GOTO 9999

        IF (NX .NE. NY .OR. NZ > 1) THEN
           CALL  ERRT(101,'ONLY WORKS ON SQUARE IMAGES',MWANT)
           GOTO 9999
        ENDIF

C       OPEN REF. IMAGE FILE -------------------------------------
        MAXIM    = 0  ! NOT A STACK OP
        CALL OPFILEC(0,.TRUE.,FILREF,LUNREF,'O',
     &               IFORM,NXR,NYR,NZR,
     &               MAXIM,'REFERENCE IMAGE~',.FALSE.,IRTFLG)
        IF (IRTFLG .NE. 0) GOTO 9999

        CALL SIZCHK(UNUSED, NX,NY,NZ,0,  NXR,NYR,NZR,0, IRTFLG)
        IF (IRTFLG .NE. 0) GOTO 9999

        CNR2     = NY/2+1     ! IMAGE CENTER
        CNS2     = NX/2+1

C       DETERMINE RING SPECIFICATIONS ----------------------------
        MR    = 5
        NR    = (NX / 2) - 4
	ISKIP = 1
        NRAD  = MIN(NX/2-1, NY/2-1) -1

        CALL RDPRI3S(MR,NR,ISKIP,NOT_USED,
     &               'FIRST & LAST RING',IRTFLG)
        IF (IRTFLG .NE. 0)  GOTO 9999
 
	IF (MR <= 0) THEN
	   CALL ERRT(101,'FIRST RING MUST BE > 0',NE)
	   GOTO 9999

	ELSEIF (NR >= NRAD)  THEN 
	   CALL ERRT(102,'LAST RING MUST BE < ',NRAD)
	   GOTO 9999
        ENDIF

C       CREATES NUMR ARRAY HOLDING THE SPECS FOR  RADIAL RINGS
        CALL SETNUMRINGS(MR,NR,ISKIP,MODE, IRAYSKIP,
     &                   NUMR,NRING,LCIRC,
     &                   IRTFLG)
        IF (IRTFLG .NE. 0)  GOTO 9999


        NPLANS  = 20 + 2         
        MAXRING = NUMR(1,NRING)
        MAXRAYS = NUMR(3,NRING) -2  ! ACTUAL LENGTH OF LONGEST RING

        ALLOCATE(FFTW_PLANS(NPLANS),
     &           CIRCREF(LCIRC),
     &           CIRCEXP(LCIRC),
     &           XBUF(NX,NY), 
     &           WRR(MAXRING+1), 
     &           WRE(MAXRING+1), 
     &           STAT=IRTFLG)
	IF (IRTFLG .NE. 0) THEN
           MWANT = NPLANS + 2*LCIRC + NX*NY + (MAXRING+1)*2 
           CALL  ERRT(46,'ORMAP; CIRCEXP,...',MWANT)
           GOTO 9999
        ENDIF 

C       INITIALIZE FFTW3 PLANS FOR USE WITHIN OMP || SECTIONS
        CALL APRINGS_INIT_PLANS(NUMR,NRING,
     &                          FFTW_PLANS,NPLANS,NX,NY,IRTFLG)

C       LOAD REF. IMAGE DATA ------------------------------
        CALL REDVOL(LUNREF,NX,NY,1,1,XBUF,IRTFLG)
        IF (IRTFLG .NE. 0) GOTO 9999

C       PUT REF. IMAGE INTO REF. RINGS (CIRCREF) ARRAY 
C       INTERPOLATE TO POLAR COORDINATES, CREATE 
C       FOURIER OF: CIRCREF. 

        WRR(1) = -1.0    ! RETURN SUM SQ WEIGHTING FOR EACH RING
	CALL APRINGS_ONE_NEW(NX,NY, CNS2,CNR2, 
     &                       XBUF,USE_OMP,
     &                       MODE,NUMR,NRING,LCIRC,WRR,FFTW_PLANS,
     &                       CIRCREF,IRTFLG)

C       LOAD EXP. IMAGE DATA ----------------------------
        CALL REDVOL(LUNEXP,NX,NY,1,1,XBUF,IRTFLG)
        IF (IRTFLG .NE. 0) GOTO 9999

C       PUT EXP. IMAGE INTO EXP. RINGS (CIRCEXP) ARRAY 
C       INTERPOLATE TO POLAR COORDINATES, CREATE 
C       FOURIER OF: CIRCEXP.  NO WEIGHTING OF RINGS

        WRE(1) = -1.0    ! RETURN SUM SQ WEIGHTING FOR EACH RING
	CALL APRINGS_ONE_NEW(NX,NY, CNS2,CNR2, 
     &                       XBUF,USE_OMP,
     &                       MODE,NUMR,NRING,LCIRC,WRE,FFTW_PLANS,
     &                       CIRCEXP,IRTFLG)
        IF (IRTFLG .NE. 0) GOTO 9999
        !call chkring(1,.false., circref,lcirc, numr,nring, ndum,ndum)

        MAXRAYS = NUMR(3,NRING) -2  ! ACTUAL LENGTH OF LONGEST RING

        CALL ORMAP_R(CIRCREF, CIRCEXP, LCIRC, 
     &               NRING,MAXRING,MAXRAYS,NUMR, 
     &               MODE,FFTW_PLANS(1), WRE,WRR, 
     &               LUNPOL,LUNGP,LUNGPD)	
       
9999    IF (ALLOCATED(CIRCEXP))    DEALLOCATE(CIRCEXP)
	IF (ALLOCATED(XBUF))       DEALLOCATE(XBUF)
	IF (ALLOCATED(FFTW_PLANS)) DEALLOCATE(FFTW_PLANS)
	IF (ALLOCATED(NUMR))       DEALLOCATE(NUMR)
	IF (ALLOCATED(WRE))        DEALLOCATE(WRE)
	IF (ALLOCATED(WRR))        DEALLOCATE(WRR)
	END





C       ----------------------- ORMAP_R ---------------------------

C PURPOSE: CROSS CORRELATION OF RADIAL RINGS FOR USE IN ROTATIONAL
C          ALIGNMENT. CREATES POLAR MAP. 
C          USES NUMR TABLE FOR MAPPING INTO Q ARRAY 

        SUBROUTINE ORMAP_R(CIRCR,CIRCE,LCIRC, 
     &                   NRING,MAXRING,MAXRAYS,NUMR, 
     &                   MODE,FFTW3PLAN,  WRE,WRR, 
     &                   LUNPOL,LUNGP,LUNGPD)

        IMPLICIT NONE

        INCLUDE 'CMBLOCK.INC' 
        INCLUDE 'CMLIMIT.INC' 

        INTEGER,  INTENT(IN)  :: LCIRC
        REAL,  INTENT(IN)     :: CIRCE(LCIRC), CIRCR(LCIRC)
        INTEGER,  INTENT(IN)  :: NRING,MAXRAYS
        INTEGER,  INTENT(IN)  :: NUMR(3,NRING)
	CHARACTER (LEN=1)     :: MODE
        INTEGER*8,INTENT(IN)  :: FFTW3PLAN     ! STRUCTURE POINTER
        REAL                  :: WRE(MAXRING+1),WRR(MAXRING+1)
        INTEGER               :: LUNPOL 
        INTEGER               :: LUNGP,LUNGPD

        REAL                  :: ang_n
        REAL                  :: VLIST(NRING+1)

        REAL,     ALLOCATABLE :: POLIMG(:,:),POLIMGT(:,:) 
        REAL,     ALLOCATABLE :: QU(:), QSUM(:)

        REAL                  :: QMAX
        REAL                  :: POS_MAX
        INTEGER               :: MAXL,IGOM1,MAXRING,IEND,NLETD
        REAL                  :: ANGMAX
        INTEGER               :: MAXL_ARRAY(1),IANG,IRING1,IRING2
        INTEGER               :: ITYPE,LNBLNKN,MAXIM,IRING,NUM
        INTEGER               :: I,NVAL,J,JC,IRTFLG,NLET,IWANT,NDUM
        INTEGER               :: NRINGP1,NT,MWANT,ICOMM,MYPID,MPIERR
        INTEGER               :: NRAYS,NRAYSP2,NRAYSMAX,K
        CHARACTER(LEN=MAXNAM) :: FILNAM,GPLOTFILE,GPLOTDATA
        CHARACTER(LEN=256)    :: PLOTVALS
        DOUBLE PRECISION      :: DSQRT_SUMSQ, DWEIGHT
        LOGICAL               :: EXISTS

        INTEGER, PARAMETER    :: INV          = -1 ! REVERSE TRANSFORM
        LOGICAL, PARAMETER    :: SPIDER_SIGN  = .FALSE.
        LOGICAL, PARAMETER    :: SPIDER_SCALE = .FALSE.
        INTEGER, PARAMETER    :: NXP          = 360
        INTEGER*8             :: IPLAN        = 0 ! STRUCTURE POINTER
        LOGICAL, PARAMETER    :: USE_UN       = .TRUE.
        LOGICAL, PARAMETER    :: USE_MIR      = .FALSE.
        LOGICAL               :: WANTGPLOT    = .FALSE.

        CHARACTER(LEN=1)      :: NQ2          = CHAR(34)   ! "
        CHARACTER(LEN=1)      :: NSL          = CHAR(92)   ! \

        CALL SET_MPI(ICOMM,MYPID,MPIERR)

        IRING1  = NUMR(1,1)      ! FIRST RING RADIUS
        MAXRING = NUMR(1,NRING)  ! MAX RING RADIUS
        NRINGP1 = NRING + 1
        NT      = MAXRAYS + 2

        ALLOCATE(POLIMG (NXP,MAXRING+1),
     &           POLIMGT(MAXRING+1,NXP),
     &           QU     (MAXRAYS + 2),
     &           QSUM   (MAXRAYS + 2), 
     &           STAT=IRTFLG)
        IF (IRTFLG .NE. 0) THEN
           MWANT = 2*NXP*(MAXRING+1) + 2*(MAXRAYS+2)                
           CALL ERRT(46,'ORMAP_2; POLIMG...',MWANT)
           RETURN
        ENDIF
        !write(6,*) 'nring, maxrays,nt:',nring, maxrays,nt
                  
C       ZERO WHOLE QU ARRAY
        QU      = 0.0
        QSUM    = 0.0

C       ZERO ALL OUTPUT ROWS, MAY NOT BE CONSECUTIVE
        POLIMG = 0.0

C       LOOP OVER ALL REQUESTED RINGS

        DO I=1,NRING

	   IRING    = NUMR(1,I)       ! RING
	   IGOM1    = NUMR(2,I) - 1   ! START LOC. WITHIN CIRCE/CIRCR
           NRAYSP2  = NUMR(3,I)       ! NUMBER OF RAYS FOR FFT   
           NRAYS    = NUMR(3,I) - 2   ! NUMBER OF RAYS = POINTS ON RING   

 	   DO J=1,NRAYSP2,2
              JC      = J + IGOM1

              QU(J)   =  DBLE(CIRCR(JC))   * CIRCE(JC)   +
     &                   DBLE(CIRCR(JC+1)) * CIRCE(JC+1)

              QU(J+1) = -DBLE(CIRCR(JC))   * CIRCE(JC+1) +
     &                   DBLE(CIRCR(JC+1)) * CIRCE(JC)

              QSUM(J)   = QSUM(J)   + QU(J)
              QSUM(J+1) = QSUM(J+1) + QU(J+1)
  	   ENDDO

           !write(6,*)' to fmrs, i,lcirc,nrays',i,lcirc,nrays,igom1
           !write(6,*)' to fmrs, igom1f,f',i,igom1f,nraysp2
           !write(6,*)' i,iring,nt,nrays',i,iring,nt,nrays

c          REVERSE FOURIER ON QU TO FIND  CORRELATION PEAK 
           CALL CROSRNG_COM_R(QU,NRAYS,IPLAN,  
     &                        QMAX,POS_MAX,MAXL)

           !write(6,2798)pos_max, maxl
2798       FORMAT('  Pos_max: ',F10.4,'    Maxl: ',i5)

C          CC NORMALIZATION 
           QMAX   = QMAX / SQRT(WRE(IRING)) / SQRT(WRR(IRING)) 

           ANGMAX = ANG_N(POS_MAX,MODE,NRAYS)
           IANG   = (ANGMAX + 0.5)

           IF (VERBOSE .AND. MYPID <= 0)  THEN
              WRITE(6,90)IRING,NRAYS, IANG,QMAX  !,WRE(IRING),WRR(IRING)
90            FORMAT('  Ring:',i3,'  Rays:',i6, 
     &               '    Max at angle:',i4, '    Max:',f5.2,2f8.2)
           ENDIF

C          CC NORMALIZATION FOR THIS LINE
           QU(1:NRAYS) = QU(1:NRAYS)      / 
     &                   SQRT(WRE(IRING)) / 
     &                   SQRT(WRR(IRING)) / NRAYS

C          DOWN/UP INTERPOLATION FROM: NRAYS  TO: NXP
           CALL LIN_INTERP(QU,NRAYS,POLIMG(1,IRING),NXP)

         !write(6,*) ' polimg,',iring,polimg(1,IRING)

           !MAXL_ARRAY = MAXLOC(POLIMG(:,IRING)) ! RETURNS ARRAY OF LENGTH: 1
           !QMAX       = POLIMG(MAXL_ARRAY(1),IRING)

	ENDDO
        !POLIMG(:,MAXRING+1:MAXRING+1) = 0.0

C       REVERSE FOURIER ON QSUM TO FIND OVERALL CORRELATION PEAK 
        CALL CROSRNG_COM_R(QSUM,MAXRAYS,FFTW3PLAN,
     &                     QMAX,POS_MAX,MAXL)

C       CC NORMALIZATION OVERALL
        QMAX   = QMAX / SQRT(WRE(MAXRING+1)) / SQRT(WRR(MAXRING+1))
 
        ANGMAX = ANG_N(POS_MAX,MODE,MAXRAYS)
        IANG   = (ANGMAX + 0.5)

        write(6,93) NRAYS, IANG,QMAX  !,WRE(MAXRING+1),WRR(MAXRING+1)
93      format('  Overall   Rays:',i6, 
     &         '    Max at angle:',i4, '    Max:',f5.2,2f8.2)

C       CC NORMALIZATION FOR OVERALL LINE
        QSUM(1:MAXRAYS) = QSUM(1:MAXRAYS) / 
     &                    SQRT(WRE(MAXRING+1)) /
     &                    SQRT(WRR(MAXRING+1)) / MAXRAYS
   
C       DOWN/UP INTERPOLATION FROM: MAXRAYS  TO: NXP
        CALL LIN_INTERP(QSUM,MAXRAYS, POLIMG(1,MAXRING+1),NXP)
        !call chkreal('qip',polimg(1,nringp1),360, 360,10,360)

C	OPEN IMAGE OUTPUT FILE --------------------------------
        MAXIM = 0
        ITYPE = 1
        CALL OPFILEC(0,.TRUE.,FILNAM,LUNPOL,'U',ITYPE,
     &               NXP,MAXRING+1,1,
     &               MAXIM,'POLAR OUTPUT',.FALSE.,IRTFLG)

        IF (IRTFLG .NE. 0) GOTO 9999

C       FILL OUTPUT VOLUME
         
        CALL WRTVOL(LUNPOL,NXP,MAXRING+1, 1,1,POLIMG,IRTFLG)
        CLOSE (LUNPOL)
        IF (IRTFLG .NE. 0) GOTO 9999

C       OPEN FORMATTED, SEQUENTIAL FILE FOR GNUPLOT ----------
        CALL OPAUXFILE(.TRUE.,GPLOTFILE,DATEXC,LUNGP,0,'N',
     &                 'GNUPLOT SCRIPT FILE',.TRUE.,IRTFLG)
        NLET      = lnblnkn(GPLOTFILE)
        !write(6,*) 'gplot:',nlet,irtflg,gplotfile

        WANTGPLOT = (NLET > 0) .AND. (IRTFLG == 0)  
        IF (IRTFLG > 0) GOTO 9999
 
        IF (WANTGPLOT) THEN
C          WRITE GNUPLOT FILE OUTPUT

C          OPEN FORMATTED, SEQUENTIAL FILE FOR GNUPLOT ----------
           GPLOTDATA = GPLOTFILE(1:NLET-4) // '_DATA'  

           CALL OPAUXFILE(.FALSE.,GPLOTDATA,DATEXC,LUNGPD,0,'N',
     &                    ' ',.TRUE.,IRTFLG)
           NLETD = lnblnkn(GPLOTDATA)

           WRITE(LUNGP,'(A)') 'set title " Correlation"'
           WRITE(LUNGP,'(A)') 'set xlabel "Angle"' 
           WRITE(LUNGP,'(A)') 'set ylabel "CC"' 
           WRITE(LUNGP,'(A, I6, A)') 
     &                        'set xrange [0:',NXP -1,']' 
           WRITE(LUNGP,'(A)') 'set yrange [-1.0:1.0]' 

C          GET RADII PLOT LIST
           NUM = NIMAX
           CALL RDPRAI(INUMBR,NIMAX,NUM,0,MAXRING+1,
     &                 'PLOT RADII','-',IRTFLG)

C          CHECK TO SEE IF RADII IN LIST ARE AVAILABLE 
           IWANT = 0

           DO I=1,NUM  ! LOOP OVER REQUESTED RINGS

              IRING = INUMBR(I)
              DO J=1,NRING
                 IF (NUMR(1,J) == IRING) THEN
C                   RADIUS PLOT AVAILABLE
                    IWANT         = IWANT + 1
                    INUMBR(IWANT) = IRING
                 ENDIF
              ENDDO
           ENDDO

           IF (IWANT <= 0) THEN
              CALL ERRT(101,'NO PLOTS AVAILABLE',NDUM)
              GOTO 9999
           ENDIF

           DO I=1,IWANT
              IRING = INUMBR(I)

              IF (I == 1) THEN
                 WRITE(LUNGP,94)NQ2,GPLOTDATA(1:NLETD),NQ2,
     &                          I+1,NQ2,IRING,NQ2,NSL 
94               FORMAT('plot ',A,A,A,' using 1:',I3,
     &                     ' title ',A,'Radius: ',I3,A,' , ',A)

              ELSEIF (I == IWANT) THEN
                 WRITE(LUNGP,97) NQ2,NQ2,
     &                             I+1,NQ2,IRING,NQ2 
97               FORMAT(' ',A,A,' using 1:',I3,
     &                  ' title ',A,'Radius: ',I3,A)

              ELSE
                 WRITE(LUNGP,95) NQ2,NQ2,
     &                          I+1,NQ2,IRING,NQ2,NSL 
95               FORMAT(' ',A,A,' using 1:',I3,
     &                     ' title ',A,'Radius: ',I3,A,' , ',A)
              ENDIF
           ENDDO


C          LIST VALUES FOR ALL REQUESTED RINGS 

           IEND = 0
           DO IANG=1, NXP   ! LOOP OVER 0...359
              DO I=1,IWANT  ! LOOP OVER REQUESTED RINGS
                 IRING    = INUMBR(I)
                 VLIST(I) = POLIMG(IANG,IRING)
              ENDDO

              WRITE(LUNGPD,96) IANG -1, (VLIST(I),I=1,IWANT)
96            FORMAT('  ',I4,' ',100F7.3)
           ENDDO
           CLOSE (LUNGPD)
        ENDIF

        CALL REG_SET_NSEL(1,2, ANGMAX,QMAX,0.0,0.0,0.0, IRTFLG)

        WRITE(NOUT,98)               GPLOTFILE(:NLET)
        IF (NOUT .NE. 6) WRITE(6,98) GPLOTFILE(:NLET)
98      FORMAT('  TO PLOT OUTPUT USE  gnuplot -persist ',A)
        WRITE(NOUT,*)' '
        
9999    IF (ALLOCATED(POLIMG))    DEALLOCATE(POLIMG)
        IF (ALLOCATED(POLIMGT))   DEALLOCATE(POLIMGT)
        IF (ALLOCATED(QU))        DEALLOCATE(QU)
        IF (ALLOCATED(QSUM))      DEALLOCATE(QSUM)

        END




C       *******************  LIN_INTERP ****************************

        SUBROUTINE LIN_INTERP(BUF1,NVAL, BUF2,NXP)

        IMPLICIT NONE

        INTEGER :: NVAL,NXP
        REAL    :: BUF1(NVAL)
        REAL    :: BUF2(NXP)

        INTEGER :: I,J1,J2
        INTEGER :: NVALM1,NXPM1
        REAL    :: COEF,CON,F2M1,F1,F2,FRAC,f1t
        INTEGER :: FLOC

        REAL     :: QMAX,rang
        integer  :: maxpos
        integer  :: maxl_array(1)
  
C       INTERPOLATION DOWN/UP FROM: MAXRAYS  TO: NXP

        NXPM1  = NXP  - 1
        NVALM1 = NVAL - 1
        F2M1   = F2   - 1.0
        COEF   = FLOAT(NVALM1) / FLOAT(NXPM1) 
        CON    = 1 - COEF 

        maxl_array = maxloc(buf1(1:nval)) ! returns array of length: 1
        maxpos     = maxl_array(1)
        qmax       = buf1(maxpos)
        rang       = float(maxpos-1) / float(nval) * 360.0
C dgm        rang       = float(maxpos-1.0) / float(nval) * 360.0
  
        !write(6,90)nval, maxpos, rang, qmax
90      format(  '  Rays:',i5, '  Max pos:',i5, 
     &           '  Ang:',f6.2,'  Max:',f10.2)
C dgm     &           '  Ang:',f6.2,'  Max:',f10.2,)

        DO I=1,NXP

           F2  = I

           !f1 = 1 + (F2 - 1) / (NXP - 1) * (NVAL - 1)
           !F1 = 1 + (F2 - 1) / NXPM1 * NVALM1 
           !F1 = 1 +  F2M1    / NXPM1 * NVALM1 
           !F1 = 1 +  F2M1    * COEF 
           !F1 =     (F2 - 1) * COEF + 1 
           !F1 =      F2 * COEF - COEF + 1 
           !F1 =      F2 * COEF + CON 
 
            F1   = F2 * COEF + CON 
            J1   = AINT(F1)
            J2   = J1 + 1
            FRAC = F1 - J1

            IF (J1 >= NVAL) THEN
               BUF2(I) = BUF1(NVAL)

            ELSEIF (J1 <= 0) THEN
               BUF2(I) = BUF1(1)

            ELSE  
               BUF2(I) = BUF1(J1) + FRAC * (BUF1(J2) - BUF1(J1))
            ENDIF
        ENDDO 

        END







