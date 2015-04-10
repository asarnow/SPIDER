C++*********************************************************************
C
C PJ3G.F        
C              EXTENSIVELY ALTERED                 MAR 07 ArDean Leith
C              FMRS_PLAN                           MAY  08 ARDEAN LEITH
C
C **********************************************************************
C=* FROM: SPIDER - MODULAR IMAGE PROCESSING SYSTEM.   AUTHOR: J.FRANK  *
C=* Copyright (C)2002-2008, P. A. Penczek                                   *
C=* University of Texas - Houston Medical School                       *
C=* Email:  pawel.a.penczek@uth.tmc.edu                                *
C=*                                                                    *
C=* This program is free software; you can redistribute it and/or      *
C=* modify it under the terms of the GNU General Public License as     *
C=* published by the Free Software Foundation; either version 2 of the *
C=* License, or (at your option) any later version.                    *
C=*                                                                    *
C=* This program is distributed in the hope that it will be useful,    *
C=* but WITHOUT ANY WARRANTY; without even the implied warranty of     *
C=* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU  *
C=* General Public License for more details.                           *
C=*                                                                    *
C=* You should have received a copy of the GNU General Public License  *
C=* along with this program; if not, write to the                      *
C=* Free Software Foundation, Inc.,                                    *
C=* 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.      *
C=*                                                                    *
C **********************************************************************
C
C PJ3G
C
C PURPOSE:  COMPUTES PROJECTIONS OF A 3D VOLUME ACCORDING TO 
C           THREE EULERIAN ANGLES. DOES A WHOLE PROJECTION SERIES. 
C           USES GRIDDING.  UNTESTED. NO MANUAL PAGE
C
C23456789012345678901234567890123456789012345678901234567890123456789012
C--*********************************************************************

        SUBROUTINE PJ3G

        INCLUDE 'CMBLOCK.INC'
        INCLUDE 'CMLIMIT.INC'

        CHARACTER (LEN=MAXNAM)                 :: FINPIC,FINPAT
        COMPLEX, DIMENSION(:,:,:), ALLOCATABLE :: X
        REAL, ALLOCATABLE, DIMENSION(:,:)      :: ANGBUF

         DATA  INVOL/92/,INDOCA/96/,INDOCS/95/

#ifdef USE_MPI
         include 'mpif.h'
         ICOMM = MPI_COMM_WORLD
         CALL MPI_COMM_RANK(ICOMM, MYPID, MPIERR)
#else
         MYPID = -1 
#endif

C        OPEN INPUT VOLUME
         MAXIM  = 0
         IRTFLG = 0
         CALL OPFILEC(0,.TRUE.,FINPIC,INVOL,'O',IFORM,NSAM,NROW,NSL,
     &               MAXIM,'3-D INPUT',.FALSE.,IRTFLG)
         IF (IRTFLG .NE. 0)  RETURN

C        READ SELECTION DOC FILE 
         NIMAXT = NIMAX
         CALL FILELIST(.FALSE.,INDOCS,FINPAT,NLETA,INUMBR,NIMAXT,NANG,
     &        'ANGLE NUMBERS OR SELECTION DOC. FILE NAME',IRTFLG)
         IF (IRTFLG .NE. 0) RETURN 
         
C        OPEN ANGLES DOC FILE
         CALL OPENDOC(FINPIC,.TRUE.,NLETI,INDOCAT,INDOCA,.TRUE.,
     &            'ANGLES DOC',.TRUE.,.FALSE.,.FALSE.,NEWFILE,IRTFLG)
         IF (IRTFLG .NE. 0)  RETURN

C        READ ANGLES (IN DEGREES) FROM ANGLES DOC FILE.
C        ORDER IN THE DOC. FILE IS PSI, THETA, PHI! 
         ALLOCATE(ANGBUF(3,NANG),STAT=IRTFLG)
         IF (IRTFLG .NE. 0) THEN 
            MWANT = 3*NANG 
            CALL ERRT(46,'ANGBUF',MWANT)
	    GOTO 9996
         ENDIF

         IF (IRTFLG .NE. 0) RETURN 

