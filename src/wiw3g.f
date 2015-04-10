C++*********************************************************************
C
C WIW3G.F        
C              EXTENSIVELY ALTERED                 MAR 07 ArDean Leith
C              FMRS_PLAN                           MAY 08 ARDEAN LEITH
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
C WIW3G
C
C PURPOSE:  BACK PROJECTION, USES GRIDDING
C
C CALL TREE:   WIW3G --> VRDG --> HSORTD
C                |                VORONOIDIAG --> VORONOI --> DISORDER2
C                |                                   `    --> CONVXYZ
C                |
C                `   --> GBP3 --> FILLBESSIO
C                          `  --> RVGPRJ  omp   --> ASTA
c                          `            `    --> DIVKB2
C                          `            `    --> PGD2
C                          `            `    --> FMRS_1
C                          `            `    --> FMRS_2
c                          ` 
c                          `  --> WIN3_3     --> DIVKB2
C                          `  --> DIVKB3     --> PGD2
C                          `  --> FMRS_3

C23456789012345678901234567890123456789012345678901234567890123456789012
C--*********************************************************************

        SUBROUTINE WIW3G

        INCLUDE 'CMBLOCK.INC'
        INCLUDE 'CMLIMIT.INC'
        INCLUDE 'F90ALLOC.INC'

        REAL, DIMENSION(:,:), ALLOCATABLE      :: DM3,SM
        COMPLEX, DIMENSION(:,:,:), ALLOCATABLE :: X
        REAL, DIMENSION(:), ALLOCATABLE        :: TEMP
C       DOC FILE POINTERS
        REAL, DIMENSION(:,:), POINTER          :: ANGBUF, ANGSYM

        CHARACTER (LEN=MAXNAM)                 :: FINPIC,FINPAT,ANGDOC
        CHARACTER (LEN=MAXNAM)                 :: FILNAM

	PARAMETER (QUADPI = 3.14159265358979323846)

        DATA  IOPIC/98/,INPIC/99/

	NILMAX = NIMAX
        CALL FILELIST(.TRUE.,INPIC,FINPAT,NLET,INUMBR,NILMAX,NANG,
     &                 'TEMPLATE FOR 2-D IMAGES',IRTFLG)
        IF (IRTFLG .NE. 0) RETURN
        CLOSE(INPIC)

        MAXNUM = MAXVAL(INUMBR(1:NANG))

C       N    - LINEAR DIMENSION OF PROJECTIONS AND RESTORED CUBE
C       NANG - TOTAL NUMBER OF IMAGES
        WRITE(NOUT,*)' NUMBER OF IMAGES:',NANG

C       RETRIEVE ANGBUG ARRAY WITH ANGLES DATA IN IT
        MAXXT = 4
        MAXYT = MAXNUM
        CALL GETDOCDAT('ANGLES DOC',.TRUE.,ANGDOC,77,.FALSE.,MAXXT,
     &                  MAXYT,ANGBUF,IRTFLG)
        IF (IRTFLG .NE. 0) GOTO 999

C       RETRIEVE ANGSUM ARRAY WITH SYMMETRIES DATA IN IT
        MAXXS  = 0
        MAXSYM = 0
        CALL GETDOCDAT('SYMMETRIES DOC',.TRUE.,ANGDOC,77,.TRUE.,MAXXS,
     &                   MAXSYM,ANGSYM,IRTFLG)
        IF (IRTFLG .NE. 0)  MAXSYM=1

C       OPEN FIRST IMAGE FILE TO DETERMINE NSAM, NROW, NSL
        CALL FILGET(FINPAT,FINPIC,NLET,INUMBR(1),INTLFG)

        MAXIM  = 0
        IRTFLG = 0
        CALL OPFILEC(0,.FALSE.,FINPIC,INPIC,'O',IFORM,NSAM,NROW,NSL,
     &              MAXIM,'DUMMY',.FALSE.,IRTFLG)
        IF (IRTFLG .NE. 0) RETURN
        CLOSE(INPIC)

        N2  = 2*NSAM
        LSD = N2+2-MOD(N2,2)
 
        ALLOCATE(DM3(9,NANG), STAT=IRTFLG)
        IF (IRTFLG.NE.0) THEN 
           CALL ERRT(46,'BP 3G, DM',9*NANG)
           RETURN
        ENDIF

C       UPDATED BUILDM al 
        CALL BUILDM(INUMBR,DM3,NANG,ANGBUF,.FALSE.,SSDUM,
     &               .FALSE.,IRTFLG)
        DEALLOCATE(ANGBUF)
        IF (IRTFLG .NE. 0) GOTO 999

        IF (MAXSYM.GT.1)  THEN
C          HAS SYMMETRIES
           ALLOCATE(SM(9,MAXSYM), STAT=IRTFLG)
           IF (IRTFLG.NE.0) THEN 
              CALL ERRT(46,'BP 3G, SM',9*MAXSYM)
              GOTO 999
           ENDIF

           CALL BUILDS(SM,MAXSYM,ANGSYM(1,1),IRTFLG)
           IF (ASSOCIATED(ANGSYM)) DEALLOCATE(ANGSYM)
        ELSE
           ALLOCATE(SM(1,1), STAT=IRTFLG)
           IF (IRTFLG.NE.0) THEN 
              CALL ERRT(46,'BP 3G, SM-2nd',1)
              GOTO 999
           ENDIF
        ENDIF

C       PREPARE THE WEIGHTS USING THE VORONOI DIAGRAM
C       NUMBER OF LINE PROJECTIONS FOR REVERSE GRIDDING
	NANG2 = NINT(QUADPI*NSAM)

	WRITE(NOUT,*)'  Number of line projections: ',NANG2

C       CREATES WEIGHTS FILE
	CALL VRDG(DM3,NANG,NANG2)

        ALLOCATE (X(0:N2/2,N2,N2), STAT=IRTFLG)
        IF (IRTFLG.NE.0) THEN 
           MWANT = (1+(N2/2)) * N2 * N2
           CALL ERRT(46,'BP 3G, X',MWANT)
           DEALLOCATE (DM3, SM)
	   RETURN
        ENDIF

C       CALCULATE THE 3D RECONSTRUCTION USING WEIGHTS FROM VRDG
        CALL GBP3(NSAM,X,X,
     &      LSD,N2,N2/2,INUMBR,DM3,NANG,SM,MAXSYM,NANG2,FINPAT,NLET)

C       ADDITIONAL SYMMETRIZATION OF THE VOLUME IN REAL SPACE 05/03/02
	IF (MAXSYM .GT. 1)  THEN
           MWANT = NSAM*NSAM*NSAM
           ALLOCATE (TEMP(NSAM*NSAM*NSAM), STAT=IRTFLG)
           IF (IRTFLG.NE.0) THEN 
              CALL ERRT(46,'BP 3G, TEMP',MWANT)
              GOTO 999
           ENDIF

           CALL COP(X,TEMP,NSAM*NSAM*NSAM)

c$omp      parallel do private(i,j,k)
           DO K=1,N2
              DO J=1,N2
                 DO I=0,N2/2
                    X(I,J,K) = CMPLX(0.0,0.0)
                 ENDDO
              ENDDO
           ENDDO

           IF (MOD(NSAM,2) .EQ. 0)  THEN
              KNX = NSAM/2-1
           ELSE
              KNX = NSAM/2
           ENDIF
           KLX = -NSAM/2

	   CALL SYMVOL(TEMP,X,KLX,KNX,KLX,KNX,KLX,KNX,SM,MAXSYM)
	   DEALLOCATE(TEMP)
	ENDIF

        IFORM  = 3
        IRTFLG = 0
        CALL OPFILEC(0,.TRUE.,FILNAM,IOPIC,'U',IFORM,NSAM,NSAM,NSAM,
     &           MAXIM,'RECONSTRUCTED 3-D',.FALSE.,IRTFLG)
        IF (IRTFLG .NE. 0) GOTO 999

C       NOTE: NSAM=NROW=NSLICE 
        CALL WRITEV(IOPIC,X,NSAM,NSAM,NSAM,NSAM,NSAM)
        CLOSE(IOPIC)

999     IF (ALLOCATED(DM3)) DEALLOCATE(DM3)
        IF (ALLOCATED(SM))  DEALLOCATE(SM)
        IF (ALLOCATED(X))   DEALLOCATE(X)

        CALL FMRS_DEPLAN(IRTFLG)
        END

C       ------------------ GBP3 ----------------------------------

        SUBROUTINE GBP3(NS,X,VO,LSD,N,N2,ISELECT,
     &                  DM3,NANG,SM,MAXSYM,NANG2,FINPAT,NLET)

C       CALCULATES RECONSTRUCTION
      
        INCLUDE 'CMLIMIT.INC'

        COMPLEX         X(0:N2,N,N)
	DIMENSION	VO(NS,NS,NS)
        DIMENSION       ISELECT(NANG)
        DIMENSION       DM3(3,3,NANG),SM(3,3,MAXSYM)

        DOUBLE  PRECISION, DIMENSION(:,:), ALLOCATABLE :: WEIGHT
        REAL, DIMENSION(:,:), ALLOCATABLE              :: DM
        REAL, DIMENSION(:,:,:), ALLOCATABLE            :: PROJ
        COMPLEX, DIMENSION(:,:,:,:), ALLOCATABLE       :: XB
        COMPLEX, DIMENSION(:), ALLOCATABLE             :: FPROJ1

 	DOUBLE  PRECISION  CWG,CWGT
 	DOUBLE  PRECISION  QUADPI
 	DOUBLE  PRECISION  TOTW,SINTHETA,DELTATHETA,SINDELTATHETA

        CHARACTER (LEN=*)                 :: FINPAT
        CHARACTER (LEN=MAXNAM)            :: FINPIC

        PARAMETER         (LTABI=5999)
        REAL, DIMENSION(0:LTABI)          :: TABI

        DATA  INPROJ/99/,LOY/51/

	PARAMETER (QUADPI = 3.1415926535897932384626D0)
 
        CALL FILLBESSI0(NS,LTABI,LNB,LNE,FLTB,TABI,ALPHA,RRR,V)

        CALL GETTHREADS(NUMTH)

        ALLOCATE (WEIGHT(MAXSYM*NANG2,NUMTH),
     &            FPROJ1(0:N2),
     &	          PROJ(NS,NS,NUMTH),
     &            XB(0:N2,N,N,NUMTH),
     &            DM(2,NANG2),   STAT=IRTFLG)
        IF (IRTFLG .NE. 0) THEN
            MWANT = MAXSYM*NANG2*NUMTH + (N2 + 1) + NS*NS*NUMTH +
     &              (N2+1)*N*N*NUMTH   + 2*NANG2
            CALL ERRT(46,'BP 3G, WEIGHT...',MWANT)
            RETURN
        ENDIF
	
	XB  = CMPLX(0.0, 0.0)
	CWG = 0.0
	LWG = 0

C       ANGLES FOR REVERSE GRIDDING
	DELTATHETA    = QUADPI/NANG2
	SINDELTATHETA = DSIN(DELTATHETA/2)
	DO  I=1,NANG2
	   DM(1,I) = DCOS(DELTATHETA*(I-1))
	   DM(2,I) = DSIN(DELTATHETA*(I-1))
	ENDDO

C       OPEN EXISTING WEIGHTS FILE
        OPEN(LOY,FILE='BP3G_WEIGHT',STATUS='OLD',FORM='UNFORMATTED')
 
C       LOOP OVER ALL IMAGES  
        NUMTHT = NUMTH
        NUMTHT = 1
    
        DO KN=1,NANG,NUMTHT
	   KE = MIN(NANG,KN+NUMTHT-1)
	   DO  K=KN,KE

C             OPEN SELECTED IMAGE FILE
              CALL FILGET(FINPAT,FINPIC,NLET,ISELECT(K),IRTFLG)
              IF (IRTFLG .NE. 0) GOTO 999
              MAXIM = 0
              CALL OPFILEC(0,.FALSE.,FINPIC,INPROJ,'O',IFORM,
     &                     NSAM,NSAM,NSL,
     &                     MAXIM,'DUMMY',.FALSE.,IRTFLG)
              IF (IRTFLG .NE. 0) GOTO 999

C             LOAD THE IMAGE
	      CALL READV(INPROJ,PROJ(1,1,K-KN+1),NS,NS,NS,NS,1)
              CLOSE(INPROJ)

C             LOAD NEXT WEIGHT FROM TEMP WEIGHTS FILE
	      READ(LOY)    (WEIGHT(J,K-KN+1),J=1,MAXSYM*NANG2)
c	      write(6,101) (WEIGHT(J,K-KN+1),J=1,MAXSYM*NANG2)
c101	      format(1x,E15.5)
	    ENDDO

            KE   = MIN(KE-KN+1,NUMTHT)
            CWGT = 0.0
            LWGT = 0

C           RBGPRJ CALLS FMRS INSIDE OMP, SO CREATE PLANS HERE

C           CREATE FORWARD FFTW3 PLAN FOR 1D FFT USING ONE THREAD
            CALL FMRS_PLAN(.FALSE.,FDUM, N,1,1, 1,+1,IRTFLG)
            IF (IRTFLG .NE. 0) RETURN
C           CREATE REVERSE FFTW3 PLAN FOR 1D FFT USING ONE THREAD
            CALL FMRS_PLAN(.FALSE.,FDUM, N,1,1, 1,-1,IRTFLG)
            IF (IRTFLG .NE. 0) RETURN
C           CREATE FORWARD FFTW3 PLAN FOR 2D FFT USING ONE THREAD
            CALL FMRS_PLAN(.FALSE.,FDUM, N,N,1, 1,+1,IRTFLG)
            IF (IRTFLG .NE. 0) RETURN

C           LOOPS OVER ALL IMAGES(ANGLES) RETURNING XB 
c$omp       parallel do private(K),reduction(+:CWGT,LWGT)
            DO K=1,KE
               CALL RVGPRJ(XB(0,1,1,K),PROJ(1,1,K),
     &                   N,NS,N2,LSD,DM,DM3(1,1,K+KN-1),
     &	                 NANG,NANG2,SM,MAXSYM,WEIGHT(1,K),CWGT,LWGT,
     &                   ALPHA,RRR,V,
     &                   LNB,LNE,FLTB,LTABI,TABI)
            ENDDO

#ifdef NEVER
          if (kn .le. 10 .or. kn .eq. nang) then
          write(6,*) '  XB(0:N2,N,N,1) for n2,k,kn ',n2,k,kn
          nit  = n2/2
          njt  = n/2+1
          ngo  = n/2+1
          nend = ngo + 200
          write(6,9001) (xb(nit,njt,ii,1),ii=ngo,nend)
9001      format( 5(1pg12.2,' '))
          endif
#endif


            CWG = CWG + CWGT
            LWG = LWG + LWGT

C           END OF THE PROJECTIONS LOOP
	ENDDO


	CLOSE(LOY,STATUS='DELETE')

C       SUM OVER ALL NUMTHT
	X = SUM(XB(:,:,:,:),DIM=4)

C       SHIFT ORIGIN OF THE FT FROM (0,int(N/2)+1=N2+1) TO (0,0)
        DO  L=1,N
           DO  J=1,N2
              FPROJ1      = X(:,J,L)
              X(:,J,L)    = X(:,J+N2,L)
              X(:,J+N2,L) = FPROJ1
           ENDDO
        ENDDO

        DO J=1,N
           DO L=1,N2
             FPROJ1      = X(:,J,L)
             X(:,J,L)    = X(:,J,L+N2)
             X(:,J,L+N2) = FPROJ1
           ENDDO
        ENDDO

c$omp   parallel do private(i,j,l)
        DO L=1,N
            DO J=1,N
              DO I=0,N2
                 X(I,J,L) = X(I,J,L)*(-1)**(I+J+L) / CWG*LWG 
              ENDDO
            ENDDO
        ENDDO

C       REAL MIXED RADIX FFT.
        INV = -1
        CALL FMRS_3(X,N,N,N,INV)

        CALL WIN3_3(X,N+2,N,VO,NS)

        CALL DIVKB3(VO,NS,ALPHA,RRR,V)

999     CONTINUE
        IF (ALLOCATED(WEIGHT)) DEALLOCATE (WEIGHT)
        IF (ALLOCATED(PROJ))   DEALLOCATE (PROJ)
        IF (ALLOCATED(XB))     DEALLOCATE (XB)
        IF (ALLOCATED(FPROJ1)) DEALLOCATE (FPROJ1)
        IF (ALLOCATED(DM))     DEALLOCATE (DM)
	END

C       ------------------ RVGPRJ ----------------------------------

	SUBROUTINE RVGPRJ(X,PROJ,N,NS,N2,LSD,
     &		DM,DM3,NANG,NANG2,SM,MAXSYM,WEIGHT,CWG,LWG,
     &          ALPHA,RRR,V,
     &          LNB,LNE,FLTB,LTABI,TABI)

        REAL              TABI(0:LTABI)
	DIMENSION         PROJ(NS,NS),DM(2,NANG2)
	DOUBLE PRECISION  WEIGHT(MAXSYM,NANG2)
	DIMENSION         DM3(3,3),SM(3,3,MAXSYM),DMS(3,3)
	COMPLEX           X(*)
	COMPLEX           FPROJ1(0:N2),BI(0:N2,1:N),FSP(NS,NANG2)
        DOUBLE PRECISION  QS,CWG

	PARAMETER (QUADPI = 3.14159265358979323846D0)

        KLP = 0
        R   = NS/2
        QS  = 0.0D0

C       SUM OF DENSITIES OUTSIDE CIRCLE OF RADIUS: R
        CALL ASTA(PROJ,NS,R,QS,KLP)

        QS   = QS/REAL(KLP)

C       SUBTRACT AVERAGE OUTSIDE CIRCLE FROM ALL VALUES OF: PROJ
	PROJ = PROJ - QS

	CALL DIVKB2(PROJ,NS,ALPHA,RRR,V)

C       PGD2 RETURNS: BI WHICH APPEARS TO WINDOW & ZERO OUTSIDE A RADIUS??
	CALL PGD2(PROJ,NS,BI,LSD,N)

C       REAL MIXED RADIX FFT.
	INV = +1
	CALL FMRS_2(BI,N,N,INV)

c$omp   parallel do private(i,j)
	DO  J=1,N
           DO  I=0,N2
              BI(I,J) = BI(I,J)*(-1)**(I+J+1)
           ENDDO
	ENDDO

C       SHIFT THE ORIGIN OF THE FT TO (0,int(N/2)+1=N2+1), 
C       FPROJ1 IS A TEMP ARRAY
	DO  J=1,N2
           FPROJ1     = BI(:,J)
           BI(:,J)    = BI(:,J+N2)
           BI(:,J+N2) = FPROJ1
	ENDDO

	INV = -1
	DO J=1,NANG2
           CALL EXTRACTLINE(FPROJ1,BI,N,N2,DM(1,J),
     &                      LNB,LNE,FLTB,LTABI,TABI)
           DO  I=1,N2,2
              FPROJ1(I) = -FPROJ1(I)
           ENDDO

C          REAL MIXED RADIX REVERSE FFT.
           CALL FMRS_1(FPROJ1,N,INV)

           CALL WIT1(FPROJ1,N2,FSP(1,J),NS)
	ENDDO

C       FSP CONTAINS THE INPUT PROJECTION IN THE FORM OF NANG2 LINE PROJECTIONS
C       PLACE THEM IN THE 3D VOLUME X

	INV = +1
	DO J=1,NANG2
	    FPROJ1(N2) = (0.0,0.0)
	    CALL PD12(FSP(1,J),NS,FPROJ1,N)

C           REAL MIXED RADIX FORWARD FFT.
	    CALL FMRS_1(FPROJ1,N,INV)
            DO  I=1,N2,2
               FPROJ1(I) = -FPROJ1(I)
            ENDDO

            DO  ISYM=1,MAXSYM
               IF (MAXSYM.GT.1)  THEN
C                 SYMMETRIES, MULTIPLY MATRICES
                  DMS = MATMUL(SM(:,:,ISYM),DM3(:,:))
               ELSE
                  DMS = DM3(:,:)
               ENDIF

	       FPROJ1(0) = FPROJ1(0)*QUADPI/6./NANG/NANG2
	       DO  I=1,N2
	          FPROJ1(I) = 
     &               FPROJ1(I)*(0.5*REAL(I*I)+1./24.)*WEIGHT(ISYM,J)
	       ENDDO

               CALL  PUTLINE3(N,N2,FPROJ1,X,DM(1,J),DMS,CWG,LWG,
     &                       LNB,LNE,FLTB,LTABI,TABI)

           ENDDO   ! END OF SYMMETRIES LOOP
	ENDDO

	END


C       ------------------- DIVKB2 -------------------------------

        SUBROUTINE DIVKB2(X,M,ALPHA,RRR,V)

        DIMENSION  X(M,M)

	PARAMETER (QUADPI = 3.14159265358979323846)
	PARAMETER (TWOPI = 2*QUADPI)

C       M is NSAM
	ICENT = INT(M/2)+1
	WKB0  = SINH(TWOPI*ALPHA*RRR*V)/(TWOPI*ALPHA*RRR*V)
	DO J=1,M
           TTT=REAL(IABS(J-ICENT))/RRR
           IF (TTT.EQ.0.0)  THEN
              WKBJ = 1.0

           ELSEIF (TTT.LT.ALPHA)  THEN
              XX   = SQRT(1.0-(TTT/ALPHA)**2)
              WKBJ = SINH(TWOPI*ALPHA*RRR*V*XX)/
     &                 (TWOPI*ALPHA*RRR*V*XX)/WKB0

           ELSEIF (TTT.EQ.ALPHA)  THEN
              WKBJ = 1.0/WKB0

           ELSE
              XX   = SQRT((TTT/ALPHA)**2-1.0)
              WKBJ = SIN(TWOPI*ALPHA*RRR*V*XX)/
     &                (TWOPI*ALPHA*RRR*V*XX)/WKB0
           ENDIF

           DO I=1,M
              TTT = REAL(IABS(I-ICENT))/RRR
              IF (TTT .EQ. 0.0)  THEN
                 WKBI = 1.0

              ELSEIF (TTT .LT. ALPHA)  THEN
                 XX   = SQRT(1.0-(TTT/ALPHA)**2)
                 WKBI = SINH(TWOPI*ALPHA*RRR*V*XX)/
     &                      (TWOPI*ALPHA*RRR*V*XX)/WKB0

              ELSEIF( TTT .EQ. ALPHA)  THEN
                 WKBI = 1.0/WKB0

              ELSE
                 XX   = SQRT((TTT/ALPHA)**2-1.0)
                 WKBI = SIN(TWOPI*ALPHA*RRR*V*XX)/
     &                    (TWOPI*ALPHA*RRR*V*XX)/WKB0
              ENDIF
              X(I,J) = X(I,J) / ABS(WKBI*WKBJ)
	   ENDDO
	ENDDO
        END

C       ------------------- PGD2 -------------------------------

        SUBROUTINE PGD2(PROJ,L,BI,LSD,N)

        DIMENSION  PROJ(L,L),BI(LSD,N)
        DOUBLE     PRECISION QS

        KLP = 0
        R   = L/2
        QS  = 0.0D0

c       QS = QS / REAL(KLP)

c$omp   parallel do private(i,j)
        DO J=1,N
           DO I=1,N
              BI(I,J) = 0.0
           ENDDO
        ENDDO

C       FOR L ODD ADD ONE.  N IS ALWAYS EVEN
	NC = INT(L/2)+1
	R2 = (R-1.)**2
        IP = (N-L)/2+MOD(L,2)

C       ZERO BI OUTSIDE OF RADIUS: R
c$omp   parallel do private(i,j)
        DO  J=1,L
           DO  I=1,L
              IF ( (REAL(I-NC)**2+REAL(J-NC)**2) .LE. R2) THEN
                 BI(IP+I,IP+J) = PROJ(I,J)
              ELSE
                 BI(IP+I,IP+J) = 0.0
              ENDIF
           ENDDO
        ENDDO

        END

C       ---------------------- WIT1 ----------------------------------

	SUBROUTINE WIT1(X,N2,FSP,NS)

	DIMENSION  X(2*N2+2),FSP(NS)

	IP     = N2-NS/2+1
	FSP(:) = X(IP:IP+NS-1)

	END

C       ---------------------- PD12 ----------------------------------

	SUBROUTINE PD12(FSP,NS,BI,N)
	DIMENSION   FSP(NS),BI(N)

        IP             = (N-NS )/ 2 + MOD(NS,2)
	BI(IP+1:IP+NS) = FSP
	BI(1:IP)       = 0.0
	BI(IP+NS+1:N)  = 0.0

	END


C       ---------------------- WIN3_3 ----------------------------------

	SUBROUTINE WIN3_3(X,LSD,N,V,NS)

C       V CAN BE THE SAME AS X
	DIMENSION  X(LSD,N,N),V(NS,NS,NS)

C       FOR NS ODD ADD ONE.  N IS ALWAYS EVEN
        IP = (N-NS) / 2+MOD(NS,2)

	DO K=1,NS
	   DO J=1,NS
	      DO I=1,NS
	         V(I,J,K) = X(IP+I,IP+J,IP+K)
	      ENDDO
	   ENDDO
	ENDDO
	END

C       ---------------------- VRDG ----------------------------------

C       VERSION WITH SORTING TO SPEED UP THE VORONOI.

	SUBROUTINE VRDG(DM3,N,NANG2)

        INCLUDE 'CMBLOCK.INC'

	DIMENSION  DM3(3,3,N)
 	DOUBLE  PRECISION  PHIS,SINTHETA,DELTATHETA,SINDELTATHETA
	DOUBLE  PRECISION  DM(2,NANG2),X(3)
        DOUBLE  PRECISION, DIMENSION(:,:,:), ALLOCATABLE :: XC
        DOUBLE  PRECISION, DIMENSION(:,:), ALLOCATABLE   :: WEIGHT
        INTEGER, DIMENSION(:), ALLOCATABLE               :: KEY

 	DOUBLE  PRECISION  QUADPI
	PARAMETER (QUADPI = 3.1415926535897932384626D0)

	DATA  LIN,LOU,LOS,LOW,LOY,LOK/51,52,65,66,67,68/

C       ANGLES FOR REVERSE GRIDDING
	PHIS = QUADPI / NANG2
	DO  I=1,NANG2
	   DM(1,I) = DCOS(PHIS*(I-1))
	   DM(2,I) = DSIN(PHIS*(I-1))
	ENDDO

	DELTATHETA    = QUADPI/NANG2
	SINDELTATHETA = DSIN(DELTATHETA/2)

C       XC CONTAINS EULERIAN ANGLES (THETA,PHI)
	ALLOCATE(XC(NANG2,N,2),KEY(NANG2*N),STAT=ISTAT)
	IF (ISTAT.NE.0)  THEN
           MWANT = (NANG2*N*2) + (NANG2*N) 
	   CALL ERRT(46,'XC, KEY',MWANT)
	   RETURN
	ENDIF

	DO  K=1,N
	   DO  IN=1,NANG2
C            CALCULATE 3'D COLUMN OF THE ROTATION MATRIX
             X = DM(1,IN) * DM3(:,1,K) + DM(2,IN) * DM3(:,2,K)

C            CONVERT 3'D COLUMN OF ROTATION MATRIX TO EULERIAN ANGLES
	     CALL  CONVXE(X(1),X(2),X(3))

C            XC(,,1) - THETA
C            XC(,,2) - PHI
	     XC(IN,K,:) = X(1:2)
	   ENDDO
	ENDDO

	WRITE(NOUT,*)' Total number of lines: ',N*NANG2

C       SORT BY THETA
	DO I=1,N*NANG2
	   KEY(I) = I
	ENDDO
	CALL HSORTD(XC(1,1,1),XC(1,1,2),KEY,N*NANG2)

C       CREATE TEMP KEYS FILE, EACH IMAGE HAS NANG2 KEYS
        OPEN(LOY,FILE='BP3G_KEYS',STATUS='UNKNOWN',FORM='UNFORMATTED')
	WRITE(LOY) KEY
	CLOSE(LOY)

	DEALLOCATE(KEY)

	ALLOCATE(WEIGHT(NANG2,N),STAT=ISTAT)
	IF (ISTAT.NE.0)  THEN
	   CALL ERRT(46,'WEIGHT',NANG2*N)
           RETURN
	ENDIF

	CALL  VORONOIDIAG(XC(1,1,1),XC(1,1,2),WEIGHT,NANG2,N)
	DEALLOCATE(XC)

C       RECOVER ORIGINAL ORDERING
	ALLOCATE(KEY(NANG2*N),STAT=ISTAT)
	IF (ISTAT.NE.0)  THEN
	   CALL ERRT(46,'KEY',NANG2*N)
           RETURN
	ENDIF

C       READ ORIGINAL KEYS FOR EACH IMAGE
        OPEN(LOY,FILE='BP3G_KEYS',STATUS='OLD',FORM='UNFORMATTED')
	READ(LOY)  KEY
	CLOSE(LOY,STATUS='DELETE')
	
	CALL SORTID2(KEY,WEIGHT,NANG2*N)

	DEALLOCATE(KEY)

C       OPEN NEW WEIGHTS FILE, EACH IMAGE HAS NANG2 WEIGHTS
        OPEN(LOS,FILE='BP3G_WEIGHT',STATUS='UNKNOWN',FORM='UNFORMATTED')
	DO  K=1,N
	   WRITE(LOS) (WEIGHT(IN,K),IN=1,NANG2)
	ENDDO

#ifdef NEVER
          write(6,*) ' weights for nang2',nang2
          nit = n/2
          ngo  = nang2/2
          nend = (nang2/2) + 100
          write(6,9001) (weight(IN,nit),IN=ngo,nend)
9001      format( 5(1pg12.2,' '))
#endif

	CLOSE(LOS)
	DEALLOCATE(WEIGHT)
	END


C       ---------------------- HSORTD ----------------------------------

      SUBROUTINE HSORTD( A, B, C, N)

      DOUBLE PRECISION  A(*),B(*),T,TT,X
      INTEGER C(*),Y

C     SINGLETON SORT PROGRAM TO ORDER B AND C USING A AS A KEY
C     AS OF THE PRESENT TIME (FEB. 1971) THIS IS THE FASTEST GENERAL
C     PURPOSE SORTING METHOD KNOWN.

      INTEGER IL(16), IU(16)

      M = 1
      I = 1
      J = N
    5 IF (I .GE. J) GO TO 70

C     ORDER THE TWO ENDS AND THE MIDDLE
   10 K = I
      IJ = (I + J)/2
      T = A(IJ)
      IF (A(I) .LE. T) GO TO 20
      A(IJ) = A(I)
      A(I) = T
      T = A(IJ)
      X = B(I)
      B(I) = B(IJ)
      B(IJ) = X
      Y = C(I)
      C(I) = C(IJ)
      C(IJ) = Y
   20 L = J
      IF (A(J) .GE. T) GO TO 40
      IF (A(J) .LT. A(I)) GO TO 25
      A(IJ) = A(J)
      A(J) = T
      T = A(IJ)
      X = B(IJ)
      B(IJ) = B(J)
      B(J) = X
      Y = C(IJ)
      C(IJ) = C(J)
      C(J) = Y
      GO TO 40
   25 A(IJ) = A(I)
      A(I) = A(J)
      A(J) = T
      T = A(IJ)
      X = B(J)
      B(J) = B(IJ)
      B(IJ) = B(I)
      B(I) = X
      Y = C(J)
      C(J) = C(IJ)
      C(IJ) = C(I)
      C(I) = Y
      GO TO 40

C     SPLIT THE SEQUENCE BETWEEN I AND J INTO TWO SEQUENCES.  THAT
C     SEQUENCE BETWEEN I AND L WILL CONTAIN ONLY ELEMENTS LESS THAN OR
C     EQUAL TO T, WHILE THAT BETWEEN K AND J WILL CONTAIN ONLY ELEMENTS
C     GREATER THAN T.

   30 A(L) = A(K)
      A(K) = TT
      X = B(L)
      B(L) = B(K)
      B(K) = X
      Y = C(L)
      C(L) = C(K)
      C(K) = Y
   40 L = L - 1
      IF (A(L) .GT. T) GO TO 40
      TT = A(L)
   50 K = K + 1
      IF (A(K) .LT. T) GO TO 50
      IF (K .LE. L) GO TO 30

C     SAVE THE END POINTS OF THE LONGER SEQUENCE IN IL AND IU, AND SORT
C     THE SHORTER SEQUENCE.

      IF (L - I .LE. J - K) GO TO 60
      IL(M) = I
      IU(M) = L
      I = K
      M = M + 1
      GO TO 80
   60 IL(M) = K
      IU(M) = J
      J = L
      M = M + 1
      GO TO 80

C     RETRIEVE END POINTS PREVIOUSLY SAVED AND SORT BETWEEN THEM.

   70 M = M - 1
      IF (M .EQ. 0) RETURN
      I = IL(M)
      J = IU(M)
C
C     IF THE SEQUENCE IS LONGER THAN 11 OR IS THE FIRST SEQUENCE, SORT
C     BY SPLITTING RECURSIVELY.
C
   80 IF (J - I .GE. 11) GO TO 10
      IF (I .EQ. 1) GO TO 5
C
C     IF THE SEQUENCE IS 11 OR LESS LONG, SORT IT BY A SHELLSORT.
C
      I = I - 1
   90 I = I + 1
      IF (I .EQ. J) GO TO 70
      T = A(I + 1)
      IF (A(I) .LE. T) GO TO 90
      X = B(I+1)
      Y = C(I+1)
      K = I
  100 A(K+1) = A(K)
      B(K+1) = B(K)
      C(K+1) = C(K)
      K = K - 1
      IF (T .LT. A(K)) GO TO 100
      A(K+1) = T
      B(K+1) = X
      C(K+1) = Y
      GO TO 90
C
      END


C       ---------------------- CONVXE ----------------------------------

	SUBROUTINE CONVXE(X,Y,Z)

	DOUBLE PRECISION  X,Y,Z
	DOUBLE PRECISION  THETA,PHI
	DOUBLE PRECISION  QUADPI,DGR_TO_RAD,RAD_TO_DGR

	PARAMETER (QUADPI = 3.1415926535897932384626D0)
	PARAMETER (DGR_TO_RAD = (QUADPI/180))
	PARAMETER (RAD_TO_DGR = (180.0/QUADPI))

	IF (DABS(Z) .GT. 0.999999D0) THEN
	   X = 0.0
C          90.0D0-SIGN(90.0D0,Z)
	   Y = 0.0
	ELSE
	   THETA = DACOS(Z)
	   PHI   = DSIN(THETA)            !  HERE PHI IS TEMP VARIABLE
	   PHI   = DATAN2(Y/PHI,X/PHI)
	   THETA = THETA*RAD_TO_DGR
	   PHI   = PHI*RAD_TO_DGR
	   IF (THETA .GT. 90.0D0)  THEN
	      THETA = 180.0D0-THETA
	      PHI   = PHI+180.0D0
	   ENDIF
	   X = THETA
	   Y = DMOD(PHI+360.0D0,360.0D0)
C	   Z = 0.0D0	
	 ENDIF
	 END


C       ------------------- DIVKB3 -------------------------------

        SUBROUTINE DIVKB3(X,M,ALPHA,RRR,V)

        DIMENSION  X(M,M,M)

	PARAMETER (QUADPI = 3.1415926535897932384626)
	PARAMETER (TWOPI = 2*QUADPI)

C       M IS NSAM
	ICENT = INT(M/2)+1
	WKB0  = SINH(TWOPI*ALPHA*RRR*V) / (TWOPI*ALPHA*RRR*V)

	DO K=1,M
	   TTT = REAL(IABS(K-ICENT)) / RRR

	   IF (TTT.EQ.0.0)  THEN
	      WKBK = 1.0
	   ELSEIF (TTT.LT.ALPHA) THEN
	      XX   = SQRT(1.0-(TTT/ALPHA)**2)
	      WKBK = SINH(TWOPI*ALPHA*RRR*V*XX)/
     &                   (TWOPI*ALPHA*RRR*V*XX)/WKB0
	   ELSEIF (TTT.EQ.ALPHA) THEN
	       WKBK = 1.0/WKB0
	   ELSE
	       XX   = SQRT((TTT/ALPHA)**2-1.0)
	       WKBK = SIN(TWOPI*ALPHA*RRR*V*XX)/
     &                   (TWOPI*ALPHA*RRR*V*XX)/WKB0
	   ENDIF

	   DO J=1,M
	      TTT = REAL(IABS(J-ICENT))/RRR

	      IF (TTT .EQ. 0.0) THEN
	         WKBJ = 1.0

	      ELSEIF (TTT .LT. ALPHA)  THEN
	         XX   = SQRT(1.0-(TTT/ALPHA)**2)
	         WKBJ = SINH(TWOPI*ALPHA*RRR*V*XX)/
     &                      (TWOPI*ALPHA*RRR*V*XX)/WKB0

	      ELSEIF (TTT .EQ. ALPHA)  THEN
	         WKBJ = 1.0/WKB0

	      ELSE
	         XX   = SQRT((TTT/ALPHA)**2-1.0)
	         WKBJ = SIN(TWOPI*ALPHA*RRR*V*XX)/
     &                     (TWOPI*ALPHA*RRR*V*XX)/WKB0
	      ENDIF

	      DO I=1,M
	         TTT = REAL(IABS(I-ICENT))/RRR

	         IF (TTT .EQ. 0.0)  THEN
	            WKBI = 1.0

	         ELSEIF (TTT .LT. ALPHA)  THEN
	            XX   = SQRT(1.0-(TTT/ALPHA)**2)
	            WKBI = SINH(TWOPI*ALPHA*RRR*V*XX)/
     &                         (TWOPI*ALPHA*RRR*V*XX)/WKB0

	         ELSEIF (TTT .EQ. ALPHA)  THEN
	            WKBI = 1.0/WKB0

	         ELSE
	            XX   = SQRT((TTT/ALPHA)**2-1.0)
	            WKBI = SIN(TWOPI*ALPHA*RRR*V*XX)/
     &                        (TWOPI*ALPHA*RRR*V*XX)/WKB0
	         ENDIF

	         X(I,J,K) = X(I,J,K) / ABS(WKBI*WKBJ*WKBK)
	      ENDDO
           ENDDO
	ENDDO
        END

C     -------------------------- SORTID2 ------------------------------

      SUBROUTINE SORTID2 ( A, B, N)

      INTEGER           A(N),T,TT
      INTEGER           IL(16), IU(16)
      DOUBLE PRECISION  B(N),X

      M = 1
      I = 1
      J = N
    5 IF (I .GE. J) GO TO 70

C    ORDER THE TWO ENDS AND THE MIDDLE

   10 K = I
      IJ = (I + J)/2
      T = A(IJ)
      IF (A(I) .LE. T) GO TO 20
      A(IJ) = A(I)
      A(I) = T
      T = A(IJ)
      X = B(I)
      B(I) = B(IJ)
      B(IJ) = X
   20 L = J
      IF (A(J) .GE. T) GO TO 40
      IF (A(J) .LT. A(I)) GO TO 25
      A(IJ) = A(J)
      A(J) = T
      T = A(IJ)
      X = B(IJ)
      B(IJ) = B(J)
      B(J) = X
      GO TO 40

   25 A(IJ) = A(I)
      A(I) = A(J)
      A(J) = T
      T = A(IJ)
      X = B(J)
      B(J) = B(IJ)
      B(IJ) = B(I)
      B(I) = X
      GO TO 40

C     SPLIT THE SEQUENCE BETWEEN I AND J INTO TWO SEQUENCES.  THAT
C     SEQUENCE BETWEEN I AND L WILL CONTAIN ONLY ELEMENTS LESS THAN OR
C     EQUAL TO T, WHILE THAT BETWEEN K AND J WILL CONTAIN ONLY ELEMENTS
C     GREATER THAN T.

   30 A(L) = A(K)
      A(K) = TT
      X = B(L)
      B(L) = B(K)
      B(K) = X
   40 L = L - 1
      IF (A(L) .GT. T) GO TO 40
      TT = A(L)
   50 K = K + 1
      IF (A(K) .LT. T) GO TO 50
      IF (K .LE. L) GO TO 30

C     SAVE THE END POINTS OF THE LONGER SEQUENCE IN IL AND IU, AND SORT
C     THE SHORTER SEQUENCE.

      IF (L - I .LE. J - K) GO TO 60
      IL(M) = I
      IU(M) = L
      I = K
      M = M + 1
      GO TO 80

   60 IL(M) = K
      IU(M) = J
      J = L
      M = M + 1
      GO TO 80

C     RETRIEVE END POINTS PREVIOUSLY SAVED AND SORT BETWEEN THEM.

   70 M = M - 1
      IF (M .EQ. 0) RETURN
      I = IL(M)
      J = IU(M)

C     IF THE SEQUENCE IS LONGER THAN 11 OR IS THE FIRST SEQUENCE, SORT
C     BY SPLITTING RECURSIVELY.

   80 IF (J - I .GE. 11) GO TO 10
      IF (I .EQ. 1) GO TO 5

C    IF THE SEQUENCE IS 11 OR LESS LONG, SORT IT BY A SHELLSORT.

      I = I - 1
   90 I = I + 1
      IF (I .EQ. J) GO TO 70
      T = A(I + 1)
      IF (A(I) .LE. T) GO TO 90
      X = B(I+1)
      K = I
  100 A(K+1) = A(K)
      B(K+1) = B(K)
      K = K - 1
      IF (T .LT. A(K)) GO TO 100
      A(K+1) = T
      B(K+1) = X
      GO TO 90

      END



C       ------------------ WGS2 ----------------------------------

        SUBROUTINE WGS2(X,N,N2)

        COMPLEX X(0:N2,-N2:N2-1,-N2:N2-1)

	DO J=-N2,N2-1
	   DO I=0,N2
	      IF (I.EQ.0 .AND. J.EQ.0)  THEN
	         DO K=-N2,N2-1
	            X(I,J,K) = X(I,J,K)*ABS(K)
	         ENDDO
	      ELSE
	         DO K=-N2,N2-1
	            W = SQRT(REAL(I*I+J*J))*SQRT(REAL(I*I+J*J+K*K))
	            X(I,J,K) = X(I,J,K)*W
	         ENDDO
	      ENDIF
	   ENDDO
	ENDDO
	END


C       ------------------ VORONOIDIAG ----------------------------------

        SUBROUTINE VORONOIDIAG(THETA,PHI,WEIGHT,NANG2,NN)

	DOUBLE PRECISION  THETA(NANG2*NN),PHI(NANG2*NN)
	DOUBLE PRECISION  WEIGHT(NANG2*NN)
	INTEGER, DIMENSION(:), ALLOCATABLE :: LBAND
	REAL, DIMENSION(:), ALLOCATABLE    :: TS,AAT
	DOUBLE PRECISION AA,QUADPI,ACUM
	LOGICAL  LAST

        PARAMETER  (QUADPI = 3.1415926535897932384626D0)
        PARAMETER  (DGR_TO_RAD = (QUADPI/180))
        PARAMETER  (RAD_TO_DGR = (180.0/QUADPI))

	N = NANG2 * NN
	CALL GETTHREADS(NUMTH)

	NBT = MAX(NINT(SQRT(REAL(N/500))),3)

	ALLOCATE(AAT(NUMTH), TS(NBT),LBAND(NBT),STAT=ISTAT)
	IF (ISTAT .NE. 0)  THEN
          MWANT = NUMTH + NBT + NBT
          CALL ERRT(46,' NBAND',MWANT)
	  STOP
	ENDIF

	NBAND = NBT
	DO  WHILE  (NBAND > 0)

c	   PRINT  *,' NBAND=',NBAND

C          TS CONTAINS ANGLES SELECTED SUCH THAT THE NUMBER OF NODES IN EACH BAND SHOULD
C          BE THE SAME
C          TS(1) - LIMIT OF FIRST BAND, CONTAINS ANGLES FROM 0 TO TS(1)
C          TS(NBAND) - IS ALWAYS 90
	   CALL ANGSTEP(TS,NBAND)

	   L=1
	   DO  I=1,N
	      IF (THETA(I) .GT. TS(L))  THEN
	         LBAND(L) = I
	         L        = L + 1
	         IF (L .GT. NBAND) STOP
	      ENDIF
	   ENDDO

	   LBAND(L) = N + 1
c	   PRINT  *,(LBAND(I),I=1,L)

C          THE NODES ARE MARKED BY THREE POINTERS INDICATING THREE 
C          REGIONS: IN VORONOI THE STRUCTURE WILL BE AS FOLLOWS:
C          1      - LOW-1     - LOW MARGIN
C          LOW    - MEDIUM-1  - REGION OF INTEREST, AREAS ARE CALCULATED FOR THIS REGION
C          MEDIUM - LHIGH     - HIGH MARGIN

	   ACUM = 0.0

	   DO IT=L,1,-NUMTH

C              THIS SEGFAULTS IF RUN IN PARALLEL June 07 aleith
cc$omp         parallel do private(i,last,lb,low,medium,lhigh,lbw,lenw,
cc$omp&                             area,aa,acum)
cc$omp&        reduction(+:asum),schedule(static)
cC             added aa, acum  leith jun 07
	      DO  I=IT,MAX(1,IT-NUMTH+1),-1
	         IF (I == L)  THEN
	            LAST = .TRUE.
	         ELSE
	            LAST = .FALSE.
	         ENDIF

                 IF (L == 1)  THEN
                    LB     = 1
                    LOW    = 1
                    MEDIUM = N+1
                    LHIGH  = N-LB+1
                    LBW    =   1
                 ELSEIF (I == 1)  THEN
                    LB     = 1
                    LOW    = 1
                    MEDIUM = LBAND(1)
                    LHIGH  = LBAND(2)-1
                    LBW    = 1
                 ELSEIF (I == L)  THEN
                    IF (L == 2)  THEN
                       LB = 1
                    ELSE
                       LB  = LBAND(L-2)
                    ENDIF
                    LOW    = LBAND(L-1) -LB + 1
                    MEDIUM = LBAND(L) - LB+1
                    LHIGH  = N-LB+1
                    LBW    = LBAND(I-1)
                 ELSE
                    IF (I == 2)  THEN
                       LB = 1
                    ELSE
                       LB = LBAND(I-2)
                    ENDIF
                    LOW    = LBAND(I-1)-LB+1
                    MEDIUM = LBAND(I)-LB+1
                    LHIGH  = LBAND(I+1)-1-LB+1
                    LBW    = LBAND(I-1)
                 ENDIF

                 LENW = MEDIUM - LOW
c	         print  *,lbw,lenw,LB,LOW,MEDIUM,LHIGH
c	         print  *,LOW+LB-1,MEDIUM+LB-1
c	         PRINT  *,'  SECTION NUMBER',I

	         CALL VORONOI(PHI(LB),THETA(LB),WEIGHT(LBW),
     &		              LENW,LOW,MEDIUM,LHIGH,LAST)

C                TEST THE AREAS IN ALL SECTIONS
                 IF (NBAND > 1)  THEN
                    IF (I == 1)  THEN
                       AREA = QUADPI*2.0*(1.0-COS(TS(1)*DGR_TO_RAD))
                    ELSE
                       AREA = QUADPI*2.0*(COS(TS(I-1)*DGR_TO_RAD) -
     &                        COS(TS(I)*DGR_TO_RAD))
                    ENDIF

	            AA   = SUM(WEIGHT(LBW:LBW+LENW-1))
	            ACUM = ACUM + AA   
	            AAT(I-MAX(1, IT-NUMTH+1)+1) = AA / AREA
	         ENDIF
	      ENDDO     !END OF PARALLEL LOOP

 	      DO I=IT,MAX(1,IT-NUMTH+1),-1
C                WRITE (6,121) I,AAT(I-MAX(1,IT-NUMTH+1)+1)
  121            FORMAT ('  Sum of Voronoi region areas relative ',
     &                  'to surface area of ',I4,'th section = ',F15.12)

	         IF (ABS(AAT(I-MAX(1,IT-NUMTH+1)+1)-1.0) > 2.0D-2) THEN
	            NBAND = MAX(0,MIN(NINT(REAL(NBAND)*0.75),NBAND-1))
	            GOTO  128
	         ENDIF
	      ENDDO
	   ENDDO  ! END OF LOOP OVER BANDS

	   ACUM = ACUM / QUADPI / 2.0
c          WRITE (6,120) ACUM
  120      FORMAT (//,'     Sum of Voronoi region areas relative ',
     &             'to total surface area = ',F15.12)
	   EXIT

C          DO NOT CHECK THE SUM - IF ALL INDIVIDUAL HAVE SMALL ERRORS, THE SUM WILL HAVE A SMALL ERROR
C	   IF (DABS(ACUM-1.0) > 1.0D-3) THEN
C	      NBAND = MAX(1,MIN(NINT(REAL(NBAND)*0.9),NBAND-1))
C	      GOTO  128
C          ELSE
C	      EXIT
c          ENDIF
128	   CONTINUE
	ENDDO

c       WRITE (6,120) SUM(WEIGHT(1:ND2))/(16.D0*ATAN(1.D0)),
c     &		      MAXVAL(WEIGHT(1:ND2))

	DEALLOCATE(AAT,TS,LBAND)
	END



C       ------------------ VORONOI ----------------------------------

	SUBROUTINE VORONOI(PHI,THETA,WEIGHT,LENW,LOW,MEDIUM,NT,LAST)

	DOUBLE PRECISION  WEIGHT(LENW)

        INTEGER IER, IX, IY, IZ, K, LNEW, LWK, N, ND2, NTMX, NT6
        DOUBLE PRECISION  A, AMAX, ASUM
        DOUBLE PRECISION  AREAV
        DOUBLE PRECISION  PHI(NT), THETA(NT), TOL
	INTEGER, DIMENSION(:), ALLOCATABLE :: LIST,LPTR,LEND,IWK,KEY
	DOUBLE PRECISION, DIMENSION(:), ALLOCATABLE   :: DS
	DOUBLE PRECISION, DIMENSION(:,:), ALLOCATABLE :: XYZ
	INTEGER, DIMENSION(:), ALLOCATABLE :: LCNT,INDX,GOOD
	LOGICAL  LAST

C       IF LAST=.TRUE. THE LAST SEGMENT OF THE COORDINATES SHOULD BE 
C       ADDED TO THE SET AND N SHOULD BE EXTENDED APPROPRIATELY
	IF (LAST)  THEN
	  IF (MEDIUM > NT)  THEN
C            THERE IS ONLY ONE REGION, THUS MEDIUM>NT AND N HAS TO 
C            BE SIMPLY DOUBLED.
	     N = NT+NT
	  ELSE
	     N = NT+NT-MEDIUM+1
	  ENDIF
	ELSE
	   N = NT
	ENDIF

	TOL = 1.0D-8
	NT6 = 6 * N

	ALLOCATE(LIST(NT6),LPTR(NT6),LEND(N),IWK(N),GOOD(N),
     &		 DS(N), KEY(N),INDX(N), LCNT(N), XYZ(N,3),
     &		 STAT=ISTAT)
	IF (ISTAT .NE. 0)  THEN
           MWANT = 2*NT6 + (10*N)
           CALL ERRT(46,'BP 3G, LIST...',MWANT)
	   STOP
	ENDIF

C       ALLOCATE NEW MEMORY FOR X,Y,Z, SHUFFLE KEY, COPY FROM XT TO X,
C       DO NOT RETURN X,Y,Z, THEY WILL BE WASTED.  IF THERE ARE TO BE 
C       RETURNED, THE CODE GETS TOO COMPLICATED.
C       ON INPUT Y IS PHI, X IS THETA
	XYZ(1:NT,1) = THETA
	XYZ(1:NT,2) = PHI

	IF (LAST)  THEN
C         ADD THE LAST N-MEDIUM+1 COORDINATES AS MIRRORED DIRECTIONS,
C         I.E., THETA'=180-THETA, PHI'=PHI+180
	  DO  I=NT+1,N
	     XYZ(I,1) = 180.0 - XYZ(2*NT-I+1,1)
	     XYZ(I,2) = 180.0 + XYZ(2*NT-I+1,2)
	  ENDDO
	ENDIF

C       RANDOMIZES ORDER OF XYZ and KEYs
	CALL DISORDER2(XYZ,KEY,N)

C       CONVERT TO X,Y,Z COORDINATES
	CALL  CONVXYZ(XYZ(1,1),XYZ(1,2),XYZ(1,3),N)

C       CHECK FIRST THREE ENTRIES.  THEY SHOULD BE DIFFERENT.  
C       IF NOT, DO ADDITIONAL SHUFFLING.
5421	DO  K=1,2
	 DO  I=K+1,3
	  IF (DOT_PRODUCT(XYZ(K,:),XYZ(I,:)) > (1.0D0-TOL))  THEN
C	     print  *,' flip2 ',k,i
	     CALL  FLIP23(K,XYZ,KEY,N)
	     GOTO 5421
	  ENDIF
	 ENDDO
       ENDDO

C      CREATE TRIANGULATION
       CALL TRMSH3(N,TOL,XYZ(1,1),XYZ(1,2),XYZ(1,3),NNOUT,LIST,
     &             LPTR,LEND,LNEW,INDX,LCNT,IWK,GOOD,DS,IER)

       MDUP = N - NNOUT
c      write(6,*)'  Number of duplicated: ',MDUP

       IF (IER .EQ. -2) THEN
          WRITE (6,510)
          write(6,5999) ((xyz(ii,iii),ii=1,3),iii=1,3)
5999      format (3(1pg12.3,' '))
          GOTO 5421   ! Added aleith Jun 07 to overcome colinear halts

      ELSEIF (IER .GT. 0) THEN
          WRITE (6,515)
          STOP
      ENDIF

C     CREATE LIST OF UNIQUE NODES GOOD, THE NUMBERS REFER TO LOCATIONS 
C     ON THE FULL LIST
C     INDX CONTAINS NODE NUMBERS FROM THE SQUEEZED LIST
      ND = 0
      DO  K=1,N
	  IF (INDX(K) > 0)  THEN
	     ND       = ND+1
	     GOOD(ND) = K
	  ENDIF
      ENDDO

C     COMPUTE THE VORONOI REGION AREAS.
      DO I = 1,NNOUT
         K = GOOD(I)
C        CHECK WHETHER KEY(K) IS WITHIN THE RANGE
C        AND WHETHER K IS A DUPLICATED, THUS NONEXISTENT ENTRY
         IF (KEY(K) >= LOW .AND. KEY(K) < MEDIUM)  THEN
C 
C           CALCULATE THE AREA
            A = AREAV(I,NNOUT,XYZ(1,1),XYZ(1,2),XYZ(1,3),
     &                 LIST,LPTR,LEND,IER)
            IF (IER /= 0) THEN
C              WRITE (*,520) IER
C              STOP
C              WE SET THE WEIGHT TO -1, THIS WILL SIGNAL THE ERROR IN THE CALLING
C              PROGRAM, AS THE AREA WILL TURN OUT INCORRECT
	       WEIGHT(KEY(K)-LOW+1) = -1.0D0
            ELSE
C              ASSIGN THE WEIGHT
               WEIGHT(KEY(K)-LOW+1) = A / LCNT(I)
            ENDIF
         ENDIF
      ENDDO

C     FILL OUT THE DUPLICATED WEIGHTS
      DO I = 1,N
	MT = -INDX(I)
	IF (MT > 0)  THEN
	   K = GOOD(MT)
C          THIS IS A DUPLICATED ENTRY, GET ALREADY CALCULATED
C          WEIGHT AND ASSIGN IT.
           IF (KEY(I) >= LOW .AND. KEY(I) < MEDIUM)  THEN
C             IS IT ALREADY CALCULATED WEIGHT??
              IF (KEY(K) >= LOW .AND. KEY(K) < MEDIUM)  THEN
                 WEIGHT(KEY(I)-LOW+1) = WEIGHT(KEY(K)-LOW+1)
	      ELSE
C                NO, THE WEIGHT IS FROM THE OUTSIDE OF VALID REGION, CALCULATE IT ANYWAY
                 A = AREAV(MT,NNOUT,XYZ(1,1),XYZ(1,2),XYZ(1,3),
     &                     LIST,LPTR,LEND,IER)
                 IF (IER /= 0) THEN
C                   WRITE (*,520) IER
C                   STOP
                    WEIGHT(KEY(I)-LOW+1) = -1.0D0
                 ELSE
                    WEIGHT(KEY(I)-LOW+1) = A/LCNT(MT)
                 ENDIF
              ENDIF
           ENDIF
        ENDIF
      ENDDO    ! END OF:  DO I = 1,N

      DEALLOCATE(LIST,LPTR,LEND,IWK,GOOD,DS,KEY,INDX,LCNT,XYZ)
      RETURN

C     ERROR MESSAGE FORMATS:
  510 FORMAT (//5X,'*** Error in TRMESH: first three nodes  collinear'/)
  515 FORMAT (//5X,'*** Error in TRMESH: duplicate nodes encountered'/)
  520 FORMAT (//5X,'*** Error in AREAV:  IER = ',I1,' ***'/)
  530 FORMAT (//5X,'*** Error in DELNOD: IER = ',I1,' ***'/)

      END


C       ------------------ ANGSTEP ----------------------------------

	SUBROUTINE ANGSTEP(THETAST,N)

        PARAMETER  (QUADPI = 3.1415926535897932384626)
        PARAMETER  (RAD_TO_DGR = (180.0/QUADPI))
	DIMENSION  THETAST(N)

C       HERE THE EQUATION FOLLOWS FROM THE INTEGRAL SSIN(THETA)DTHETA=1/N
C       I.E., EQUAL AREA BANDS 

	IF (N > 1)  THEN
	   T1 = 0.
           DO I=1,N-1
              TMP        = COS(T1)-1./REAL(N)
              T2         = ACOS(SIGN(AMIN1(1.0,ABS(TMP)),TMP))
              THETAST(I) = T2*RAD_TO_DGR
              T1         = T2
           ENDDO
	ENDIF
	THETAST(N) = 90.0
	END

C       ------------------ DISORDER2 ----------------------------------

	SUBROUTINE DISORDER2(XYZ,KEY,NN)

	DOUBLE PRECISION  XYZ(NN,2),TMP(2)
	INTEGER           KEY(NN)

	DO  I=1,NN
           KEY(I) = I
	ENDDO

	DO  I=1,NN
           CALL  RANDOM_NUMBER(HARVEST=RANDOM)
           K = MIN(NINT(RANDOM*NN+0.5), NN)
            if (k .le. 0) then
               write(6,*) ' k < 1 in disorder2',k
               stop
           endif 

C          INTERCHANGE
           IT       = KEY(K)
           KEY(K)   = KEY(I)
           KEY(I)   = IT

           TMP      = XYZ(K,:)
           XYZ(K,:) = XYZ(I,:)
           XYZ(I,:) = TMP
	ENDDO
	END

C       ------------------ DISORDER ----------------------------------


	SUBROUTINE DISORDER(X,Y,Z,KEY,NN)

	DOUBLE PRECISION  X(NN),Y(NN),Z(NN),TMP
	INTEGER           KEY(NN)

	DO  I=1,NN
           KEY(I)=I
	ENDDO

	DO  I=1,NN
           CALL  RANDOM_NUMBER(HARVEST=RANDOM)
           K      = MIN(NINT(RANDOM*NN+0.5),NN)

C          INTERCHANGE
           IT     = KEY(K)
           KEY(K) = KEY(I)
           KEY(I) = IT

           TMP    = X(K)
           X(K)   = X(I)
           X(I)   = TMP

           TMP    = Y(K)
           Y(K)   = Y(I)
           Y(I)   = TMP

           TMP    = Z(K)
           Z(K)   = Z(I)
           Z(I)   = TMP
	ENDDO
	END

C       ------------------ FLIP23 ----------------------------------

	SUBROUTINE FLIP23(I,XYZ,KEY,NN)

	 DOUBLE PRECISION  XYZ(NN,3),TMP(3)
	 INTEGER           KEY(NN)

	 CALL  RANDOM_NUMBER(HARVEST=RANDOM)

	 K        = MIN(NINT(RANDOM*NN+0.5),NN)

C        INTERCHANGE
	 IT       = KEY(K)
	 KEY(K)   = KEY(I)
	 KEY(I)   = IT

	 TMP      = XYZ(K,:)
	 XYZ(K,:) = XYZ(I,:)
	 XYZ(I,:) = TMP

	 END


C       ------------------ CONVXYZ ----------------------------------

	SUBROUTINE CONVXYZ(X,Y,Z,N)

C       On input Y is PHI, X is THETA
	DOUBLE PRECISION  X(N),Y(N),Z(N)
	DOUBLE PRECISION  COSTHETA,SINTHETA,COSPHI,SINPHI
	DOUBLE PRECISION  QUADPI,DGR_TO_RAD,RAD_TO_DGR

	PARAMETER (QUADPI = 3.141592653589793238462643383279502884197D0)
	PARAMETER (DGR_TO_RAD = (QUADPI/180))
	PARAMETER (RAD_TO_DGR = (180.0/QUADPI))

	DO I=1,N
	   COSPHI = DCOS(Y(I)*DGR_TO_RAD)
	   SINPHI = DSIN(Y(I)*DGR_TO_RAD)
	   IF (DABS(X(I)-90.0D0) .LT. 1.0D-5)  THEN
              X(I)     = COSPHI
              Y(I)     = SINPHI
              Z(I)     = 0.0D0
	   ELSE
              COSTHETA = DCOS(X(I)*DGR_TO_RAD)
              SINTHETA = DSIN(X(I)*DGR_TO_RAD)
              X(I)     = COSPHI*SINTHETA
              Y(I)     = SINPHI*SINTHETA
              Z(I)     = COSTHETA
	   ENDIF
	ENDDO
	END

C       ------------------ TRMSH3 ----------------------------------


      SUBROUTINE TRMSH3(N0,TOL, X,Y,Z, N,LIST,LPTR,LEND,
     &                   LNEW,INDX,LCNT,NEAR,NEXT,DIST,IER)

      INTEGER N0, N, LIST(*), LPTR(*), LEND(N0), LNEW,
     &        INDX(N0), LCNT(*),NEAR(N0), NEXT(N0), IER
      DOUBLE PRECISION TOL, X(N0), Y(N0), Z(N0), DIST(N0)

C***********************************************************
C
C                                              From STRIPACK
C                                            Robert J. Renka
C                                  Dept. of Computer Science
C                                       Univ. of North Texas
C                                           renka@cs.unt.edu
C                                                   01/20/03
C
C   This is an alternative to TRMESH with the inclusion of
C an efficient means of removing duplicate or nearly dupli-
C cate nodes.
C
C   This subroutine creates a Delaunay triangulation of a
C set of N arbitrarily distributed points, referred to as
C nodes, on the surface of the unit sphere.  Refer to Sub-
C routine TRMESH for definitions and a list of additional
C subroutines.  This routine is an alternative to TRMESH
C with the inclusion of an efficient means of removing dup-
C licate or nearly duplicate nodes.
C
C   The algorithm has expected time complexity O(N*log(N))
C for random nodal distributions.
C
C
C On input:
C
C       N0 = Number of nodes, possibly including duplicates.
C            N0 .GE. 3.
C
C       TOL = Tolerance defining a pair of duplicate nodes:
C             bound on the deviation from 1 of the cosine of
C             the angle between the nodes.  Note that
C             |1-cos(A)| is approximately A*A/2.
C
C The above parameters are not altered by this routine.
C
C       X,Y,Z = Arrays of length at least N0 containing the
C               Cartesian coordinates of nodes.  (X(K),Y(K),
C               Z(K)) is referred to as node K, and K is re-
C               ferred to as a nodal index.  It is required
C               that X(K)**2 + Y(K)**2 + Z(K)**2 = 1 for all
C               K.  The first three nodes must not be col-
C               linear (lie on a common great circle).
C
C       LIST,LPTR = Arrays of length at least 6*N0-12.
C
C       LEND = Array of length at least N0.
C
C       INDX = Array of length at least N0.
C
C       LCNT = Array of length at least N0 (length N is
C              sufficient).
C
C       NEAR,NEXT,DIST = Work space arrays of length at
C                        least N0.  The space is used to
C                        efficiently determine the nearest
C                        triangulation node to each un-
C                        processed node for use by ADDNOD.
C
C On output:
C
C       N = Number of nodes in the triangulation.  3 .LE. N
C           .LE. N0, or N = 0 if IER < 0.
C
C       X,Y,Z = Arrays containing the Cartesian coordinates
C               of the triangulation nodes in the first N
C               locations.  The original array elements are
C               shifted down as necessary to eliminate dup-
C               licate nodes.
C
C       LIST = Set of nodal indexes which, along with LPTR,
C              LEND, and LNEW, define the triangulation as a
C              set of N adjacency lists -- counterclockwise-
C              ordered sequences of neighboring nodes such
C              that the first and last neighbors of a bound-
C              ary node are boundary nodes (the first neigh-
C              bor of an interior node is arbitrary).  In
C              order to distinguish between interior and
C              boundary nodes, the last neighbor of each
C              boundary node is represented by the negative
C              of its index.
C
C       LPTR = Set of pointers (LIST indexes) in one-to-one
C              correspondence with the elements of LIST.
C              LIST(LPTR(I)) indexes the node which follows
C              LIST(I) in cyclical counterclockwise order
C              (the first neighbor follows the last neigh-
C              bor).
C
C       LEND = Set of pointers to adjacency lists.  LEND(K)
C              points to the last neighbor of node K for
C              K = 1,...,N.  Thus, LIST(LEND(K)) < 0 if and
C              only if K is a boundary node.
C
C       LNEW = Pointer to the first empty location in LIST
C              and LPTR (list length plus one).  LIST, LPTR,
C              LEND, and LNEW are not altered if IER < 0,
C              and are incomplete if IER > 0.
C
C       INDX = Array of output (triangulation) nodal indexes
C              associated with input nodes.  For I = 1 to
C              N0, INDX(I) is the index (for X, Y, and Z) of
C              the triangulation node with the same (or
C              nearly the same) coordinates as input node I.
C
C       LCNT = Array of integer weights (counts) associated
C              with the triangulation nodes.  For I = 1 to
C              N, LCNT(I) is the number of occurrences of
C              node I in the input node set, and thus the
C              number of duplicates is LCNT(I)-1.
C
C       NEAR,NEXT,DIST = Garbage.
C
C       IER = Error indicator:
C             IER =  0 if no errors were encountered.
C             IER = -1 if N0 < 3 on input.
C             IER = -2 if the first three nodes are
C                      collinear.
C             IER = -3 if Subroutine ADDNOD returns an error
C                      flag.  This should not occur.
C
C Modules required by TRMSH3:  ADDNOD, BDYADD, COVSPH,
C                                INSERT, INTADD, JRAND,
C                                LEFT, LSTPTR, STORE, SWAP,
C                                SWPTST, TRFIND
C
C Intrinsic function called by TRMSH3:  ABS
C
C***********************************************************

      INTEGER I, I0, J, KT, KU, LP, LPL, NEXTI, NKU
      LOGICAL LEFT
      DOUBLE PRECISION D, D1, D2, D3

C Local parameters:
C D =        (Negative cosine of) distance from node KT to
C              node I
C D1,D2,D3 = Distances from node KU to nodes 1, 2, and 3,
C              respectively
C I,J =      Nodal indexes
C I0 =       Index of the node preceding I in a sequence of
C              unprocessed nodes:  I = NEXT(I0)
C KT =       Index of a triangulation node
C KU =       Index of an unprocessed node and DO-loop index
C LP =       LIST index (pointer) of a neighbor of KT
C LPL =      Pointer to the last neighbor of KT
C NEXTI =    NEXT(I)
C NKU =      NEAR(KU)

      IF (N0 .LT. 3) THEN
         N   = 0
         IER = -1
         RETURN
      ENDIF

C     STORE THE FIRST TRIANGLE IN THE LINKED LIST.
      IF ( .NOT. LEFT (X(1),Y(1),Z(1),X(2),Y(2),Z(2),
     .                 X(3),Y(3),Z(3)) ) THEN

C       THE FIRST TRIANGLE IS (3,2,1) = (2,1,3) = (1,3,2).
        LIST(1) = 3
        LPTR(1) = 2
        LIST(2) = -2
        LPTR(2) = 1
        LEND(1) = 2

        LIST(3) = 1
        LPTR(3) = 4
        LIST(4) = -3
        LPTR(4) = 3
        LEND(2) = 4

        LIST(5) = 2
        LPTR(5) = 6
        LIST(6) = -1
        LPTR(6) = 5
        LEND(3) = 6

      ELSEIF ( .NOT. LEFT(X(2),Y(2),Z(2),X(1),Y(1),Z(1),
     .                    X(3),Y(3),Z(3)) ) THEN

C       The first triangle is (1,2,3):  3 Strictly Left 1->2,
C       i.e., node 3 lies in the left hemisphere defined by
C       arc 1->2.

        LIST(1) = 2
        LPTR(1) = 2
        LIST(2) = -3
        LPTR(2) = 1
        LEND(1) = 2
C
        LIST(3) = 3
        LPTR(3) = 4
        LIST(4) = -1
        LPTR(4) = 3
        LEND(2) = 4
C
        LIST(5) = 1
        LPTR(5) = 6
        LIST(6) = -2
        LPTR(6) = 5
        LEND(3) = 6
      ELSE

C       THE FIRST THREE NODES ARE COLLINEAR.
        N   = 0
        IER = -2
        RETURN
      ENDIF

C Initialize LNEW, INDX, and LCNT, and test for N = 3.

      LNEW = 7
      INDX(1) = 1
      INDX(2) = 2
      INDX(3) = 3
      LCNT(1) = 1
      LCNT(2) = 1
      LCNT(3) = 1
      IF (N0 .EQ. 3) THEN
         N = 3
         IER = 0
         RETURN
      ENDIF

C A NEAREST-NODE DATA STRUCTURE (NEAR, NEXT, AND DIST) IS
C   USED TO OBTAIN AN EXPECTED-TIME (N*LOG(N)) INCREMENTAL
C   ALGORITHM BY ENABLING CONSTANT SEARCH TIME FOR LOCATING
C   EACH NEW NODE IN THE TRIANGULATION.
C
C FOR EACH UNPROCESSED NODE KU, NEAR(KU) IS THE INDEX OF THE
C   TRIANGULATION NODE CLOSEST TO KU (USED AS THE STARTING
C   POINT FOR THE SEARCH IN SUBROUTINE TRFIND) AND DIST(KU)
C   IS AN INCREASING FUNCTION OF THE ARC LENGTH (ANGULAR
C   DISTANCE) BETWEEN NODES KU AND NEAR(KU):  -COS(A) FOR
C   ARC LENGTH A.
C
C SINCE IT IS NECESSARY TO EFFICIENTLY FIND THE SUBSET OF
C   UNPROCESSED NODES ASSOCIATED WITH EACH TRIANGULATION
C   NODE J (THOSE THAT HAVE J AS THEIR NEAR ENTRIES), THE
C   SUBSETS ARE STORED IN NEAR AND NEXT AS FOLLOWS:  FOR
C   EACH NODE J IN THE TRIANGULATION, I = NEAR(J) IS THE
C   FIRST UNPROCESSED NODE IN J'S SET (WITH I = 0 IF THE
C   SET IS EMPTY), L = NEXT(I) (IF I > 0) IS THE SECOND,
C   NEXT(L) (IF L > 0) IS THE THIRD, ETC.  THE NODES IN EACH
C   SET ARE INITIALLY ORDERED BY INCREASING INDEXES (WHICH
C   MAXIMIZES EFFICIENCY) BUT THAT ORDERING IS NOT MAIN-
C   TAINED AS THE DATA STRUCTURE IS UPDATED.

C     INITIALIZE THE DATA STRUCTURE FOR THE SINGLE TRIANGLE.
      NEAR(1) = 0
      NEAR(2) = 0
      NEAR(3) = 0
      DO 1 KU = N0,4,-1
        D1 = -(X(KU)*X(1) + Y(KU)*Y(1) + Z(KU)*Z(1))
        D2 = -(X(KU)*X(2) + Y(KU)*Y(2) + Z(KU)*Z(2))
        D3 = -(X(KU)*X(3) + Y(KU)*Y(3) + Z(KU)*Z(3))
        IF (D1 .LE. D2  .AND.  D1 .LE. D3) THEN
           NEAR(KU) = 1
           DIST(KU) = D1
           NEXT(KU) = NEAR(1)
           NEAR(1) = KU
        ELSEIF (D2 .LE. D1  .AND.  D2 .LE. D3) THEN
           NEAR(KU) = 2
           DIST(KU) = D2
           NEXT(KU) = NEAR(2)
           NEAR(2) = KU
        ELSE
           NEAR(KU) = 3
           DIST(KU) = D3
           NEXT(KU) = NEAR(3)
           NEAR(3) = KU
        ENDIF
    1   CONTINUE

C     LOOP ON UNPROCESSED NODES KU.  KT IS THE NUMBER OF NODES
C     IN THE TRIANGULATION, AND NKU = NEAR(KU).

      KT = 3
      DO 6 KU = 4,N0
        NKU = NEAR(KU)

C       REMOVE KU FROM THE SET OF UNPROCESSED NODES ASSOCIATED
C       WITH NEAR(KU).

        I = NKU
        IF (NEAR(I) .EQ. KU) THEN
          NEAR(I) = NEXT(KU)
        ELSE
          I  = NEAR(I)
    2     I0 = I
            I = NEXT(I0)
            IF (I .NE. KU) GO TO 2
          NEXT(I0) = NEXT(KU)
        ENDIF
        NEAR(KU) = 0

C       Bypass duplicate nodes.
        IF (DIST(KU) .LE. TOL-1.D0) THEN
          INDX(KU)  = -NKU
          LCNT(NKU) = LCNT(NKU) + 1
          GO TO 6
        ENDIF

C       Add a new triangulation node KT with LCNT(KT) = 1.
        KT       = KT + 1
        X(KT)    = X(KU)
        Y(KT)    = Y(KU)
        Z(KT)    = Z(KU)
        INDX(KU) = KT
        LCNT(KT) = 1
        CALL ADDNOD (NKU,KT,X,Y,Z, LIST,LPTR,LEND,LNEW, IER)
        IF (IER .NE. 0) THEN
          N = 0
          IER = -3
          RETURN
        ENDIF
C
C Loop on neighbors J of node KT.
C
        LPL = LEND(KT)
        LP = LPL
    3   LP = LPTR(LP)
          J = ABS(LIST(LP))
C
C Loop on elements I in the sequence of unprocessed nodes
C   associated with J:  KT is a candidate for replacing J
C   as the nearest triangulation node to I.  The next value
C   of I in the sequence, NEXT(I), must be saved before I
C   is moved because it is altered by adding I to KT's set.
C
          I = NEAR(J)
    4     IF (I .EQ. 0) GO TO 5
          NEXTI = NEXT(I)
C
C Test for the distance from I to KT less than the distance
C   from I to J.
C
          D = -(X(I)*X(KT) + Y(I)*Y(KT) + Z(I)*Z(KT))
          IF (D .LT. DIST(I)) THEN
C
C Replace J by KT as the nearest triangulation node to I:
C   update NEAR(I) and DIST(I), and remove I from J's set
C   of unprocessed nodes and add it to KT's set.
C
            NEAR(I) = KT
            DIST(I) = D
            IF (I .EQ. NEAR(J)) THEN
              NEAR(J) = NEXTI
            ELSE
              NEXT(I0) = NEXTI
            ENDIF
            NEXT(I) = NEAR(KT)
            NEAR(KT) = I
          ELSE
            I0 = I
          ENDIF

C         Bottom of loop on I.
          I = NEXTI
          GO TO 4

C         Bottom of loop on neighbors J.
    5     IF (LP .NE. LPL) GO TO 3
    6   CONTINUE
      N = KT
      IER = 0
      RETURN
      END



C       ------------------ ADDNOD ----------------------------------

      SUBROUTINE ADDNOD(NST,K,X,Y,Z, LIST,LPTR,LEND,LNEW, IER)

      INTEGER NST, K, LIST(*), LPTR(*), LEND(K), LNEW, IER
      DOUBLE PRECISION X(K), Y(K), Z(K)

C***********************************************************
C
C                                              From STRIPACK
C                                            Robert J. Renka
C                                  Dept. of Computer Science
C                                       Univ. of North Texas
C                                           renka@cs.unt.edu
C                                                   01/08/03
C
C   This subroutine adds node K to a triangulation of the
C convex hull of nodes 1,...,K-1, producing a triangulation
C of the convex hull of nodes 1,...,K.
C
C   The algorithm consists of the following steps:  node K
C is located relative to the triangulation (TRFIND), its
C index is added to the data structure (INTADD or BDYADD),
C and a sequence of swaps (SWPTST and SWAP) are applied to
C the arcs opposite K so that all arcs incident on node K
C and opposite node K are locally optimal (satisfy the cir-
C cumcircle test).  Thus, if a Delaunay triangulation is
C input, a Delaunay triangulation will result.
C
C
C On input:
C
C       NST = Index of a node at which TRFIND begins its
C             search.  Search time depends on the proximity
C             of this node to K.  If NST < 1, the search is
C             begun at node K-1.
C
C       K = Nodal index (index for X, Y, Z, and LEND) of the
C           new node to be added.  K .GE. 4.
C
C       X,Y,Z = Arrays of length .GE. K containing Car-
C               tesian coordinates of the nodes.
C               (X(I),Y(I),Z(I)) defines node I for
C               I = 1,...,K.
C
C The above parameters are not altered by this routine.
C
C       LIST,LPTR,LEND,LNEW = Data structure associated with
C                             the triangulation of nodes 1
C                             to K-1.  The array lengths are
C                             assumed to be large enough to
C                             add node K.  Refer to Subrou-
C                             tine TRMESH.
C
C On output:
C
C       LIST,LPTR,LEND,LNEW = Data structure updated with
C                             the addition of node K as the
C                             last entry unless IER .NE. 0
C                             and IER .NE. -3, in which case
C                             the arrays are not altered.
C
C       IER = Error indicator:
C             IER =  0 if no errors were encountered.
C             IER = -1 if K is outside its valid range
C                      on input.
C             IER = -2 if all nodes (including K) are col-
C                      linear (lie on a common geodesic).
C             IER =  L if nodes L and K coincide for some
C                      L < K.  Refer to TOL below.
C
C Modules required by ADDNOD:  BDYADD, COVSPH, INSERT,
C                                INTADD, JRAND, LSTPTR,
C                                STORE, SWAP, SWPTST,
C                                TRFIND
C
C Intrinsic function called by ADDNOD:  ABS
C
C***********************************************************

      INTEGER LSTPTR
      INTEGER I1, I2, I3, IO1, IO2, IN1, IST, KK, KM1, L,
     .        LP, LPF, LPO1, LPO1S
      LOGICAL SWPTST
      DOUBLE PRECISION B1, B2, B3, P(3), TOL

C     Local parameters:

C B1,B2,B3 = Unnormalized barycentric coordinates returned
C              by TRFIND.
C I1,I2,I3 = Vertex indexes of a triangle containing K
C IN1 =      Vertex opposite K:  first neighbor of IO2
C              that precedes IO1.  IN1,IO1,IO2 are in
C              counterclockwise order.
C IO1,IO2 =  Adjacent neighbors of K defining an arc to
C              be tested for a swap
C IST =      Index of node at which TRFIND begins its search
C KK =       Local copy of K
C KM1 =      K-1
C L =        Vertex index (I1, I2, or I3) returned in IER
C              if node K coincides with a vertex
C LP =       LIST pointer
C LPF =      LIST pointer to the first neighbor of K
C LPO1 =     LIST pointer to IO1
C LPO1S =    Saved value of LPO1
C P =        Cartesian coordinates of node K
C TOL =      Tolerance defining coincident nodes:  bound on
C              the deviation from 1 of the cosine of the
C              angle between the nodes.
C              Note that |1-cos(A)| is approximately A*A/2.
C
      DATA TOL/0.D0/
C
      KK = K
      IF (KK .LT. 4) GO TO 3
C
C Initialization:
C
      KM1 = KK - 1
      IST = NST
      IF (IST .LT. 1) IST = KM1
      P(1) = X(KK)
      P(2) = Y(KK)
      P(3) = Z(KK)

C      Find a triangle (I1,I2,I3) containing K or the rightmost
C     (I1) and leftmost (I2) visible boundary nodes as viewed
C     from node K.

      CALL TRFIND (IST,P,KM1,X,Y,Z,LIST,LPTR,LEND, B1,B2,B3,
     .             I1,I2,I3)

C     Test for collinear or (nearly) duplicate nodes.

      IF (I1 .EQ. 0) GO TO 4
      L = I1
      IF (P(1)*X(L) + P(2)*Y(L) + P(3)*Z(L) .GE. 1.D0-TOL)
     .  GO TO 5
      L = I2
      IF (P(1)*X(L) + P(2)*Y(L) + P(3)*Z(L) .GE. 1.D0-TOL)
     .  GO TO 5
      IF (I3 .NE. 0) THEN
        L = I3
        IF (P(1)*X(L) + P(2)*Y(L) + P(3)*Z(L) .GE. 1.D0-TOL)
     .    GO TO 5
        CALL INTADD (KK,I1,I2,I3, LIST,LPTR,LEND,LNEW )
      ELSE
        IF (I1 .NE. I2) THEN
          CALL BDYADD (KK,I1,I2, LIST,LPTR,LEND,LNEW )
        ELSE
          CALL COVSPH (KK,I1, LIST,LPTR,LEND,LNEW )
        ENDIF
      ENDIF
      IER = 0

C     Initialize variables for optimization of the
C     triangulation.

      LP = LEND(KK)
      LPF = LPTR(LP)
      IO2 = LIST(LPF)
      LPO1 = LPTR(LPF)
      IO1 = ABS(LIST(LPO1))

C     Begin loop:  find the node opposite K.

    1 LP = LSTPTR(LEND(IO1),IO2,LIST,LPTR)
        IF (LIST(LP) .LT. 0) GO TO 2
        LP = LPTR(LP)
        IN1 = ABS(LIST(LP))

C       Swap test:  if a swap occurs, two new arcs are
C             opposite K and must be tested.

        LPO1S = LPO1
        IF ( .NOT. SWPTST(IN1,KK,IO1,IO2,X,Y,Z) ) GO TO 2
        CALL SWAP (IN1,KK,IO1,IO2, LIST,LPTR,LEND, LPO1)
        IF (LPO1 .EQ. 0) THEN

C         A swap is not possible because KK and IN1 are already
C         adjacent.  This error in SWPTST only occurs in the
C         neutral case and when there are nearly duplicate
C         nodes.

          LPO1 = LPO1S
          GO TO 2
        ENDIF
        IO1 = IN1
        GO TO 1

C       No swap occurred.  Test for termination and reset
C       IO2 and IO1.
    2   IF (LPO1 .EQ. LPF  .OR.  LIST(LPO1) .LT. 0) RETURN
        IO2 = IO1
        LPO1 = LPTR(LPO1)
        IO1 = ABS(LIST(LPO1))
        GO TO 1

C     KK < 4.
    3 IER = -1
      RETURN

C     All nodes are collinear.
    4 IER = -2
      RETURN

C     Nodes L and K coincide.
    5 IER = L
      RETURN
      END



      DOUBLE PRECISION FUNCTION AREAS(V1,V2,V3)

      DOUBLE PRECISION V1(3), V2(3), V3(3)

C***********************************************************
C
C                                              From STRIPACK
C                                            Robert J. Renka
C                                  Dept. of Computer Science
C                                       Univ. of North Texas
C                                           renka@cs.unt.edu
C                                                   06/22/98
C
C   This function returns the area of a spherical triangle
C on the unit sphere.
C
C
C On input:
C
C       V1,V2,V3 = Arrays of length 3 containing the Carte-
C                  sian coordinates of unit vectors (the
C                  three triangle vertices in any order).
C                  These vectors, if nonzero, are implicitly
C                  scaled to have length 1.
C
C Input parameters are not altered by this function.
C
C On output:
C
C       AREAS = Area of the spherical triangle defined by
C               V1, V2, and V3 in the range 0 to 2*PI (the
C               area of a hemisphere).  AREAS = 0 (or 2*PI)
C               if and only if V1, V2, and V3 lie in (or
C               close to) a plane containing the origin.
C
C Modules required by AREAS:  None
C
C Intrinsic functions called by AREAS:  ACOS, SQRT
C
C***********************************************************

      DOUBLE PRECISION A1, A2, A3, CA1, CA2, CA3, S12, S23,
     .                 S31, U12(3), U23(3), U31(3)
      INTEGER          I

C Local parameters:
C
C A1,A2,A3 =    Interior angles of the spherical triangle
C CA1,CA2,CA3 = cos(A1), cos(A2), and cos(A3), respectively
C I =           DO-loop index and index for Uij
C S12,S23,S31 = Sum of squared components of U12, U23, U31
C U12,U23,U31 = Unit normal vectors to the planes defined by
C                 pairs of triangle vertices
C
C
C Compute cross products Uij = Vi X Vj.
C
      U12(1) = V1(2)*V2(3) - V1(3)*V2(2)
      U12(2) = V1(3)*V2(1) - V1(1)*V2(3)
      U12(3) = V1(1)*V2(2) - V1(2)*V2(1)
C
      U23(1) = V2(2)*V3(3) - V2(3)*V3(2)
      U23(2) = V2(3)*V3(1) - V2(1)*V3(3)
      U23(3) = V2(1)*V3(2) - V2(2)*V3(1)
C
      U31(1) = V3(2)*V1(3) - V3(3)*V1(2)
      U31(2) = V3(3)*V1(1) - V3(1)*V1(3)
      U31(3) = V3(1)*V1(2) - V3(2)*V1(1)
C
C Normalize Uij to unit vectors.

      S12 = 0.D0
      S23 = 0.D0
      S31 = 0.D0
      DO 2 I = 1,3
        S12 = S12 + U12(I)*U12(I)
        S23 = S23 + U23(I)*U23(I)
        S31 = S31 + U31(I)*U31(I)
    2   CONTINUE

C       Test for a degenerate triangle associated with collinear
C       vertices.

      IF (S12 .EQ. 0.D0  .OR.  S23 .EQ. 0.D0  .OR.
     .    S31 .EQ. 0.D0) THEN
        AREAS = 0.D0
        RETURN
      ENDIF
      S12 = SQRT(S12)
      S23 = SQRT(S23)
      S31 = SQRT(S31)
      DO 3 I = 1,3
        U12(I) = U12(I)/S12
        U23(I) = U23(I)/S23
        U31(I) = U31(I)/S31
    3   CONTINUE

C       Compute interior angles Ai as the dihedral angles between
C       planes:
C           CA1 = cos(A1) = -<U12,U31>
C           CA2 = cos(A2) = -<U23,U12>
C           CA3 = cos(A3) = -<U31,U23>

      CA1 = -U12(1)*U31(1)-U12(2)*U31(2)-U12(3)*U31(3)
      CA2 = -U23(1)*U12(1)-U23(2)*U12(2)-U23(3)*U12(3)
      CA3 = -U31(1)*U23(1)-U31(2)*U23(2)-U31(3)*U23(3)
      IF (CA1 .LT. -1.D0) CA1 = -1.D0
      IF (CA1 .GT. 1.D0) CA1 = 1.D0
      IF (CA2 .LT. -1.D0) CA2 = -1.D0
      IF (CA2 .GT. 1.D0) CA2 = 1.D0
      IF (CA3 .LT. -1.D0) CA3 = -1.D0
      IF (CA3 .GT. 1.D0) CA3 = 1.D0
      A1 = ACOS(CA1)
      A2 = ACOS(CA2)
      A3 = ACOS(CA3)
C
C Compute AREAS = A1 + A2 + A3 - PI.
C
      AREAS = A1 + A2 + A3 - ACOS(-1.D0)
      IF (AREAS .LT. 0.D0) AREAS = 0.D0
      RETURN
      END



      DOUBLE PRECISION FUNCTION AREAV(K,N,X,Y,Z,LIST,LPTR,
     .                                 LEND,IER)
      INTEGER K, N, LIST(*), LPTR(*), LEND(N), IER
      DOUBLE PRECISION X(N), Y(N), Z(N)
C
C***********************************************************
C
C                                            Robert J. Renka
C                                  Dept. of Computer Science
C                                       Univ. of North Texas
C                                           renka@cs.unt.edu
C                                                   10/25/02
C
C   Given a Delaunay triangulation and the index K of an
C interior node, this subroutine returns the (surface) area
C of the Voronoi region associated with node K.  The Voronoi
C region is the polygon whose vertices are the circumcenters
C of the triangles that contain node K, where a triangle
C circumcenter is the point (unit vector) lying at the same
C angular distance from the three vertices and contained in
C the same hemisphere as the vertices.
C
C
C On input:
C
C       K = Nodal index in the range 1 to N.
C
C       N = Number of nodes in the triangulation.  N > 3.
C
C       X,Y,Z = Arrays of length N containing the Cartesian
C               coordinates of the nodes (unit vectors).
C
C       LIST,LPTR,LEND = Data structure defining the trian-
C                        gulation.  Refer to Subroutine
C                        TRMESH.
C
C Input parameters are not altered by this function.
C
C On output:
C
C       AREAV = Area of Voronoi region K unless IER > 0,
C               in which case AREAV = 0.
C
C       IER = Error indicator:
C             IER = 0 if no errors were encountered.
C             IER = 1 if K or N is outside its valid range
C                     on input.
C             IER = 2 if K indexes a boundary node.
C             IER = 3 if an error flag is returned by CIRCUM
C                     (null triangle).
C             IER = 4 if AREAS returns a value greater than
C                     AMAX (defined below).
C
C Modules required by AREAV:  AREAS, CIRCUM
C
C***********************************************************

      INTEGER IERR, LP, LPL, N1, N2, N3
      LOGICAL FIRST
      DOUBLE PRECISION AREAS
      DOUBLE PRECISION A, AMAX, ASUM, C0(3), C2(3), C3(3),
     .                 V1(3), V2(3), V3(3)

C     Maximum valid triangle area is less than 2*Pi:

      DATA AMAX/6.28D0/

C     Test for invalid input.

      IF (K .LT. 1  .OR.  K .GT. N  .OR.  N .LE. 3) GO TO 11
C
C Initialization:  Set N3 to the last neighbor of N1 = K.
C   FIRST = TRUE only for the first triangle.
C   The Voronoi region area is accumulated in ASUM.
C
      N1 = K
      V1(1) = X(N1)
      V1(2) = Y(N1)
      V1(3) = Z(N1)
      LPL = LEND(N1)
      N3 = LIST(LPL)
      IF (N3 .LT. 0) GO TO 12
      LP = LPL
      FIRST = .TRUE.
      ASUM = 0.D0
C
C Loop on triangles (N1,N2,N3) containing N1 = K.
C
    1 N2 = N3
        LP = LPTR(LP)
        N3 = LIST(LP)
        V2(1) = X(N2)
        V2(2) = Y(N2)
        V2(3) = Z(N2)
        V3(1) = X(N3)
        V3(2) = Y(N3)
        V3(3) = Z(N3)
        IF (FIRST) THEN

C         First triangle:  compute the circumcenter C3 and save a
C         copy in C0.

          CALL CIRCUM (V1,V2,V3, C3,IERR)
          IF (IERR .NE. 0) GO TO 13
          C0(1) = C3(1)
          C0(2) = C3(2)
          C0(3) = C3(3)
          FIRST = .FALSE.
        ELSE

C         Set C2 to C3, compute the new circumcenter C3, and compute
C         the area A of triangle (V1,C2,C3).

          C2(1) = C3(1)
          C2(2) = C3(2)
          C2(3) = C3(3)
          CALL CIRCUM (V1,V2,V3, C3,IERR)
          IF (IERR .NE. 0) GO TO 13
          A = AREAS (V1,C2,C3)
          IF (A .GT. AMAX) GO TO 14
          ASUM = ASUM + A
        ENDIF

C       Bottom on loop on neighbors of K.

        IF (LP .NE. LPL) GO TO 1

C     Compute the area of triangle (V1,C3,C0).
      A = AREAS (V1,C3,C0)
      IF (A .GT. AMAX) GO TO 14
      ASUM = ASUM + A

C     No error encountered.
      IER = 0
      AREAV = ASUM
      RETURN

C     Invalid input.
  11  IER = 1
      AREAV = 0.D0
      RETURN

C     K indexes a boundary node.
   12 IER = 2
      AREAV = 0.D0
      RETURN

C     Error in CIRCUM.
   13 IER = 3
      AREAV = 0.D0
      RETURN

C     AREAS value larger than AMAX.
   14 IER = 4
      AREAV = 0.D0
      RETURN
      END


C      ------------------ BDYADD ----------------------------------

      SUBROUTINE BDYADD (KK,I1,I2, LIST,LPTR,LEND,LNEW )

      INTEGER KK, I1, I2, LIST(*), LPTR(*), LEND(*), LNEW

C***********************************************************
C
C                                              From STRIPACK
C                                            Robert J. Renka
C                                  Dept. of Computer Science
C                                       Univ. of North Texas
C                                           renka@cs.unt.edu
C                                                   07/11/96
C
C   This subroutine adds a boundary node to a triangulation
C of a set of KK-1 points on the unit sphere.  The data
C structure is updated with the insertion of node KK, but no
C optimization is performed.
C
C   This routine is identical to the similarly named routine
C in TRIPACK.
C
C
C On input:
C
C       KK = Index of a node to be connected to the sequence
C            of all visible boundary nodes.  KK .GE. 1 and
C            KK must not be equal to I1 or I2.
C
C       I1 = First (rightmost as viewed from KK) boundary
C            node in the triangulation that is visible from
C            node KK (the line segment KK-I1 intersects no
C            arcs.
C
C       I2 = Last (leftmost) boundary node that is visible
C            from node KK.  I1 and I2 may be determined by
C            Subroutine TRFIND.
C
C The above parameters are not altered by this routine.
C
C       LIST,LPTR,LEND,LNEW = Triangulation data structure
C                             created by Subroutine TRMESH.
C                             Nodes I1 and I2 must be in-
C                             cluded in the triangulation.
C
C On output:
C
C       LIST,LPTR,LEND,LNEW = Data structure updated with
C                             the addition of node KK.  Node
C                             KK is connected to I1, I2, and
C                             all boundary nodes in between.
C
C Module required by BDYADD:  INSERT
C
C***********************************************************

      INTEGER K, LP, LSAV, N1, N2, NEXT, NSAV

C Local parameters:
C
C K =     Local copy of KK
C LP =    LIST pointer
C LSAV =  LIST pointer
C N1,N2 = Local copies of I1 and I2, respectively
C NEXT =  Boundary node visible from K
C NSAV =  Boundary node visible from K

      K = KK
      N1 = I1
      N2 = I2

C Add K as the last neighbor of N1.
      LP = LEND(N1)
      LSAV = LPTR(LP)
      LPTR(LP) = LNEW
      LIST(LNEW) = -K
      LPTR(LNEW) = LSAV
      LEND(N1) = LNEW
      LNEW = LNEW + 1
      NEXT = -LIST(LP)
      LIST(LP) = NEXT
      NSAV = NEXT
C
C Loop on the remaining boundary nodes between N1 and N2,
C   adding K as the first neighbor.
C
    1 LP = LEND(NEXT)
        CALL INSERT (K,LP, LIST,LPTR,LNEW )
        IF (NEXT .EQ. N2) GO TO 2
        NEXT = -LIST(LP)
        LIST(LP) = NEXT
        GO TO 1
C
C Add the boundary nodes between N1 and N2 as neighbors
C   of node K.
C
    2 LSAV = LNEW
      LIST(LNEW) = N1
      LPTR(LNEW) = LNEW + 1
      LNEW = LNEW + 1
      NEXT = NSAV
C
    3 IF (NEXT .EQ. N2) GO TO 4
        LIST(LNEW) = NEXT
        LPTR(LNEW) = LNEW + 1
        LNEW = LNEW + 1
        LP = LEND(NEXT)
        NEXT = LIST(LP)
        GO TO 3
C
    4 LIST(LNEW) = -N2
      LPTR(LNEW) = LSAV
      LEND(K) = LNEW
      LNEW = LNEW + 1
      RETURN
      END


C       ------------------ CIRCUM ----------------------------------

      SUBROUTINE CIRCUM (V1,V2,V3, C,IER)

      INTEGER IER
      DOUBLE PRECISION V1(3), V2(3), V3(3), C(3)

C***********************************************************
C
C                                              From STRIPACK
C                                            Robert J. Renka
C                                  Dept. of Computer Science
C                                       Univ. of North Texas
C                                           renka@cs.unt.edu
C                                                   10/27/02
C
C   This subroutine returns the circumcenter of a spherical
C triangle on the unit sphere:  the point on the sphere sur-
C face that is equally distant from the three triangle
C vertices and lies in the same hemisphere, where distance
C is taken to be arc-length on the sphere surface.
C
C
C On input:
C
C       V1,V2,V3 = Arrays of length 3 containing the Carte-
C                  sian coordinates of the three triangle
C                  vertices (unit vectors) in CCW order.
C
C The above parameters are not altered by this routine.
C
C       C = Array of length 3.
C
C On output:
C
C       C = Cartesian coordinates of the circumcenter unless
C           IER > 0, in which case C is not defined.  C =
C           (V2-V1) X (V3-V1) normalized to a unit vector.
C
C       IER = Error indicator:
C             IER = 0 if no errors were encountered.
C             IER = 1 if V1, V2, and V3 lie on a common
C                     line:  (V2-V1) X (V3-V1) = 0.
C             (The vertices are not tested for validity.)
C
C Modules required by CIRCUM:  None
C
C Intrinsic function called by CIRCUM:  SQRT
C
C***********************************************************
C
      INTEGER I
      DOUBLE PRECISION CNORM, CU(3), E1(3), E2(3)

C Local parameters:

C CNORM = Norm of CU:  used to compute C
C CU =    Scalar multiple of C:  E1 X E2
C E1,E2 = Edges of the underlying planar triangle:
C           V2-V1 and V3-V1, respectively
C I =     DO-loop index

      DO 1 I = 1,3
        E1(I) = V2(I) - V1(I)
        E2(I) = V3(I) - V1(I)
    1   CONTINUE

C Compute CU = E1 X E2 and CNORM**2.

      CU(1) = E1(2)*E2(3) - E1(3)*E2(2)
      CU(2) = E1(3)*E2(1) - E1(1)*E2(3)
      CU(3) = E1(1)*E2(2) - E1(2)*E2(1)
      CNORM = CU(1)*CU(1) + CU(2)*CU(2) + CU(3)*CU(3)

C The vertices lie on a common line if and only if CU is
C   the zero vector.

      IF (CNORM .NE. 0.D0) THEN

C   No error:  compute C.

        CNORM = SQRT(CNORM)
        DO 2 I = 1,3
          C(I) = CU(I)/CNORM
    2     CONTINUE

C If the vertices are nearly identical, the problem is
C   ill-conditioned and it is possible for the computed
C   value of C to be 180 degrees off:  <C,V1> near -1
C   when it should be positive.

        IF (C(1)*V1(1)+C(2)*V1(2)+C(3)*V1(3) .LT. -0.5D0) THEN
          C(1) = -C(1)
          C(2) = -C(2)
          C(3) = -C(3)
        ENDIF
        IER = 0
      ELSE
C
C   CU = 0.
C
        IER = 1
      ENDIF
      RETURN
      END

C       ------------------ COVSPH ----------------------------------


      SUBROUTINE COVSPH (KK,N0, LIST,LPTR,LEND,LNEW )

      INTEGER KK, N0, LIST(*), LPTR(*), LEND(*), LNEW

C***********************************************************
C
C                                              From STRIPACK
C                                            Robert J. Renka
C                                  Dept. of Computer Science
C                                       Univ. of North Texas
C                                           renka@cs.unt.edu
C                                                   07/17/96
C
C   This subroutine connects an exterior node KK to all
C boundary nodes of a triangulation of KK-1 points on the
C unit sphere, producing a triangulation that covers the
C sphere.  The data structure is updated with the addition
C of node KK, but no optimization is performed.  All boun-
C dary nodes must be visible from node KK.
C
C
C On input:
C
C       KK = Index of the node to be connected to the set of
C            all boundary nodes.  KK .GE. 4.
C
C       N0 = Index of a boundary node (in the range 1 to
C            KK-1).  N0 may be determined by Subroutine
C            TRFIND.
C
C The above parameters are not altered by this routine.
C
C       LIST,LPTR,LEND,LNEW = Triangulation data structure
C                             created by Subroutine TRMESH.
C                             Node N0 must be included in
C                             the triangulation.
C
C On output:
C
C       LIST,LPTR,LEND,LNEW = Data structure updated with
C                             the addition of node KK as the
C                             last entry.  The updated
C                             triangulation contains no
C                             boundary nodes.
C
C Module required by COVSPH:  INSERT
C
C***********************************************************

      INTEGER K, LP, LSAV, NEXT, NST

C Local parameters:
C K =     Local copy of KK
C LP =    LIST pointer
C LSAV =  LIST pointer
C NEXT =  Boundary node visible from K
C NST =   Local copy of N0

      K = KK
      NST = N0

C     Traverse the boundary in clockwise order, inserting K as
C    the first neighbor of each boundary node, and converting
C    the boundary node to an interior node.

      NEXT = NST
    1 LP = LEND(NEXT)
        CALL INSERT (K,LP, LIST,LPTR,LNEW )
        NEXT = -LIST(LP)
        LIST(LP) = NEXT
        IF (NEXT .NE. NST) GO TO 1

C     Traverse the boundary again, adding each node to K's
C     adjacency list.

      LSAV = LNEW
    2 LP = LEND(NEXT)
        LIST(LNEW) = NEXT
        LPTR(LNEW) = LNEW + 1
        LNEW = LNEW + 1
        NEXT = LIST(LP)
        IF (NEXT .NE. NST) GO TO 2
C
      LPTR(LNEW-1) = LSAV
      LEND(K) = LNEW - 1
      RETURN
      END

C       ------------------ INSERT ----------------------------------

      SUBROUTINE INSERT (K,LP, LIST,LPTR,LNEW )

      INTEGER K, LP, LIST(*), LPTR(*), LNEW

C***********************************************************
C
C                                              From STRIPACK
C                                            Robert J. Renka
C                                  Dept. of Computer Science
C                                       Univ. of North Texas
C                                           renka@cs.unt.edu
C                                                   07/17/96
C
C   This subroutine inserts K as a neighbor of N1 following
C N2, where LP is the LIST pointer of N2 as a neighbor of
C N1.  Note that, if N2 is the last neighbor of N1, K will
C become the first neighbor (even if N1 is a boundary node).
C
C   This routine is identical to the similarly named routine
C in TRIPACK.
C
C
C On input:
C
C       K = Index of the node to be inserted.
C
C       LP = LIST pointer of N2 as a neighbor of N1.
C
C The above parameters are not altered by this routine.
C
C       LIST,LPTR,LNEW = Data structure defining the trian-
C                        gulation.  Refer to Subroutine
C                        TRMESH.
C
C On output:
C
C       LIST,LPTR,LNEW = Data structure updated with the
C                        addition of node K.
C
C Modules required by INSERT:  None
C
C***********************************************************

      INTEGER LSAV

      LSAV = LPTR(LP)
      LPTR(LP) = LNEW
      LIST(LNEW) = K
      LPTR(LNEW) = LSAV
      LNEW = LNEW + 1
      RETURN
      END

C       ------------------ INTADD ----------------------------------


      SUBROUTINE INTADD (KK,I1,I2,I3, LIST,LPTR,LEND,LNEW )

      INTEGER KK, I1, I2, I3, LIST(*), LPTR(*), LEND(*),
     .        LNEW

C***********************************************************
C
C                                              From STRIPACK
C                                            Robert J. Renka
C                                  Dept. of Computer Science
C                                       Univ. of North Texas
C                                           renka@cs.unt.edu
C                                                   07/17/96
C
C   This subroutine adds an interior node to a triangulation
C of a set of points on the unit sphere.  The data structure
C is updated with the insertion of node KK into the triangle
C whose vertices are I1, I2, and I3.  No optimization of the
C triangulation is performed.
C
C   This routine is identical to the similarly named routine
C in TRIPACK.
C
C
C On input:
C
C       KK = Index of the node to be inserted.  KK .GE. 1
C            and KK must not be equal to I1, I2, or I3.
C
C       I1,I2,I3 = Indexes of the counterclockwise-ordered
C                  sequence of vertices of a triangle which
C                  contains node KK.
C
C The above parameters are not altered by this routine.
C
C       LIST,LPTR,LEND,LNEW = Data structure defining the
C                             triangulation.  Refer to Sub-
C                             routine TRMESH.  Triangle
C                             (I1,I2,I3) must be included
C                             in the triangulation.
C
C On output:
C
C       LIST,LPTR,LEND,LNEW = Data structure updated with
C                             the addition of node KK.  KK
C                             will be connected to nodes I1,
C                             I2, and I3.
C
C Modules required by INTADD:  INSERT, LSTPTR
C
C***********************************************************

      INTEGER LSTPTR
      INTEGER K, LP, N1, N2, N3

C Local parameters:

C K =        Local copy of KK
C LP =       LIST pointer
C N1,N2,N3 = Local copies of I1, I2, and I3

      K = KK

C     Initialization.
      N1 = I1
      N2 = I2
      N3 = I3

C     Add K as a neighbor of I1, I2, and I3.
      LP = LSTPTR(LEND(N1),N2,LIST,LPTR)
      CALL INSERT (K,LP, LIST,LPTR,LNEW )
      LP = LSTPTR(LEND(N2),N3,LIST,LPTR)
      CALL INSERT (K,LP, LIST,LPTR,LNEW )
      LP = LSTPTR(LEND(N3),N1,LIST,LPTR)
      CALL INSERT (K,LP, LIST,LPTR,LNEW )

C     Add I1, I2, and I3 as neighbors of K.
      LIST(LNEW) = N1
      LIST(LNEW+1) = N2
      LIST(LNEW+2) = N3
      LPTR(LNEW) = LNEW + 1
      LPTR(LNEW+1) = LNEW + 2
      LPTR(LNEW+2) = LNEW
      LEND(K) = LNEW + 2
      LNEW = LNEW + 3
      RETURN
      END






      INTEGER FUNCTION JRAND (N, IX,IY,IZ )

      INTEGER N, IX, IY, IZ
C
C***********************************************************
C
C                                              From STRIPACK
C                                            Robert J. Renka
C                                  Dept. of Computer Science
C                                       Univ. of North Texas
C                                           renka@cs.unt.edu
C                                                   07/28/98
C
C   This function returns a uniformly distributed pseudo-
C random integer in the range 1 to N.
C
C
C On input:
C
C       N = Maximum value to be returned.
C
C N is not altered by this function.
C
C       IX,IY,IZ = Integer seeds initialized to values in
C                  the range 1 to 30,000 before the first
C                  call to JRAND, and not altered between
C                  subsequent calls (unless a sequence of
C                  random numbers is to be repeated by
C                  reinitializing the seeds).
C
C On output:
C
C       IX,IY,IZ = Updated integer seeds.
C
C       JRAND = Random integer in the range 1 to N.
C
C Reference:  B. A. Wichmann and I. D. Hill, "An Efficient
C             and Portable Pseudo-random Number Generator",
C             Applied Statistics, Vol. 31, No. 2, 1982,
C             pp. 188-190.
C
C Modules required by JRAND:  None
C
C Intrinsic functions called by JRAND:  INT, MOD, REAL
C
C***********************************************************

      REAL U, X

C     Local parameters:
C     U = Pseudo-random number uniformly distributed in the
C     interval (0,1).
C     X = Pseudo-random number in the range 0 to 3 whose frac-
C       tional part is U.

      IX = MOD(171*IX,30269)
      IY = MOD(172*IY,30307)
      IZ = MOD(170*IZ,30323)
      X = (REAL(IX)/30269.) + (REAL(IY)/30307.) +
     .    (REAL(IZ)/30323.)
      U = X - INT(X)
      JRAND = REAL(N)*U + 1.0E0
      RETURN
      END



      LOGICAL FUNCTION LEFT(X1,Y1,Z1,X2,Y2,Z2,X0,Y0,Z0)

      DOUBLE PRECISION X1, Y1, Z1, X2, Y2, Z2, X0, Y0, Z0
C
C***********************************************************
C
C                                              From STRIPACK
C                                            Robert J. Renka
C                                  Dept. of Computer Science
C                                       Univ. of North Texas
C                                           renka@cs.unt.edu
C                                                   07/15/96
C
C   This function determines whether node N0 is in the
C (closed) left hemisphere defined by the plane containing
C N1, N2, and the origin, where left is defined relative to
C an observer at N1 facing N2.
C
C
C On input:
C       X1,Y1,Z1 = Coordinates of N1.
C       X2,Y2,Z2 = Coordinates of N2.
C       X0,Y0,Z0 = Coordinates of N0.

C Input parameters are not altered by this function.

C On output:
C       LEFT = TRUE if and only if N0 is in the closed
C              left hemisphere.

C Modules required by LEFT:  None

C***********************************************************
C
C LEFT = TRUE iff <N0,N1 X N2> = det(N0,N1,N2) .GE. 0.
C
      LEFT = X0*(Y1*Z2-Y2*Z1) - Y0*(X1*Z2-X2*Z1) +
     .       Z0*(X1*Y2-X2*Y1) .GE. 0.D0
      RETURN
      END


      INTEGER FUNCTION LSTPTR (LPL,NB,LIST,LPTR)
      INTEGER LPL, NB, LIST(*), LPTR(*)
C
C***********************************************************
C
C                                              From STRIPACK
C                                            Robert J. Renka
C                                  Dept. of Computer Science
C                                       Univ. of North Texas
C                                           renka@cs.unt.edu
C                                                   07/15/96
C
C   This function returns the index (LIST pointer) of NB in
C the adjacency list for N0, where LPL = LEND(N0).
C
C   This function is identical to the similarly named
C function in TRIPACK.
C
C
C On input:
C
C       LPL = LEND(N0)
C
C       NB = Index of the node whose pointer is to be re-
C            turned.  NB must be connected to N0.
C
C       LIST,LPTR = Data structure defining the triangula-
C                   tion.  Refer to Subroutine TRMESH.
C
C Input parameters are not altered by this function.
C
C On output:
C
C       LSTPTR = Pointer such that LIST(LSTPTR) = NB or
C                LIST(LSTPTR) = -NB, unless NB is not a
C                neighbor of N0, in which case LSTPTR = LPL.
C
C Modules required by LSTPTR:  None
C
C***********************************************************

      INTEGER LP, ND

C     Local parameters:
C     LP = LIST pointer
C     ND = Nodal index

      LP = LPTR(LPL)
    1 ND = LIST(LP)
        IF (ND .EQ. NB) GO TO 2
        LP = LPTR(LP)
        IF (LP .NE. LPL) GO TO 1

    2 LSTPTR = LP
      RETURN
      END






      DOUBLE PRECISION FUNCTION STORE (X)

      DOUBLE PRECISION X

C***********************************************************
C
C                                              From STRIPACK
C                                            Robert J. Renka
C                                  Dept. of Computer Science
C                                       Univ. of North Texas
C                                           renka@cs.unt.edu
C                                                   05/09/92
C
C   This function forces its argument X to be stored in a
C memory location, thus providing a means of determining
C floating point number characteristics (such as the machine
C precision) when it is necessary to avoid computation in
C high precision registers.
C
C
C On input:
C
C       X = Value to be stored.
C
C X is not altered by this function.
C
C On output:
C
C       STORE = Value of X after it has been stored and
C               possibly truncated or rounded to the single
C               precision word length.
C
C Modules required by STORE:  None
C
C***********************************************************

      DOUBLE PRECISION Y
      COMMON/STCOM/Y

      Y = X
      STORE = Y
      RETURN
      END

C       ------------------ SWAP ----------------------------------


      SUBROUTINE SWAP(IN1,IN2,IO1,IO2, LIST,LPTR,
     .                 LEND, LP21)

      INTEGER IN1, IN2, IO1, IO2, LIST(*), LPTR(*), LEND(*),
     .        LP21

C***********************************************************
C
C                                              From STRIPACK
C                                            Robert J. Renka
C                                  Dept. of Computer Science
C                                       Univ. of North Texas
C                                           renka@cs.unt.edu
C                                                   06/22/98
C
C   Given a triangulation of a set of points on the unit
C sphere, this subroutine replaces a diagonal arc in a
C strictly convex quadrilateral (defined by a pair of adja-
C cent triangles) with the other diagonal.  Equivalently, a
C pair of adjacent triangles is replaced by another pair
C having the same union.
C
C
C On input:
C
C       IN1,IN2,IO1,IO2 = Nodal indexes of the vertices of
C                         the quadrilateral.  IO1-IO2 is re-
C                         placed by IN1-IN2.  (IO1,IO2,IN1)
C                         and (IO2,IO1,IN2) must be trian-
C                         gles on input.
C
C The above parameters are not altered by this routine.
C
C       LIST,LPTR,LEND = Data structure defining the trian-
C                        gulation.  Refer to Subroutine
C                        TRMESH.
C
C On output:
C
C       LIST,LPTR,LEND = Data structure updated with the
C                        swap -- triangles (IO1,IO2,IN1) and
C                        (IO2,IO1,IN2) are replaced by
C                        (IN1,IN2,IO2) and (IN2,IN1,IO1)
C                        unless LP21 = 0.
C
C       LP21 = Index of IN1 as a neighbor of IN2 after the
C              swap is performed unless IN1 and IN2 are
C              adjacent on input, in which case LP21 = 0.
C
C Module required by SWAP:  LSTPTR
C
C Intrinsic function called by SWAP:  ABS
C
C***********************************************************

      INTEGER LSTPTR
      INTEGER LP, LPH, LPSAV

C Local parameters:
C LP,LPH,LPSAV = LIST pointers

C     Test for IN1 and IN2 adjacent.
      LP = LSTPTR(LEND(IN1),IN2,LIST,LPTR)
      IF (ABS(LIST(LP)) .EQ. IN2) THEN
        LP21 = 0
        RETURN
      ENDIF

C     Delete IO2 as a neighbor of IO1.
      LP = LSTPTR(LEND(IO1),IN2,LIST,LPTR)
      LPH = LPTR(LP)
      LPTR(LP) = LPTR(LPH)

C     If IO2 is the last neighbor of IO1, make IN2 the
C     last neighbor.
      IF (LEND(IO1) .EQ. LPH) LEND(IO1) = LP

C     Insert IN2 as a neighbor of IN1 following IO1
C     using the hole created above.
      LP = LSTPTR(LEND(IN1),IO1,LIST,LPTR)
      LPSAV = LPTR(LP)
      LPTR(LP) = LPH
      LIST(LPH) = IN2
      LPTR(LPH) = LPSAV

C     Delete IO1 as a neighbor of IO2.
      LP = LSTPTR(LEND(IO2),IN1,LIST,LPTR)
      LPH = LPTR(LP)
      LPTR(LP) = LPTR(LPH)
C
C     If IO1 is the last neighbor of IO2, make IN1 the
C     last neighbor.
      IF (LEND(IO2) .EQ. LPH) LEND(IO2) = LP
C
C     Insert IN1 as a neighbor of IN2 following IO2.
      LP = LSTPTR(LEND(IN2),IO2,LIST,LPTR)
      LPSAV = LPTR(LP)
      LPTR(LP) = LPH
      LIST(LPH) = IN1
      LPTR(LPH) = LPSAV
      LP21 = LPH
      RETURN
      END


      LOGICAL FUNCTION SWPTST(N1,N2,N3,N4,X,Y,Z)

      INTEGER N1, N2, N3, N4
      DOUBLE PRECISION X(*), Y(*), Z(*)

C***********************************************************
C
C                                              From STRIPACK
C                                            Robert J. Renka
C                                  Dept. of Computer Science
C                                       Univ. of North Texas
C                                           renka@cs.unt.edu
C                                                   03/29/91
C
C   This function decides whether or not to replace a
C diagonal arc in a quadrilateral with the other diagonal.
C The decision will be to swap (SWPTST = TRUE) if and only
C if N4 lies above the plane (in the half-space not contain-
C ing the origin) defined by (N1,N2,N3), or equivalently, if
C the projection of N4 onto this plane is interior to the
C circumcircle of (N1,N2,N3).  The decision will be for no
C swap if the quadrilateral is not strictly convex.
C
C
C On input:
C
C       N1,N2,N3,N4 = Indexes of the four nodes defining the
C                     quadrilateral with N1 adjacent to N2,
C                     and (N1,N2,N3) in counterclockwise
C                     order.  The arc connecting N1 to N2
C                     should be replaced by an arc connec-
C                     ting N3 to N4 if SWPTST = TRUE.  Refer
C                     to Subroutine SWAP.
C
C       X,Y,Z = Arrays of length N containing the Cartesian
C               coordinates of the nodes.  (X(I),Y(I),Z(I))
C               define node I for I = N1, N2, N3, and N4.
C
C Input parameters are not altered by this routine.
C
C On output:
C
C       SWPTST = TRUE if and only if the arc connecting N1
C                and N2 should be swapped for an arc con-
C                necting N3 and N4.
C
C Modules required by SWPTST:  None
C
C***********************************************************

      DOUBLE PRECISION DX1, DX2, DX3, DY1, DY2, DY3, DZ1,
     .                 DZ2, DZ3, X4, Y4, Z4

C Local parameters:

C DX1,DY1,DZ1 = Coordinates of N4->N1
C DX2,DY2,DZ2 = Coordinates of N4->N2
C DX3,DY3,DZ3 = Coordinates of N4->N3
C X4,Y4,Z4 =    Coordinates of N4

      X4 = X(N4)
      Y4 = Y(N4)
      Z4 = Z(N4)
      DX1 = X(N1) - X4
      DX2 = X(N2) - X4
      DX3 = X(N3) - X4
      DY1 = Y(N1) - Y4
      DY2 = Y(N2) - Y4
      DY3 = Y(N3) - Y4
      DZ1 = Z(N1) - Z4
      DZ2 = Z(N2) - Z4
      DZ3 = Z(N3) - Z4
C
C N4 lies above the plane of (N1,N2,N3) iff N3 lies above
C   the plane of (N2,N1,N4) iff Det(N3-N4,N2-N4,N1-N4) =
C   (N3-N4,N2-N4 X N1-N4) > 0.

      SWPTST = DX3*(DY2*DZ1 - DY1*DZ2)
     .        -DY3*(DX2*DZ1 - DX1*DZ2)
     .        +DZ3*(DX2*DY1 - DX1*DY2) .GT. 0.D0
      RETURN
      END



C       ------------------ TRFIND ----------------------------------


      SUBROUTINE TRFIND (NST,P,N,X,Y,Z,LIST,LPTR,LEND, B1,
     .                   B2,B3,I1,I2,I3)

      INTEGER NST, N, LIST(*), LPTR(*), LEND(N), I1, I2, I3
      DOUBLE PRECISION P(3), X(N), Y(N), Z(N), B1, B2, B3

C***********************************************************
C
C                                              From STRIPACK
C                                            Robert J. Renka
C                                  Dept. of Computer Science
C                                       Univ. of North Texas
C                                           renka@cs.unt.edu
C                                                   11/30/99
C
C   This subroutine locates a point P relative to a triangu-
C lation created by Subroutine TRMESH.  If P is contained in
C a triangle, the three vertex indexes and barycentric coor-
C dinates are returned.  Otherwise, the indexes of the
C visible boundary nodes are returned.
C
C
C On input:
C
C       NST = Index of a node at which TRFIND begins its
C             search.  Search time depends on the proximity
C             of this node to P.
C
C       P = Array of length 3 containing the x, y, and z
C           coordinates (in that order) of the point P to be
C           located.
C
C       N = Number of nodes in the triangulation.  N .GE. 3.
C
C       X,Y,Z = Arrays of length N containing the Cartesian
C               coordinates of the triangulation nodes (unit
C               vectors).  (X(I),Y(I),Z(I)) defines node I
C               for I = 1 to N.
C
C       LIST,LPTR,LEND = Data structure defining the trian-
C                        gulation.  Refer to Subroutine
C                        TRMESH.
C
C Input parameters are not altered by this routine.
C
C On output:
C
C       B1,B2,B3 = Unnormalized barycentric coordinates of
C                  the central projection of P onto the un-
C                  derlying planar triangle if P is in the
C                  convex hull of the nodes.  These parame-
C                  ters are not altered if I1 = 0.
C
C       I1,I2,I3 = Counterclockwise-ordered vertex indexes
C                  of a triangle containing P if P is con-
C                  tained in a triangle.  If P is not in the
C                  convex hull of the nodes, I1 and I2 are
C                  the rightmost and leftmost (boundary)
C                  nodes that are visible from P, and
C                  I3 = 0.  (If all boundary nodes are vis-
C                  ible from P, then I1 and I2 coincide.)
C                  I1 = I2 = I3 = 0 if P and all of the
C                  nodes are coplanar (lie on a common great
C                  circle.
C
C Modules required by TRFIND:  JRAND, LSTPTR, STORE
C
C Intrinsic function called by TRFIND:  ABS
C
C***********************************************************

      INTEGER JRAND, LSTPTR
      INTEGER IX, IY, IZ, LP, N0, N1, N1S, N2, N2S, N3, N4,
     .        NEXT, NF, NL
      DOUBLE PRECISION STORE
      DOUBLE PRECISION DET, EPS, PTN1, PTN2, Q(3), S12, TOL,
     .                 XP, YP, ZP
      DOUBLE PRECISION X0, X1, X2, Y0, Y1, Y2, Z0, Z1, Z2

      SAVE    IX, IY, IZ
      DATA    IX/1/, IY/2/, IZ/3/

C Local parameters:

C EPS =      Machine precision
C IX,IY,IZ = Integer seeds for JRAND
C LP =       LIST pointer
C N0,N1,N2 = Nodes in counterclockwise order defining a
C              cone (with vertex N0) containing P, or end-
C              points of a boundary edge such that P Right
C              N1->N2
C N1S,N2S =  Initially-determined values of N1 and N2
C N3,N4 =    Nodes opposite N1->N2 and N2->N1, respectively
C NEXT =     Candidate for I1 or I2 when P is exterior
C NF,NL =    First and last neighbors of N0, or first
C              (rightmost) and last (leftmost) nodes
C              visible from P when P is exterior to the
C              triangulation
C PTN1 =     Scalar product <P,N1>
C PTN2 =     Scalar product <P,N2>
C Q =        (N2 X N1) X N2  or  N1 X (N2 X N1) -- used in
C              the boundary traversal when P is exterior
C S12 =      Scalar product <N1,N2>
C TOL =      Tolerance (multiple of EPS) defining an upper
C              bound on the magnitude of a negative bary-
C              centric coordinate (B1 or B2) for P in a
C              triangle -- used to avoid an infinite number
C              of restarts with 0 <= B3 < EPS and B1 < 0 or
C              B2 < 0 but small in magnitude
C XP,YP,ZP = Local variables containing P(1), P(2), and P(3)
C X0,Y0,Z0 = Dummy arguments for DET
C X1,Y1,Z1 = Dummy arguments for DET
C X2,Y2,Z2 = Dummy arguments for DET
C
C Statement function:
C
C DET(X1,...,Z0) .GE. 0 if and only if (X0,Y0,Z0) is in the
C                       (closed) left hemisphere defined by
C                       the plane containing (0,0,0),
C                       (X1,Y1,Z1), and (X2,Y2,Z2), where
C                       left is defined relative to an ob-
C                       server at (X1,Y1,Z1) facing
C                       (X2,Y2,Z2).

      DET (X1,Y1,Z1,X2,Y2,Z2,X0,Y0,Z0) = X0*(Y1*Z2-Y2*Z1)
     .     - Y0*(X1*Z2-X2*Z1) + Z0*(X1*Y2-X2*Y1)

C     Initialize variables.

      XP = P(1)
      YP = P(2)
      ZP = P(3)
      N0 = NST
      IF (N0 .LT. 1  .OR.  N0 .GT. N)
     .  N0 = JRAND(N, IX,IY,IZ )

C     Compute the relative machine precision EPS and TOL.
      EPS = 1.D0
    1 EPS = EPS/2.D0
        IF (STORE(EPS+1.D0) .GT. 1.D0) GO TO 1
      EPS = 2.D0*EPS
      TOL = 4.D0*EPS

C     Set NF and NL to the first and last neighbors of N0, and
C     initialize N1 = NF.
    2 LP = LEND(N0)
      NL = LIST(LP)
      LP = LPTR(LP)
      NF = LIST(LP)
      N1 = NF

C     Find a pair of adjacent neighbors N1,N2 of N0 that define
C     a wedge containing P:  P LEFT N0->N1 and P RIGHT N0->N2.
      IF (NL .GT. 0) THEN

C       N0 is an interior node.  Find N1.
    3   IF ( DET(X(N0),Y(N0),Z(N0),X(N1),Y(N1),Z(N1),
     .           XP,YP,ZP) .LT. 0.D0 ) THEN
          LP = LPTR(LP)
          N1 = LIST(LP)
          IF (N1 .EQ. NL) GO TO 6
          GO TO 3
        ENDIF
      ELSE
C
C   N0 is a boundary node.  Test for P exterior.
C
        NL = -NL
        IF ( DET(X(N0),Y(N0),Z(N0),X(NF),Y(NF),Z(NF),
     .           XP,YP,ZP) .LT. 0.D0 ) THEN
C
C   P is to the right of the boundary edge N0->NF.
C
          N1 = N0
          N2 = NF
          GO TO 9
        ENDIF
        IF ( DET(X(NL),Y(NL),Z(NL),X(N0),Y(N0),Z(N0),
     .           XP,YP,ZP) .LT. 0.D0 ) THEN
C
C   P is to the right of the boundary edge NL->N0.
C
          N1 = NL
          N2 = N0
          GO TO 9
        ENDIF
      ENDIF
C
C P is to the left of arcs N0->N1 and NL->N0.  Set N2 to the
C   next neighbor of N0 (following N1).
C
    4 LP = LPTR(LP)
        N2 = ABS(LIST(LP))
        IF ( DET(X(N0),Y(N0),Z(N0),X(N2),Y(N2),Z(N2),
     .           XP,YP,ZP) .LT. 0.D0 ) GO TO 7
        N1 = N2
        IF (N1 .NE. NL) GO TO 4
      IF ( DET(X(N0),Y(N0),Z(N0),X(NF),Y(NF),Z(NF),
     .         XP,YP,ZP) .LT. 0.D0 ) GO TO 6
C
C P is left of or on arcs N0->NB for all neighbors NB
C   of N0.  Test for P = +/-N0.
C
      IF (STORE(ABS(X(N0)*XP + Y(N0)*YP + Z(N0)*ZP))
     .   .LT. 1.D0-4.D0*EPS) THEN
C
C   All points are collinear iff P Left NB->N0 for all
C     neighbors NB of N0.  Search the neighbors of N0.
C     Note:  N1 = NL and LP points to NL.
C
    5   IF ( DET(X(N1),Y(N1),Z(N1),X(N0),Y(N0),Z(N0),
     .           XP,YP,ZP) .GE. 0.D0 ) THEN
          LP = LPTR(LP)
          N1 = ABS(LIST(LP))
          IF (N1 .EQ. NL) GO TO 14
          GO TO 5
        ENDIF
      ENDIF
C
C P is to the right of N1->N0, or P = +/-N0.  Set N0 to N1
C   and start over.
C
      N0 = N1
      GO TO 2

C     P is between arcs N0->N1 and N0->NF.
    6 N2 = NF

C   P is contained in a wedge defined by geodesics N0-N1 and
C   N0-N2, where N1 is adjacent to N2.  Save N1 and N2 to
C   test for cycling.
    7 N3 = N0
      N1S = N1
      N2S = N2
C
C     Top of edge-hopping loop:
C
    8 B3 = DET(X(N1),Y(N1),Z(N1),X(N2),Y(N2),Z(N2),XP,YP,ZP)
      IF (B3 .LT. 0.D0) THEN
C
C       Set N4 to the first neighbor of N2 following N1 (the
C       node opposite N2->N1) unless N1->N2 is a boundary arc.
C
        LP = LSTPTR(LEND(N2),N1,LIST,LPTR)
        IF (LIST(LP) .LT. 0) GO TO 9
        LP = LPTR(LP)
        N4 = ABS(LIST(LP))

C       Define a new arc N1->N2 which intersects the geodesic N0-P.

        IF ( DET(X(N0),Y(N0),Z(N0),X(N4),Y(N4),Z(N4),
     .           XP,YP,ZP) .LT. 0.D0 ) THEN
          N3 = N2
          N2 = N4
          N1S = N1
          IF (N2 .NE. N2S  .AND.  N2 .NE. N0) GO TO 8
        ELSE
          N3 = N1
          N1 = N4
          N2S = N2
          IF (N1 .NE. N1S  .AND.  N1 .NE. N0) GO TO 8
        ENDIF

C       The starting node N0 or edge N1-N2 was encountered
C       again, implying a cycle (infinite loop).  Restart
C       with N0 randomly selected.
        N0 = JRAND(N, IX,IY,IZ )
        GO TO 2
      ENDIF

C     P is in (N1,N2,N3) unless N0, N1, N2, and P are collinear
C     or P is close to -N0.
      IF (B3 .GE. EPS) THEN

C       B3 .NE. 0.
        B1 = DET(X(N2),Y(N2),Z(N2),X(N3),Y(N3),Z(N3),
     .           XP,YP,ZP)
        B2 = DET(X(N3),Y(N3),Z(N3),X(N1),Y(N1),Z(N1),
     .           XP,YP,ZP)
        IF (B1 .LT. -TOL  .OR.  B2 .LT. -TOL) THEN
C         Restart with N0 randomly selected.
          N0 = JRAND(N, IX,IY,IZ )
          GO TO 2
        ENDIF
      ELSE

C       B3 = 0 AND THUS P LIES ON N1->N2. COMPUTE
C       B1 = DET(P,N2 X N1,N2) AND B2 = DET(P,N1,N2 X N1).

        B3 = 0.D0
        S12 = X(N1)*X(N2) + Y(N1)*Y(N2) + Z(N1)*Z(N2)
        PTN1 = XP*X(N1) + YP*Y(N1) + ZP*Z(N1)
        PTN2 = XP*X(N2) + YP*Y(N2) + ZP*Z(N2)
        B1 = PTN1 - S12*PTN2
        B2 = PTN2 - S12*PTN1
        IF (B1 .LT. -TOL  .OR.  B2 .LT. -TOL) THEN

C         RESTART WITH N0 RANDOMLY SELECTED.
          N0 = JRAND(N, IX,IY,IZ )
          GO TO 2
        ENDIF
      ENDIF

C     P is in (N1,N2,N3).

      I1 = N1
      I2 = N2
      I3 = N3
      IF (B1 .LT. 0.0) B1 = 0.0
      IF (B2 .LT. 0.0) B2 = 0.0
      RETURN

C     P Right N1->N2, where N1->N2 is a boundary edge.
C     Save N1 and N2, and set NL = 0 to indicate that
C     NL has not yet been found.

    9 N1S = N1
      N2S = N2
      NL = 0

C           COUNTERCLOCKWISE BOUNDARY TRAVERSAL:

   10 LP = LEND(N2)
      LP = LPTR(LP)
      NEXT = LIST(LP)
      IF ( DET(X(N2),Y(N2),Z(N2),X(NEXT),Y(NEXT),Z(NEXT),
     .         XP,YP,ZP) .GE. 0.D0 ) THEN

C       N2 is the rightmost visible node if P Forward N2->N1
C       or NEXT Forward N2->N1.  Set Q to (N2 X N1) X N2.

        S12 = X(N1)*X(N2) + Y(N1)*Y(N2) + Z(N1)*Z(N2)
        Q(1) = X(N1) - S12*X(N2)
        Q(2) = Y(N1) - S12*Y(N2)
        Q(3) = Z(N1) - S12*Z(N2)
        IF (XP*Q(1) + YP*Q(2) + ZP*Q(3) .GE. 0.D0) GO TO 11
        IF (X(NEXT)*Q(1) + Y(NEXT)*Q(2) + Z(NEXT)*Q(3)
     .      .GE. 0.D0) GO TO 11

C       N1, N2, NEXT, and P are nearly collinear, and N2 is
C       the leftmost visible node.

        NL = N2
      ENDIF

C     Bottom of counterclockwise loop:
      N1 = N2
      N2 = NEXT
      IF (N2 .NE. N1S) GO TO 10

C     All boundary nodes are visible from P.
      I1 = N1S
      I2 = N1S
      I3 = 0
      RETURN

C     N2 is the rightmost visible node.
   11 NF = N2
      IF (NL .EQ. 0) THEN

C       Restore initial values of N1 and N2, and begin the search
C       for the leftmost visible node.
        N2 = N2S
        N1 = N1S

C           Clockwise Boundary Traversal:
   12   LP = LEND(N1)
        NEXT = -LIST(LP)
        IF ( DET(X(NEXT),Y(NEXT),Z(NEXT),X(N1),Y(N1),Z(N1),
     .           XP,YP,ZP) .GE. 0.D0 ) THEN

C         N1 is the leftmost visible node if P or NEXT is
C         forward of N1->N2.  Compute Q = N1 X (N2 X N1).
C
          S12 = X(N1)*X(N2) + Y(N1)*Y(N2) + Z(N1)*Z(N2)
          Q(1) = X(N2) - S12*X(N1)
          Q(2) = Y(N2) - S12*Y(N1)
          Q(3) = Z(N2) - S12*Z(N1)
          IF (XP*Q(1) + YP*Q(2) + ZP*Q(3) .GE. 0.D0)
     .      GO TO 13
          IF (X(NEXT)*Q(1) + Y(NEXT)*Q(2) + Z(NEXT)*Q(3)
     .        .GE. 0.D0) GO TO 13
C
C         P, NEXT, N1, and N2 are nearly collinear and N1 is the
C         rightmost visible node.
          NF = N1
        ENDIF
C
C       Bottom of clockwise loop:
        N2 = N1
        N1 = NEXT
        IF (N1 .NE. N1S) GO TO 12

C       All boundary nodes are visible from P.
        I1 = N1
        I2 = N1
        I3 = 0
        RETURN

C       N1 is the leftmost visible node.
   13   NL = N1
      ENDIF

C     NF and NL have been found.
      I1 = NF
      I2 = NL
      I3 = 0
      RETURN

C     All points are collinear (coplanar).
   14 I1 = 0
      I2 = 0
      I3 = 0
      RETURN
      END


C       ------------------ EXTRACTLINE -------------------------------

        SUBROUTINE EXTRACTLINE(X,BI,N,N2,DM,
     &                         LNB,LNE,FLTB,LTABI,TABI)

C       EXTRACT 1D FROM 2D
C       NEW VERSIONS WITH ACCELERATIONS
C       added: LNB,LNE,FLTB,LTABI,TABI al mar 2007

        REAL               TABI(0:LTABI)

        COMPLEX            BI(0:N2,-N2:N2-1), X(0:N2), BTQ
        DIMENSION          DM(2)
	DOUBLE  PRECISION  CWG
	LOGICAL            FLIP,MIRROR
	DIMENSION          WY(LNB:LNE), WX(LNB:LNE)

        FLIP = DM(1) .LT. 0.0
	CWG  = 0.0
	LWG  = 0.0
        DO  I=0,N2
           BTQ  = (0.0,0.0)
           XNEW = I * DM(1)
           YNEW = I * DM(2)
           IF (FLIP) THEN
              XNEW = -XNEW
              YNEW = -YNEW
           ENDIF

           IXN = IFIX(XNEW+0.5)
           IYN = IFIX(YNEW+SIGN(0.5,YNEW))

           IF (IXN.GE.-LNB.AND.IXN.LE.N2-1-LNE .AND.
     &	      IYN.GE.-N2-LNB.AND.IYN.LE.N2-1-LNE)  THEN
	      LWG = LWG+1
	      DO  LY=LNB,LNE
                 IYP     = IYN + LY
                 WY(LY)  = TABI(NINT(ABS(YNEW-IYP) * FLTB))
                 IXP     = IXN + LY
                 WX(LY)  = TABI(NINT(ABS(XNEW-IXP) * FLTB))
              ENDDO

C             RESTRICT LOOPS
              DO  LY=LNB,-1,1
                 IF (WY(LY) .NE. 0.0)  THEN
                    LNBY = LY
                    GOTO 1
                 ENDIF
              ENDDO
              LNBY=0

1             DO  LY=LNE,1,-1
                 IF (WY(LY) .NE. 0.0)  THEN
                    LNEY=LY
                    GOTO 2
                 ENDIF
              ENDDO
              LNEY=0
2             DO  LY=LNB,-1,1
                 IF (WX(LY).NE.0.0)  THEN
                    LNBX=LY
                    GOTO 3
                 ENDIF
              ENDDO
              LNBX=0

3             DO  LY=LNE,1,-1
                 IF (WX(LY).NE.0.0)  THEN
                    LNEX=LY
                    GOTO 4
                 ENDIF
              ENDDO
              LNEX=0

4             CONTINUE	
              DO  LY=LNBY,LNEY
                 IYP = IYN + LY
                 DO  LX=LNBX,LNEX
                    IXP = IXN + LX
C                   GET THE WEIGHT
                    WG  = WX(LX)*WY(LY)
                    BTQ = BTQ + BI(IXP,IYP) * WG
                    CWG=CWG+WG
                 ENDDO
              ENDDO
           ELSE

C          SPECIAL CASES OF POINTS "STICKING OUT"
	   LWG=LWG+1
           DO  LY=LNB,LNE
              IYP = IYN + LY
              WY(LY)  = TABI(NINT(ABS(YNEW-IYP) * FLTB))
              IXP = IXN + LY
              WX(LY)  = TABI(NINT(ABS(XNEW-IXP) * FLTB))
           ENDDO

C          RESTRICT LOOPS
	   DO  LY=LNB,-1,1
	      IF (WY(LY).NE.0.0)  THEN
                 LNBY=LY
                 GOTO 11
              ENDIF
           ENDDO
           LNBY=0

11          DO  LY=LNE,1,-1
               IF (WY(LY).NE.0.0)  THEN
                  LNEY=LY
                  GOTO 12
               ENDIF
             ENDDO
             LNEY=0

12           DO  LY=LNB,-1,1
                IF(WX(LY).NE.0.0)  THEN
                   LNBX=LY
                   GOTO 13
                ENDIF
             ENDDO
             LNBX=0

13           DO  LY=LNE,1,-1
                 IF (WX(LY).NE.0.0)  THEN
                    LNEX=LY
                    GOTO 14
                 ENDIF
              ENDDO
              LNEX=0

14	      CONTINUE
              DO  LY=LNBY,LNEY
                 IYP = IYN + LY
                    DO  LX=LNBX,LNEX
                       IXP = IXN + LX
C                      GET THE WEIGHT
                       WG=WX(LX)*WY(LY)

                       MIRROR=.FALSE.
                       IXT=IXP
                       IYT=IYP
                       IF ( IXT.GT.N2.OR.IXT.LT.-N2 )  THEN
                          IXT=ISIGN(N-IABS(IXT),IXT)
                          IYT=-IYT
                          MIRROR = .NOT.MIRROR
	               ENDIF

	               IF ( IYT.GE.N2.OR.IYT.LT.-N2)  THEN
	               IF (IXT.NE.0)  THEN
	                  IXT=-IXT
	                  IYT=ISIGN(N-IABS(IYT),IYT)
	                  MIRROR=.NOT.MIRROR
	               ELSE
	                  IYT=IYT-ISIGN(N,IYT)
	               ENDIF
	            ENDIF

	            IF (IXT .LT. 0)  THEN
	               IXT    = -IXT
	               IYT    = -IYT
	               MIRROR =.NOT.MIRROR
	            ENDIF
                    IF(IYT.EQ.N2) IYT=-N2

                    IF(MIRROR)  THEN
                       BTQ = BTQ + CONJG(BI(IXT,IYT)) * WG
                    ELSE
                       BTQ = BTQ + BI(IXT,IYT) * WG
                    ENDIF
                    CWG=CWG+WG
                 ENDDO
              ENDDO
	   ENDIF

	   X(I)=BTQ

C       END I LOOP
        ENDDO

        IF (FLIP)  THEN
	   X = CONJG(X)/CWG*LWG
        ELSE
	   X = X/CWG*LWG
        ENDIF

        END


C       ------------------ PUTLINE3 ----------------------------------

C       OLD VERSION ACCELERATED
C       ADDED: LNB,LNE,FLTB,LTABI,TABI AL MAR 2007

        SUBROUTINE PUTLINE3(N,N2,X,BI,DM,DM3,CWG,LWG,
     &                      LNB,LNE,FLTB,LTABI,TABI)

        REAL           :: TABI(0:LTABI)
        COMPLEX           BI(0:N2,-N2:N2-1,-N2:N2-1),X(0:N2),BTQ
        DIMENSION         DM(2),DM3(6)
	DOUBLE PRECISION  CWG
 	DIMENSION         WZ(LNB:LNE),WY(LNB:LNE),WX(LNB:LNE)

        DO  I=-N2,N2
	 IF (I.GE.0)  THEN
	    BTQ=X(I)
	 ELSE
	    BTQ=CONJG(X(-I))
	 ENDIF
         XPL  = I * DM(1)
         YPL  = I * DM(2)
         XNEW = XPL * DM3(1) + YPL * DM3(4)
         YNEW = XPL * DM3(2) + YPL * DM3(5)
         ZNEW = XPL * DM3(3) + YPL * DM3(6)
         IXN = IFIX(XNEW+SIGN(0.5,XNEW))
	 IF (.NOT.(IXN.LT.-LNE .AND. IXN+LNB.GT.-N2) ) THEN
            IYN = IFIX(YNEW+SIGN(0.5,YNEW))
	    IF (.NOT. (IYN.EQ.N2) )  THEN
            IZN = IFIX(ZNEW+SIGN(0.5,ZNEW))
	    IF (.NOT. (IZN.EQ.N2) )  THEN
            DO  LZ=LNB,LNE
               IZP     = IZN + LZ
               WZ(LZ)  = TABI(NINT(ABS(ZNEW-IZP) * FLTB))
               IYP     = IYN + LZ
               WY(LZ)  = TABI(NINT(ABS(YNEW-IYP) * FLTB))
               IXP     = IXN + LZ
               WX(LZ)  = TABI(NINT(ABS(XNEW-IXP) * FLTB))
            ENDDO

C           RESTRICT LOOPS
            DO  LY=LNB,-1,1
               IF (WY(LY).NE.0.0)  THEN
                  LNBY=LY
                  GOTO 1
               ENDIF
            ENDDO
            LNBY=0

1           DO  LY=LNE,1,-1
               IF (WY(LY).NE.0.0)  THEN
                  LNEY=LY
                  GOTO 2
               ENDIF
            ENDDO
            LNEY=0

2           DO  LY=LNB,-1,1
               IF (WZ(LY).NE.0.0)  THEN
                  LNBZ=LY
                  GOTO 3
               ENDIF
            ENDDO
            LNBZ=0

3           DO  LY=LNE,1,-1
               IF (WZ(LY).NE.0.0)  THEN
               LNEZ=LY
               GOTO 4
               ENDIF
            ENDDO
            LNEZ=0

4	    CONTINUE	

C           SPECIAL CASES OF POINTS "STICKING OUT"
	    IF (IXN+LNB.LE.-N2.AND.IXN.GE.-N2)  THEN
C              POINTS EXCEED LEFT BORDER FOR IX<0, THEY HAVE TO BE 
C              REFLECTED TO THE RIGHT
               LWG=LWG+1
               LE = -N2-IXN
               DO  LZ=LNBZ,LNEZ
                      IZP = IZN + LZ
                         DO  LY=LNBY,LNEY
                             IYP = IYN + LY
	 			TY = WZ(LZ) * WY(LY)
                                DO  LX=LNB,LE
				  IXP = IXN + LX
C                                  GET THE WEIGHT
                                   WG= WX(LX) * TY
             BI(N+IXP,IYP,IZP) = BI(N+IXP,IYP,IZP) + BTQ * WG
				    CWG=CWG+WG
                                ENDDO
                          ENDDO
               ENDDO

	 ELSEIF(IYN+LNE.GT.N2-1)  THEN
C              POINTS EXCEED IY>N2-1 BORDER, HAVE TO BE 
C              REFLECTED TO IY<0
                    LWG=LWG+1

                    DO  LZ=LNBZ,LNEZ
                      IZP = IZN + LZ
                        DO  LY=LNBY,LNEY
                             IYP = IYN + LY
	 			TY = WZ(LZ) * WY(LY)
			     IF(IYP.GT.N2-1)  IYP=IYP-N
                    		LB = MAX0(0,IXN+LNB)
                    		LE = IXN+LNE
                                DO  IXP=LB,LE
C                                  GET THE WEIGHT
                                   WG= WX(IXP-IXN) * TY
                BI(IXP,IYP,IZP) = BI(IXP,IYP,IZP) + BTQ * WG
				    CWG=CWG+WG
                                ENDDO
                          ENDDO
                    ENDDO

	 ELSEIF(IYN+LNB.LT.-N2)  THEN
C  Points exceed IY<-N2 border, have to be reflected to IY>0
				    LWG=LWG+1
                    DO  LZ=LNBZ,LNEZ
                      IZP = IZN + LZ
                          DO  LY=LNBY,LNEY
                             IYP = IYN + LY
	 			TY = WZ(LZ) * WY(LY)
			     IF(IYP.LT.-N2)  IYP=N+IYP
                    		LB = MAX0(0,IXN+LNB)
                    		LE = IXN+LNE
                                DO  IXP=LB,LE
C                                  GET THE WEIGHT
                                   WG= WX(IXP-IXN) * TY
             BI(IXP,IYP,IZP) = BI(IXP,IYP,IZP) + BTQ * WG
				    CWG=CWG+WG
                                ENDDO
                          ENDDO
                    ENDDO

	 ELSEIF(IZN+LNE.GT.N2-1)  THEN
C  Points exceed IZ>N2-1 border, have to be reflected to IZ<0
 				    LWG=LWG+1
                    DO  LZ=LNBZ,LNEZ
                      IZP = IZN + LZ
		      IF(IZP.GT.N2-1)  IZP=IZP-N
                        DO  LY=LNBY,LNEY
                             IYP = IYN + LY
	 			TY = WZ(LZ) * WY(LY)
                    		LB = MAX0(0,IXN+LNB)
                    		LE = IXN+LNE
                                DO  IXP=LB,LE
C                                  GET THE WEIGHT
                                   WG= WX(IXP-IXN) * TY
               BI(IXP,IYP,IZP) = BI(IXP,IYP,IZP) + BTQ * WG
				    CWG=CWG+WG
                                ENDDO
                          ENDDO
                    ENDDO

	 ELSEIF(IZN+LNB.LT.-N2)  THEN
C  Points exceed IZ<-N2 border, have to be reflected to IZ>0
				    LWG=LWG+1
                    DO  LZ=LNBZ,LNEZ
                      IZP = IZN + LZ
		      IF(IZP.LT.-N2)  IZP=N+IZP
                          DO  LY=LNBY,LNEY
                             IYP = IYN + LY
	 			TY = WZ(LZ) * WY(LY)
                    		LB = MAX0(0,IXN+LNB)
                    		LE = IXN+LNE
                                DO  IXP=LB,LE
C                                  GET THE WEIGHT
                                   WG= WX(IXP-IXN) * TY
               BI(IXP,IYP,IZP) = BI(IXP,IYP,IZP) + BTQ * WG
				    CWG=CWG+WG
                                ENDDO
                          ENDDO
                    ENDDO

	 ELSE
C Points left are within the proper rectangle
C                   MAKE SURE THAT LOWER LIMIT FOR X DOES NOT GO BELOW 0
C  Points which exceed IX=0 border have to be truncated
                    LB = MAX0(0,IXN+LNB)
C                   MAKE SURE THAT UPPER LIMIT FOR X DOES NOT GO ABOVE N2
C  Points which exceed IX=N2 border have to be truncated
		    LE = MIN0(N2,IXN+LNE)
				    LWG=LWG+1
                    DO  LZ=LNBZ,LNEZ
                      IZP = IZN + LZ
                           DO  LY=LNBY,LNEY
                             IYP = IYN + LY
	 			TY = WZ(LZ) * WY(LY)
                                DO  IXP=LB,LE
C                                  GET THE WEIGHT
                                   WG= WX(IXP-IXN) * TY
               BI(IXP,IYP,IZP) = BI(IXP,IYP,IZP) + BTQ * WG
				    CWG=CWG+WG
                                ENDDO
                          ENDDO
                    ENDDO
	 ENDIF
	 ENDIF
C  
	ENDIF
	ENDIF
C          END I LOOP
        ENDDO
        END