C        RETRIEVE THE ANGLES FROM KEYED DOC FILE
         CALL LUNDOCREDANG(INDOCA,ANGBUF,NANG,NGOTY,MAXGOTY,IRTFLG)
         IF (IRTFLG .NE. 0) GOTO 9996

         N2  = 2*NSAM
         LSD = N2+2-MOD(N2,2)

         ALLOCATE (X(0:N2/2,N2,N2), STAT=IRTFLG)
         IF (IRTFLG .NE. 0) THEN 
            MWANT = (1+N2)/2 * N2 * N2 
            FWANT = (1+N2)/2 * N2 * N2 
            WRITE(NOUT,*) ' BYTES WANTED: ',FWANT
            CALL ERRT(46,'X',MWANT)
	    GOTO 9996
         ENDIF

C        LOAD THE VOLUME INTO: X
         CALL READV(INVOL,X,NSAM,NSAM,NSAM,NSAM,NSAM)
         CLOSE(INVOL)

C        PROJECT NOW
         CALL GPRJ3(NSAM,X,X,
     &              LSD,N2,N2/2,ANGBUF,NANG,INUMBR,NANG)

         IF (MYPID .LE. 0) THEN
            WRITE(NOUT,90) NANG
90          FORMAT('  PJ 3G FINISHED FOR: ',I6,'   PROJECTIONS ----',/)
            CALL FLUSHRESULTS()
         ENDIF

9996     IF (ALLOCATED(X))       DEALLOCATE(X)
         IF (ALLOCATED(ANGBUF))  DEALLOCATE(ANGBUF)

         END


C       ------------------ GPRJ3 ----------------------------------

        SUBROUTINE GPRJ3(NS,X,VO,LSD,N,N2,ANGBUF,MAXKEY,ISELECT,NANG)

        INCLUDE 'CMBLOCK.INC'
        INCLUDE 'CMLIMIT.INC'
        
        COMPLEX, DIMENSION(0:N2,N,N)           :: X 
	REAL, DIMENSION(NS,NS,NS)              :: VO
	REAL, DIMENSION(4)                     :: BUFOUT
        INTEGER, DIMENSION(MAXKEY)             :: ISELECT
        REAL,    DIMENSION(3,MAXKEY)           :: ANGBUF

        REAL, DIMENSION(:,:,:),    ALLOCATABLE :: PROJ
        COMPLEX, DIMENSION(:,:),   ALLOCATABLE :: FPROJ1
        COMPLEX, DIMENSION(:,:,:), ALLOCATABLE :: BI
        COMPLEX, DIMENSION(:,:,:), ALLOCATABLE :: VIN

        PARAMETER         (LTABI=5999)
        REAL, DIMENSION(0:LTABI)               :: TABI
        CHARACTER (LEN=MAXNAM)                 :: FINPAT,FINP

        DATA  INPAT/91/

C       CREATE KAISER-BESSEL TABLE
        CALL FILLBESSI0(NS,LTABI,LNB,LNE,FLTB,TABI,ALPHA,RRR,V)
c       write(6,*) 'TABI(66): ',TABI(66),V,FLTB,ALPHA,RRR,V,LNB,LNE

C       FIND NUMBER OF PARALLEL THREADS
        CALL GETTHREADS(NUMTH)

        ALLOCATE (FPROJ1(0:N2,NUMTH),
     &		  PROJ(NS,NS,NUMTH),
     &            BI(0:N2,N,NUMTH),
     &            VIN(0:N2,N,N),
     &            STAT=IRTFLG)
        IF (IRTFLG .NE. 0) THEN
           MWANT =(N2+1)*NUMTH+ NS*NS*NUMTH+2*(N2+1)*N*NUMTH+(N2+1)*N*N 
           CALL ERRT(46,'FPROJ1, ...',MWANT)
           RETURN
        ENDIF

C       CREATE FFTW3 NxN PLAN FOR USE WITHIN OMP LOOP BELOW	
        CALL FMRS_PLAN(.TRUE.,BI, N,N,1, 1,-1,IRTFLG)
        IF (IRTFLG .NE. 0) RETURN

C       PREPARE INPUT VOLUME
        CALL DIVKB3(VO,NS,ALPHA,RRR,V)   !CODE LOCATED IN: wiw3g.f

        CALL PAD3_3(VIN,N+2,N,VO,NS)

C       FORWARD FFT ON: VIN NxNxN
        INV = +1
        CALL FMRS_3(VIN,N,N,N,INV)

        DO L=1,N
            DO J=1,N
              DO I=0,N2
                 VIN(I,J,L) = VIN(I,J,L)*(-1)**(I+J+L)
              ENDDO
            ENDDO
        ENDDO

C       SHIFT THE ORIGIN OF THE FT FROM (0,0) TO (0,int(N/2)+1=N2+1)
        DO  L=1,N
           DO  J=1,N2
             FPROJ1(:,1)   = VIN(:,J,L)
             VIN(:,J,L)    = VIN(:,J+N2,L)
             VIN(:,J+N2,L) = FPROJ1(:,1)
           ENDDO
        ENDDO

        DO J=1,N
           DO L=1,N2
             FPROJ1(:,1)   = VIN(:,J,L)
             VIN(:,J,L)    = VIN(:,J,L+N2)
             VIN(:,J,L+N2) = FPROJ1(:,1)
           ENDDO
        ENDDO

C       GET FINPAT TEMPLATE ONLY (NOT ILIST)
        NMAX = 0
        CALL FILSEQP(FINPAT,NLET,ILIST,NMAX,NIMA,
     &               'TEMPLATE FOR 2-D PROJECTION',IRTFLG)

        IFORM = 1
        NSL   = 1
	NP2   = N+2 

        IANG  = 1
        DO WHILE (IANG .LE. NANG)
            NEEDED = MIN(IANG+NUMTH-1,NANG)

c$omp       parallel do private(i,ifile,j,jx,inv)
            DO I=IANG,NEEDED
              IFILE = ISELECT(I)

              IF (VERBOSE) WRITE(NOUT,90)IFILE
90            FORMAT('  PROJECTION: ',I6)

              CALL EXTRACTPLANE(N,N2,BI(0,1,I-IANG+1),VIN,
     &		     ANGBUF(3,IFILE),ANGBUF(2,IFILE),ANGBUF(1,IFILE),
     &               LNB,LNE,FLTB,LTABI,TABI)

C             SHIFT THE ORIGIN OF THE FT FROM (0,int(N/2)+1=N2+1) TO (0,0)
              DO  J=1,N2
                 FPROJ1(:,I-IANG+1)  = BI(:,J,I-IANG+1)
                 BI(:,J,I-IANG+1)    = BI(:,J+N2,I-IANG+1)
                 BI(:,J+N2,I-IANG+1) = FPROJ1(:,I-IANG+1)
              ENDDO

              DO  J=1,N
                 DO  JX=0,N2
                    BI(JX,J,I-IANG+1) = BI(JX,J,I-IANG+1)*(-1)**(JX+J+1)
                 ENDDO
              ENDDO

C             INVERSE FFT ON: NxN
              INV = -1
              CALL FMRS_2(BI(0,1,I-IANG+1),N,N,INV)

C             WINDOWING?
	      CALL WIN2_2(BI(0,1,I-IANG+1),NP2,N,PROJ(1,1,I-IANG+1),NS)
	    ENDDO

C           WRITE PROJECTIONS TO OUTPUT FILES
            DO I=IANG,NEEDED
               IFILE  = ISELECT(I)
C              CREATE OUTPUT FILENAME
               CALL FILGET(FINPAT,FINP,NLET,IFILE,IRTFLG)

C              OPEN FILE
               MAXIM = 0
               CALL OPFILEC(0,.FALSE.,FINP,INPAT,'U',IFORM,NS,NS,NSL,
     &                 MAXIM,' ',.FALSE.,IRTFLG)

               DO J=1,NS
                  CALL WRTLIN(INPAT,PROJ(1,J,I-IANG+1),NS,J)
               ENDDO

C              PUT ANGLES IN HEADER
               BUFOUT(1) = ANGBUF(1,IFILE)
               BUFOUT(2) = ANGBUF(2,IFILE)
               BUFOUT(3) = ANGBUF(3,IFILE)
               BUFOUT(4) = 1.0
               CALL LUNSETVALS(INPAT,IAPLOC+1,4,BUFOUT,IRTFLG)
               CLOSE(INPAT)
            ENDDO


            IANG = IANG + NUMTH

         ENDDO

999     IF (ALLOCATED(PROJ))    DEALLOCATE (PROJ)
        IF (ALLOCATED(BI))      DEALLOCATE (BI)
        IF (ALLOCATED(FPROJ1))  DEALLOCATE (FPROJ1)
        IF (ALLOCATED(VIN))     DEALLOCATE (VIN)

	END


C       ------------------- WIN2_2 -------------------------------

	SUBROUTINE  WIN2_2(X,LSD,N,V,NS)

	DIMENSION  X(LSD,N), V(NS,NS)

C       FOR NS ODD ADD ONE.  N IS ALWAYS EVEN
        IP = (N-NS) / 2+MOD(NS,2)
	V  = X(IP+1:IP+NS,IP+1:IP+NS)

	END

C       ------------------- PAD3_3 -------------------------------

	SUBROUTINE  PAD3_3(X,LSD,N,V,NS)
C 
	DIMENSION  X(LSD,N,N),V(NS,NS,NS)
C       FOR NS ODD ADD ONE.  N IS ALWAYS EVEN

	X = 0.0
        IP = (N-NS) / 2+MOD(NS,2)

	DO K=1,NS
	   DO J=1,NS
	      DO I=1,NS
	         X(IP+I,IP+J,IP+K) = V(I,J,K)
	      ENDDO
	   ENDDO
	ENDDO
	END

C       ------------------- EXTRACTPLANE -------------------------------

        SUBROUTINE EXTRACTPLANE(N,N2,X,BI,PHI,THETA,PSI,
     &                          LNB,LNE,FLTB,LTABI,TABI)

        REAL              TABI(0:LTABI)
        COMPLEX           BI(0:N2,-N2:N2-1,-N2:N2-1)
        COMPLEX           X(0:N2,-N2:N2-1),BTQ
        DIMENSION         DM(6)
	DIMENSION         WZ(LNB:LNE),WY(LNB:LNE),WX(LNB:LNE)
	DOUBLE PRECISION  CWG
	LOGICAL           FLIP,MIRROR
        DOUBLE PRECISION  CPHI,SPHI,CTHE,STHE,CPSI,SPSI
        DOUBLE PRECISION  QUADPI,DGR_TO_RAD,RAD_TO_DGR

        PARAMETER (QUADPI = 3.1415926535897932384626)
        PARAMETER (DGR_TO_RAD = (QUADPI/180))

	CWG = 0.0
	LWG = 0
	X   = (0.0,0.0)

	CPHI = DCOS(DBLE(PHI)*DGR_TO_RAD)
	SPHI = DSIN(DBLE(PHI)*DGR_TO_RAD)
	CTHE = DCOS(DBLE(THETA)*DGR_TO_RAD)
	STHE = DSIN(DBLE(THETA)*DGR_TO_RAD)
	CPSI = DCOS(DBLE(PSI)*DGR_TO_RAD)
	SPSI = DSIN(DBLE(PSI)*DGR_TO_RAD)

	DM(1) = CPHI*CTHE*CPSI-SPHI*SPSI
	DM(2) = SPHI*CTHE*CPSI+CPHI*SPSI
	DM(3) = -STHE*CPSI
	DM(4) = -CPHI*CTHE*SPSI-SPHI*CPSI
	DM(5) = -SPHI*CTHE*SPSI+CPHI*CPSI
	DM(6) = STHE*SPSI

	RIM = N2*N2
        DO J=-N2,N2-1
           DO I=0,N2
              XNEW = I * DM(1) + J * DM(4)
              YNEW = I * DM(2) + J * DM(5)
              ZNEW = I * DM(3) + J * DM(6)
              IF (XNEW*XNEW+YNEW*YNEW+ZNEW*ZNEW.LE.RIM)  THEN
                 BTQ = (0.0,0.0)
	         IF (XNEW .LT. 0.0)  THEN
		    FLIP = .TRUE.
		    XNEW = -XNEW
		    YNEW = -YNEW
		    ZNEW = -ZNEW
		 ELSE
		    FLIP = .FALSE.
		 ENDIF

		 IXN = IFIX(XNEW+SIGN(0.5,XNEW))
		 IYN = IFIX(YNEW+SIGN(0.5,YNEW))
		 IZN = IFIX(ZNEW+SIGN(0.5,ZNEW))
		 IF (IXN.GE.-LNB.AND.IXN.LE.N2-1-LNE     .AND.
     &	             IYN.GE.-N2-LNB.AND.IYN.LE.N2-1-LNE  .AND.
     &	             IZN.GE.-N2-LNB.AND.IZN.LE.N2-1-LNE ) THEN
	             LWG = LWG+1

                     DO  LZ=LNB,LNE
                        IZP     = IZN + LZ
                        WZ(LZ)  = TABI(NINT(ABS(ZNEW-IZP) * FLTB))
                        IYP     = IYN + LZ
                        WY(LZ)  = TABI(NINT(ABS(YNEW-IYP) * FLTB))
		        IXP     = IXN + LZ
                        WX(LZ)  = TABI(NINT(ABS(XNEW-IXP) * FLTB))
                     ENDDO

C                    RESTRICT LOOPS
                     DO  LY=LNB,-1,1
                        IF (WY(LY).NE.0.0)  THEN
                           LNBY = LY
                           GOTO 1
                        ENDIF
                     ENDDO

                     LNBY = 0
1                    DO LY=LNE,1,-1
	                IF (WY(LY) .NE. 0.0)  THEN
	                   LNEY = LY
	                   GOTO 2
	                ENDIF
	             ENDDO
	             LNEY = 0
2	             DO  LY=LNB,-1,1
	                IF (WX(LY) .NE. 0.0)  THEN
	                   LNBX = LY
	                   GOTO 3
	                ENDIF
	             ENDDO
	             LNBX = 0
3	             DO  LY=LNE,1,-1
	                IF (WX(LY) .NE. 0.0)  THEN
                           LNEX = LY
	                   GOTO 4
	                ENDIF
	             ENDDO
	             LNEX = 0

4	             DO  LY=LNB,-1,1
                        IF(WZ(LY) .NE. 0.0)  THEN
                           LNBZ = LY
                           GOTO 5
                        ENDIF
                     ENDDO
                  LNBZ = 0
5	          DO  LY=LNE,1,-1
	             IF (WZ(LY) .NE. 0.0)  THEN
                       LNEZ = LY
	               GOTO 6
	             ENDIF
	          ENDDO
	          LNEZ = 0

6	          CONTINUE	

                  DO LZ=LNBZ,LNEZ
                      IZP = IZN + LZ
                      DO LY=LNBY,LNEY
                         IYP = IYN + LY
                         TY  = WZ(LZ)*WY(LY)
                         DO LX=LNBX,LNEX
                            IXP  = IXN + LX

C                           GET THE WEIGHT
                            WG  = WX(LX)*TY
                            BTQ = BTQ + BI(IXP,IYP,IZP) * WG
                            CWG = CWG+WG
                         ENDDO
                     ENDDO
                  ENDDO
	       ELSE

C                 SPECIAL CASES OF POINTS "STICKING OUT"
	          LWG=LWG+1

	          DO  LZ=LNB,LNE
                      IZP     = IZN + LZ
                      WZ(LZ)  = TABI(NINT(ABS(ZNEW-IZP) * FLTB))
                      IYP     = IYN + LZ
                      WY(LZ)  = TABI(NINT(ABS(YNEW-IYP) * FLTB))
		      IXP     = IXN + LZ
                      WX(LZ)  = TABI(NINT(ABS(XNEW-IXP) * FLTB))
	          ENDDO

C                 RESTRICT LOOPS
	          DO LY=LNB,-1,1
	             IF (WY(LY) .NE. 0.0)  THEN
                        LNBY = LY
	                GOTO 11
	             ENDIF
	          ENDDO
	          LNBY=0
11	          DO LY=LNE,1,-1
	             IF (WY(LY) .NE. 0.0)  THEN
                        LNEY = LY
	                GOTO 12
	             ENDIF
	          ENDDO
	          LNEY = 0
12	          DO  LY=LNB,-1,1
	             IF (WX(LY) .NE.0.0)  THEN
                        LNBX = LY
	                GOTO 13
	             ENDIF
	          ENDDO
	          LNBX = 0
13	          DO  LY=LNE,1,-1
	             IF (WX(LY) .NE.0.0)  THEN
	                LNEX = LY
	                GOTO 14
	             ENDIF
	          ENDDO
                  LNEX = 0
14	          DO  LY=LNB,-1,1
                     IF (WZ(LY) .NE.0.0)  THEN
                        LNBZ = LY
                        GOTO 15
                     ENDIF
                  ENDDO
                  LNBZ=0
15	          DO  LY=LNE,1,-1
                     IF (WZ(LY) .NE. 0.0)  THEN
                        LNEZ = LY
                        GOTO 16
                     ENDIF
                  ENDDO
                  LNEZ = 0
16	          CONTINUE	


                  DO LZ=LNBZ,LNEZ
                      IZP = IZN + LZ
                          DO  LY=LNBY,LNEY
                             IYP = IYN + LY
                             TY  = WZ(LZ)*WY(LY)
                                DO LX=LNBX,LNEX
				   IXP = IXN + LX
C                                  GET THE WEIGHT
                                   WG     = WX(LX)*TY
	                           MIRROR =.FALSE.
	                           IXT    = IXP
	                           IYT    = IYP
	                           IZT    = IZP
	                           IF (IXT.GT.N2.OR.IXT.LE.-N2) THEN
	                              IXT    = ISIGN(N-IABS(IXT),IXT)
	                              IYT    = -IYT
	                              IZT    = -IZT
	                              MIRROR = .NOT.MIRROR
	                           ENDIF

	                           IF (IYT.GE.N2.OR.IYT.LT.-N2 ) THEN
	                              IF (IXT.NE.0) THEN
	                                 IXT    = -IXT
	                                 IYT    = ISIGN(N-IABS(IYT),IYT)
	                                 IZT    = -IZT
	                                 MIRROR = .NOT.MIRROR
	                              ELSE
	                                 IYT = IYT-ISIGN(N,IYT)
	                              ENDIF
	                           ENDIF

	                           IF (IZT.GE.N2.OR.IZT.LT.-N2)  THEN
	                              IF (IXT.NE.0)  THEN
	                                 IXT    = -IXT
	                                 IYT    = -IYT
	                                 IZT    = ISIGN(N-IABS(IZT),IZT)
	                                 MIRROR = .NOT.MIRROR
	                              ELSE
	                                 IZT = IZT-ISIGN(N,IZT)
	                              ENDIF
	                           ENDIF

	                           IF (IXT.LT.0)  THEN
	                              IXT    = -IXT
	                              IYT    = -IYT
	                              IZT    = -IZT
	                              MIRROR = .NOT.MIRROR
	                           ENDIF

	                           IF (IYT .EQ. N2) IYT=-N2
	                           IF (IZT .EQ. N2) IZT=-N2

	                           IF (MIRROR) THEN
	                              BTQ = BTQ + 
     &                                      CONJG(BI(IXT,IYT,IZT)) * WG
	                           ELSE
                                      BTQ = BTQ + BI(IXT,IYT,IZT) * WG
	                           ENDIF
	                           CWG = CWG + WG
	                        ENDDO
	                     ENDDO
	                  ENDDO
	               ENDIF
	               IF (FLIP)  THEN
	                  X(I,J) = CONJG(BTQ)
	               ELSE
	                  X(I,J) = BTQ
	               ENDIF
	            ENDIF
C                   END I-J LOOP
                 ENDDO
              ENDDO

	      X = X / CWG * LWG
        END
