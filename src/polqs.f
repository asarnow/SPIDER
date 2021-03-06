C ++********************************************************************
C                                                                      *
C  POLQS.F                                                             *
C                  OPFILEC                        FEB  03 ARDEAN LEITH *
C                  FILELIST                       FEB  06 ARDEAN LEITH *
C                  MAXNAM                         JUL  14 ARDEAN LEITH *
C                                                                      *
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
C                                                                      *
C  POLQS(MAXMEM)                                                       *
C                                                                      *
C  PURPOSE:                                                            *
C                                                                      *
C  PARAMETERS:                                                         *
C                                                                      *
C   02/22/07   USED FILELIST 
C
C   07/14/05   Corrected minor bug with 1D projection
C              OpenMP switched off - it does not work on Linux
C
C   07/29/99   PARALLEL, F90 VERSION; CORRECTED ON 02/13/02
C
C   02/11/99   TRIGONOMETRIC FUNCTIONS CHANGED TO F90.
C
C                                     08/28/97
C  DISTRIBUTION OF ANGLES IN ANGTAB CHANGED TO AGREE WITH CURRENT VO EA
C                                     10/3/96
C  COMPLETE VERSION FOR SPIDER
C  CALCULATES THE 1D PROJECTIONS OF 2D IMAGES (NOT NORMALIZED).
C                                                  11/19/90
C                                     05/16/95
C  SAME AS POLQT, BUT FOURIER VERSION ...
C  WEIGHTS ON CIRCLE AS IN POLQW
C  PROBLEM OF DUPLICATED LINES IN WEIGHTING SOLVED
C  WEIGHTS TAKEN OUT OF THE DO-LOOP
C  CORRECT LINE CALCULATION, EXCLUSION OF IDENTICAL DIRECTIONS ...
C
C **********************************************************************

	SUBROUTINE POLQS(MAXMEM)

	PARAMETER  (NILMAX=4000)
        INCLUDE 'CMBLOCK.INC'
        INCLUDE 'CMLIMIT.INC'
        INCLUDE 'F90ALLOC.INC'

	CHARACTER(LEN=MAXNAM) :: FINPAT,FINPIC,FINFO,FINDOC
	COMMON  /F_SPEC/         FINPAT,FINPIC,FINFO,FINDOC,NLET

	CHARACTER*1  MODIS
	COMMON  /POLS/ MODIS

	COMMON  BUF(1024)
	COMMON /PAR/  LDP,NM,LDPNM
	DIMENSION  TARRAY(2)

	REAL, ALLOCATABLE, DIMENSION(:,:,:) ::  PRJ
	REAL, ALLOCATABLE, DIMENSION(:,:)   ::  P
	REAL,  DIMENSION(:,:), POINTER      ::  IPQ

	DATA  INPIC/99/,INDOC/96/,NDOC/95/

C       N - LINEAR DIMENSION OF 2D IMAGE
C       NANG - NUMBER OF ANGLES
C       NIMA - NUMBER OF 2D IMAGES

	NMAX   = NIMAX
        CALL FILELIST(.TRUE.,NDOC,FINPAT,NLET,INUMBR,NMAX,NIMA,
     &                'INPUT FILE TEMPLATE (E.G. PIC****)',IRTFLG)
        IF (IRTFLG .NE. 0) RETURN
C       GET FIRST PICTURE TO DETERMINE DIMS
        CALL FILGET(FINPAT,FINPIC,NLET,INUMBR(1),IRTFLG)
        IF (IRTFLG .NE. 0) RETURN

	MAXIM = 0
	CALL OPFILEC(0,.FALSE.,FINPIC,INPIC,'O',IFORM,
     &              N,NROW,NSL,MAXIM,' ',.FALSE.,IRTFLG)
 	IF (IRTFLG.NE.0)  RETURN
	CLOSE(INPIC)

C       NANG - TOTAL NUMBER OF ANGLES
	CALL RDPRMI(LENPROJ,NANG,NOT_USED,'LENGTH OF LINE PROJECTION')
	CALL RDPRM2(F1,F2,NOT_USED,'MINIMUM, MAXIMUM FREQUENCY')

	IF (F1.LT.0.0 .OR. F2.GT.0.5 .OR. F1.GT.F2)  THEN
	   CALL ERRT(14,'OP',IER)
	   RETURN
	ENDIF
	IF (F1.EQ.0.0 .AND. F2.EQ.0.0)  THEN
	   F1=0.0
	   F2=0.5
	ENDIF
	CALL  RDPRMI(IDPSI,NANG,NOT_USED, 'ACCURACY OF THETA')

C  PAP  07/14/05
C  I cannot fix the code for arbitrary NANG (number of psi angles).
C  The reason is that in too many places the code depends on the assumption that NANG=180.
C  The main problem is in SPIN, where the spin step is IDPSI, which again can be any...
C  Since all angles are coded by their integer numbers (i.e., l1=3 means angle 3*180/NANG)
C   the corrections are virtually impossible without major rewriting of the code.
C	IF (NANG.EQ.0)  THEN
C          DEFAULT 1 DEGREE ACCURACY FOR PSI
	   NANG=180
C	ELSE
C	   IDUM=180/NANG
C	   IF(IDUM*NANG.NE.180)  THEN
C	   	WRITE(NOUT,*)  '  180 has to be divisible by NANG'
C	   	CALL  ERRT(14,'OP',NE)
C		GOTO 991
C	   ENDIF
C	   NANG=IDUM
C	ENDIF

C       DEFAULT 5 DEGREES ACCURACY FOR THETA
	IF (IDPSI.EQ.0)  IDPSI=5 

	CALL RDPRMI(MAXIT,IDUM,NOT_USED, 'MAXIMUM NUMBER OF CYCLES')

	DPSI=IDPSI
	CALL  GENAT(BUF,DPSI,NANGT,.FALSE.)

	MODIS = 'E'

        RI      = LENPROJ/2
	LENPROJ = LENPROJ/2
	LENPROJ = LENPROJ*2+1
	IF (LENPROJ .GT. N-2) THEN
	   LENRPOJ = N-2
	   IF (MOD(N,2) .EQ. 0)  LENRPOJ = LENRPOJ-1
	   WRITE(NOUT,*)  
     &	      'LENGTH OF PROJECTION TOO LARGE!  LIMITED TO ',LENRPOJ
	ENDIF

C       ALWAYS SKIP (0) TERM, LENB has to be odd to fall on the real part
	LENB=MAX(NINT(2*F1*LENPROJ+1),3)
	LENB=LENB+MOD(LENB+1,2)
	LENE=MIN(NINT(2*F2*LENPROJ),LENPROJ-1)
	LENF=LENE-LENB+1

        LDP=N/2+1
        LDPNM=LENPROJ/2+1

	ALLOCATE(PRJ(LENF,2*NANG,NIMA),STAT=IRTFLG)
	IF (IRTFLG.NE.0) THEN
            CALL ERRT(46,'OP, PRJ',IER)
            RETURN
        ENDIF

	TM1 = ETIME(TARRAY)
 	CALL RDL_P(N,NANG,LENPROJ,RI,INUMBR,NIMA,PRJ,LENB,LENF)

	TM2 = ETIME(TARRAY)
	WRITE(NOUT,*) ' TIME FOR READING PROJECTIONS = ',TM2-TM1

	MAXKEY = NIMA
	MAXREG = 4
	CALL GETDOCDAT('DOCUMENT WITH INITIAL ANGLES',.TRUE.,FINDOC,
     &		INDOC,.FALSE.,MAXREG,MAXKEY,IPQ,IRTFLG)
	IF (IRTFLG.NE.0) RETURN

	ALLOCATE(P(MAXREG-1,NIMA),STAT=IRTFLG)
	IF (IRTFLG.NE.0) CALL ERRT(46,'OP, P',IER)

	DO I=1,MAXKEY
	   DO J=1,3
              P(J,I) = IPQ(J+1,I)
	   ENDDO
	ENDDO
C       IPQ NO LONGER NEEDED
	DEALLOCATE(IPQ)

	TM3 = ETIME(TARRAY)
	CALL FCANG(NANG,NIMA,LENF,MAXIT,P,PRJ,NANGT,IDPSI)

	TM4 = ETIME(TARRAY)

	WRITE(NOUT,*) ' TIME FOR ANGLE SEARCH = ',TM4-TM3

991	IF(ALLOCATED(P))    DEALLOCATE(P)
	IF(ALLOCATED(PRJ))  DEALLOCATE(PRJ)
	END


	SUBROUTINE FCANG(NANG,NIMA,LENPROJ,MAXIT,
     &		         P,PRJ,NANGT,IDPSI)

        INCLUDE 'CMBLOCK.INC' 

	PARAMETER  (NDLI=4)
	DIMENSION  DLIST(NDLI)
	DIMENSION  P(3,NIMA)
	DIMENSION  PRJ(LENPROJ,2*NANG,NIMA)
	REAL, ALLOCATABLE, DIMENSION(:,:) ::  ANGTAB
	CHARACTER*8 CTIME
	DOUBLE PRECISION  DIS(NIMA)
	DOUBLE PRECISION  DIST

	DATA  NDOC/77/

C       NEW TABLES.
C       ANGTAB(1  - THETA
C       ANGTAB(2  - PHI
	LOGICAL CHANGE,CHANGEPOS
C       SET FIRST THREE ANGLES TO ZERO FOREVER ...
C	P(1,1)=0.0
C	P(2,1)=0.0
C	P(3,1)=0.0

	ALLOCATE(ANGTAB(2,NANGT),STAT=IRTFLG)
	IF (IRTFLG.NE.0) CALL  ERRT(46,'OP, ANGTAB',IER)

	DPSI=IDPSI
	CALL GENAT(ANGTAB,DPSI,NANGT,.TRUE.)

	FVALUE=DIST(NIMA,NANG,LENPROJ,PRJ,P)
	WRITE(NOUT,2177)  FVALUE
2177	FORMAT(' INITIAL DISCREPANCY ',1PE10.3)
	WRITE(NOUT,2178)
2178	FORMAT(' INITIAL ANGLES',5X,'PSI',7X,'THETA',5X,'PHI')

C       TRY TO SPIN
	ITER=0
507	CHANGE=.TRUE.
	CHANGEPOS=.FALSE.
	ITER=ITER+1
	DO  I=1,NIMA
	   WRITE(NOUT,2179)  I,(P(J,I),J=1,3)
	ENDDO

2179	FORMAT(I15,3(3X,F7.2))
	CALL  MYTIME(CTIME)

	WRITE(NOUT,777)  CTIME
777	FORMAT(' ENTERED SPIN : ',A8)

	DO  ISPIN=1,NIMA

C	   CALL  SPINSPIN
C     &	      (NIMA,NANG,LENPROJ,PRJ,P,
C     &		ISPIN,IDPSI,ANGTAB,NANGT,IPSIM,IANGMIN,CHANGE,
C     &		L1,L2,LT,LT1,LT2,LORD,W)

	    CALL  SPIN(NIMA,NANG,LENPROJ,PRJ,P,
     &		ISPIN,IDPSI,ANGTAB,NANGT,IPSIM,IANGMIN,CHANGE)
	    IF (CHANGE)  THEN
	       CHANGEPOS=.TRUE.
	       P(1,ISPIN)=IPSIM
	       P(2,ISPIN)=ANGTAB(1,IANGMIN)
	       P(3,ISPIN)=ANGTAB(2,IANGMIN)
	   ENDIF
	ENDDO
	IF (CHANGEPOS)  THEN
	   FVALUE=DIST(NIMA,NANG,LENPROJ,PRJ,P)
	   WRITE(NOUT,2181)  ITER,FVALUE
2181	   FORMAT(' CYCLE',I9,'  NEW VALUE=',1PE10.3)
	   DLIST(1)=-1
	   DLIST(2)=ITER
	   DLIST(3)=FVALUE
	   CALL SAVD(NDOC,DLIST,3,IRTFLG)
	   DO I=1,NIMA
	      DLIST(1)=I
	      DO J=1,3
	        DLIST(J+1)=P(J,I)
	      ENDDO
	      CALL SAVD(NDOC,DLIST,NDLI,IRTFLG)
	   ENDDO
	ENDIF
	IF (CHANGEPOS.AND.(MAXIT.EQ.0.OR.ITER.LT.MAXIT))  GOTO  507
        CLOSE(NDOC)
	CALL  SAVDC
	DEALLOCATE(ANGTAB)
	END



	SUBROUTINE SPIN(NIMA,NANG,LENPROJ,PRJ,P,
     &		ISPIN,IDPSI,ANGTAB,NANGT,MMIN,LMIN,CHANGE)

	DIMENSION  P(3,NIMA),PRJ(LENPROJ,2*NANG,NIMA)
	DIMENSION  ANGTAB(2,NANGT)
	DOUBLE PRECISION DMI(NANGT),DMIN
	DIMENSION  LMI(NANGT),MMI(NANGT)
C,EDL1
	LOGICAL CHANGE
C       LENGTH OF ARRAYS NEEDED IN DWTG
	LNM2=NIMA*(NIMA-1)/2

C       SPIN
Cc$omp parallel do private(l)
	DO  L=1,NANGT
	   CALL  DWTG(P,ANGTAB(1,L),PRJ,ISPIN,NIMA,NANG,LENPROJ,
     &		    L,IDPSI,DMI(L),LMI(L),MMI(L),LNM2)
	ENDDO

	DMIN=1.0D23
	LMIN=-1
	MMIN=-1
	DO  2 L=1,NANGT
	   DO I=1,NIMA
	     IF(I.NE.ISPIN.AND.
     &	       P(2,I).EQ.ANGTAB(1,L).AND.P(3,I).EQ.ANGTAB(2,L)) GOTO 2
	   ENDDO
	   IF (DMI(L).LT.DMIN)  THEN
	      DMIN=DMI(L)
	      LMIN=LMI(L)
	      MMIN=MMI(L)
	   ENDIF
2	CONTINUE

C       CHECK WHETHER POSITION CHANGED
C	PRINT  *,NANGT,DMIN,LMIN,MMIN
C	PRINT  *,FLOAT(MMIN),ANGTAB(1,LMIN),ANGTAB(2,LMIN)
	IF (P(1,ISPIN).EQ.FLOAT(MMIN))  THEN
	   IF (P(2,ISPIN).EQ.ANGTAB(1,LMIN))  THEN
	      IF (P(3,ISPIN).EQ.ANGTAB(2,LMIN))  THEN
	         CHANGE = .FALSE.
	         RETURN
	      ENDIF
	   ENDIF
	ENDIF
	CHANGE = .TRUE.
	END



	SUBROUTINE  DWTG(PP,ANGTAB,PRJ,ISPIN,NIMA,NANG,LENPROJ,
     &		         L,IDPSI,DMIN,LMIN,MMIN,LNM2)

	DIMENSION  PP(3,NIMA),ANGTAB(2),PRJ(LENPROJ,2*NANG,NIMA)

C       AUTOMATIC ARRAYS
	DIMENSION  L1(LNM2),L2(LNM2),LT(LNM2)
	DIMENSION  W(LNM2),LT1(LNM2),LT2(LNM2),LORD(LNM2)
	DIMENSION  P(3,NIMA)
	DOUBLE PRECISION DMIN,DID,DIST

	DMIN=1.0D23
	LMIN=-1
	MMIN=-1
	DO I=1,NIMA
	   IF(I.NE.ISPIN.AND.
     &	    PP(2,I).EQ.ANGTAB(1).AND.PP(3,I).EQ.ANGTAB(2)) RETURN
	ENDDO

	P=PP

	NIM=NIMA-1

	P(2,ISPIN)=ANGTAB(1)
	P(3,ISPIN)=ANGTAB(2)
	P(1,ISPIN)=0.0	

	K=0
	DO I=1,NIMA-1
	   DO J=I+1,NIMA
	      IF(I.EQ.ISPIN.OR.J.EQ.ISPIN) THEN
	        K=K+1
	        LORD(K)=K
	        CALL  CALDILW1(P(1,I),P(1,J),NANG,L1(K),L2(K))
	       ENDIF
	   ENDDO
	ENDDO

	K=0
	DO I=1,NIMA-1
	   DO J=I+1,NIMA
	       IF(I.EQ.ISPIN) THEN
	          K=K+1
	          LT(K)=L1(K)
	          IF(LT(K).GT.NANG)  LT(K)=LT(K)-NANG
	       ELSEIF(J.EQ.ISPIN)  THEN
	          K=K+1
	          LT(K)=L2(K)
	          IF(LT(K).GT.NANG)  LT(K)=LT(K)-NANG
	       ENDIF
	   ENDDO
	ENDDO

C       FROM SMALL TO LARGE
	CALL SORT2(LT,LORD,NIM)

	QT=1.0
	DO K=2,NIM-1
	   IF (LT(K).NE.LT(K-1))  THEN
	      W(LORD(K))=FLOAT(LT(K+1)-LT(K-1))/2
	      QT=1.0
	   ELSE
	      QT=QT+1.0
	      W(LORD(K))=-QT
	   ENDIF
	ENDDO

	IF (LT(NIM).NE.LT(NIM-1))  THEN
            W(LORD(NIM))=FLOAT(LT(1)+NANG-LT(NIM-1))/2
	ELSE
            QT=QT+1
	    W(LORD(NIM))=-QT
	ENDIF
	W(LORD(1))=FLOAT(LT(2)-LT(NIM)+NANG)/2

	K=1
105	K=K+1
	IF (W(LORD(K)).LT.0.0)  THEN
	   KB=K-1
	   K=KB
106	   K=K+1
	   IF(W(LORD(K)).LT.0.0)  THEN
              IF(K.NE.NIM) GOTO 106
	   ELSE
	      K=K-1
	   ENDIF
	   W(LORD(KB))=-W(LORD(KB))/W(LORD(K))
	   DO   KK=KB+1,K
	      W(LORD(KK))=W(LORD(KB))
	   ENDDO
	ENDIF
	IF(K.LT.NIM) GOTO  105

	WT=0.0
	DO K=1,NIM
	    WT=WT+W(K)
	ENDDO
	DO K=1,NIM
	   W(K)=W(K)/WT
	ENDDO

	DO  M=0,359,IDPSI
	   P(1,ISPIN) = M	

C          GET LINES ROTATED BY PSI ANGLE
           K=0
           DO I=1,NIMA-1
              DO J=I+1,NIMA
                 IF (I.EQ.ISPIN.OR.J.EQ.ISPIN) THEN
                    K=K+1
                    IF (L1(K).EQ.NANG/2+1.OR.L1(K).EQ.271 .OR. 
     &                 L2(K).EQ.91.OR.L2(K).EQ.271)  THEN
                       CALL CALDILW1(P(1,I),P(1,J),NANG,LT1(K),LT2(K))
                    ELSE
                       IF(I.EQ.ISPIN)  THEN
                          LT1(K)=MOD(L1(K)-M+2*NANG-1,2*NANG)+1
                          LT2(K)=L2(K)
                       ELSE
                          LT1(K)=L1(K)
                          LT2(K)=MOD(L2(K)-M+2*NANG-1,2*NANG)+1
                       ENDIF
                    ENDIF
                 ENDIF
              ENDDO
	   ENDDO
 
C          DO THE DISTANCE WITH WEIGHTING
	   DIST=0.0D0
	   K=0
	   DO I=1,NIMA-1
	      DO J=I+1,NIMA
	        IF (I.EQ.ISPIN.OR.J.EQ.ISPIN) THEN
	           K=K+1
	   	   if (w(k).le.0.0)  then
		      print *,' incorrect weight',k,w(k)
		      stop
		   endif
	           DIST = DIST+EDL1(PRJ(1,LT1(K),I),
     &                   PRJ(1,LT2(K),J),LENPROJ)*W(K)
               ENDIF
            ENDDO
         ENDDO

	IF (DIST.LT.DMIN)  THEN
            DMIN=DIST
            LMIN=L
            MMIN=M
            ENDIF
         ENDDO
C       END OF DO-LOOP OVER M (PSI ANGLE)
	END
	

	SUBROUTINE  SPINSPIN(NIMA,NANG,LENPROJ,PRJ,P,
     &		ISPIN,IDPSI,ANGTAB,NANGT,MMIN,LMIN,CHANGE,
     &		L1,L2,LT,LT1,LT2,LORD,W)

	DIMENSION  P(3,NIMA),PRJ(LENPROJ,2*NANG,NIMA),PTMP(3)
	DIMENSION  ANGTAB(2,NANGT)
	DOUBLE PRECISION DMIN,DID,DIST
C,EDL1
	LOGICAL CHANGE

	DIMENSION  L1(*),L2(*),LT(*),LT1(*),LT2(*),LORD(*)
	DIMENSION  W(*)
	NIM=NIMA-1
C       SPIN
	DMIN=1.0E23
	LMIN=-1
	MMIN=-1
	DO  1  L=1,NANGT
	DO  I=1,NIMA
	IF(I.NE.ISPIN.AND.
     &	P(2,I).EQ.ANGTAB(1,L).AND.P(3,I).EQ.ANGTAB(2,L)) GOTO 1
	ENDDO
	PTMP(2)=P(2,ISPIN)	
	PTMP(3)=P(3,ISPIN)
	PTMP(1)=P(1,ISPIN)	
	P(2,ISPIN)=ANGTAB(1,L)
	P(3,ISPIN)=ANGTAB(2,L)
	P(1,ISPIN)=0.0	

	K=0
	DO  14  I=1,NIMA-1
	DO  14  J=I+1,NIMA
	IF (I.EQ.ISPIN.OR.J.EQ.ISPIN) THEN
	   K=K+1
	   LORD(K)=K
	   CALL  CALDILW1(P(1,I),P(1,J),NANG,L1(K),L2(K))
	ENDIF
14	CONTINUE

	K=0
	DO  101  I=1,NIMA-1
	DO  101  J=I+1,NIMA
	IF (I.EQ.ISPIN) THEN
	   K=K+1
	   LT(K)=L1(K)
	   IF (LT(K).GT.NANG)  LT(K)=LT(K)-NANG
	ELSEI F(J.EQ.ISPIN)  THEN
	   K=K+1
	   LT(K)=L2(K)
	   IF(LT(K).GT.NANG)  LT(K)=LT(K)-NANG
	ENDIF
101	CONTINUE

C       FROM SMALL TO LARGE
	CALL  SORT2(LT,LORD,NIM)

	QT=1.0
	DO  102  K=2,NIM-1
	IF(LT(K).NE.LT(K-1))  THEN
	W(LORD(K))=FLOAT(LT(K+1)-LT(K-1))/2
	QT=1.0
	ELSE
	QT=QT+1.0
	W(LORD(K))=-QT
	ENDIF
102	CONTINUE
	IF(LT(NIM).NE.LT(NIM-1))  THEN
	W(LORD(NIM))=FLOAT(LT(1)+NANG-LT(NIM-1))/2
	ELSE
	QT=QT+1
	W(LORD(NIM))=-QT
	ENDIF
	W(LORD(1))=FLOAT(LT(2)-LT(NIM)+NANG)/2
C
	K=1
105	K=K+1
	IF (W(LORD(K)).LT.0.0)  THEN
	   KB=K-1
	   K=KB
106	   K=K+1
	   IF (W(LORD(K)).LT.0.0)  THEN
              IF(K.NE.NIM) GOTO 106
	   ELSE
	      K=K-1
	   ENDIF
	   W(LORD(KB))=-W(LORD(KB))/W(LORD(K))
	   DO  107  KK=KB+1,K
107	   W(LORD(KK))=W(LORD(KB))
	ENDIF
	IF (K.LT.NIM) GOTO  105
	
	WT=0.0
	DO K=1,NIM
	   WT=WT+W(K)
	ENDDO
	DO K=1,NIM
	   W(K)=W(K)/WT
	ENDDO

	DO  2  M=0,359,IDPSI
	P(1,ISPIN)=M	

C  GET LINES ROTATED BY PSI ANGLE
	K=0
	DO   I=1,NIMA-1
	 DO   J=I+1,NIMA
	  IF(I.EQ.ISPIN.OR.J.EQ.ISPIN) THEN
	   K=K+1
	IF(L1(K).EQ.91.OR.L1(K).EQ.271.OR.L2(K).EQ.91.OR.L2(K).EQ.271)
     &      THEN
	    CALL  CALDILW1(P(1,I),P(1,J),NANG,LT1(K),LT2(K))
	ELSE
	    IF(I.EQ.ISPIN)  THEN
	     LT1(K)=MOD(L1(K)-M+2*NANG-1,2*NANG)+1
	     LT2(K)=L2(K)
	    ELSE
	     LT1(K)=L1(K)
	     LT2(K)=MOD(L2(K)-M+2*NANG-1,2*NANG)+1
	    ENDIF
	ENDIF
	   ENDIF
	 ENDDO
	ENDDO
 
C       DO THE DISTANCE WITH WEIGHTING
	DIST=0.0D0
	K=0
	DO   I=1,NIMA-1
	 DO   J=I+1,NIMA
	  IF(I.EQ.ISPIN.OR.J.EQ.ISPIN) THEN
	   K=K+1
	   DID=EDL1(PRJ(1,LT1(K),I),PRJ(1,LT2(K),J),LENPROJ)
	   DIST=DIST+DID*W(K)
	  ENDIF
	 ENDDO
	ENDDO
C
	IF(DIST.LT.DMIN)  THEN
	 DMIN=DIST
	 LMIN=L
	 MMIN=M
	ENDIF
2	CONTINUE
	P(2,ISPIN)=PTMP(2)	
	P(3,ISPIN)=PTMP(3)
	P(1,ISPIN)=PTMP(1)
1	CONTINUE
C       CHECK WHETHER POSITION CHANGED
C	PRINT  *,NANGT,DMIN,LMIN,MMIN
C	PRINT  *,FLOAT(MMIN),ANGTAB(1,LMIN),ANGTAB(2,LMIN)
	IF(P(1,ISPIN).EQ.FLOAT(MMIN))  THEN
	 IF(P(2,ISPIN).EQ.ANGTAB(1,LMIN))  THEN
	  IF(P(3,ISPIN).EQ.ANGTAB(2,LMIN))  THEN
	   CHANGE=.FALSE.
	   RETURN
	  ENDIF
	 ENDIF
	ENDIF
	CHANGE=.TRUE.
	END

	
	DOUBLE PRECISION FUNCTION  DIST
     &	   (NIMA,NANG,LENPROJ,PRJ,P)
	DIMENSION  P(3,NIMA),PRJ(LENPROJ,2*NANG,NIMA)
	DOUBLE PRECISION  DIN,DIN1,DIN2,DID

	DIN=0.0D0
C#ifdef SP_MP
C	NTR=NIMA*(NIMA-1)/2
Cc$omp parallel do private(k,i,j,did)
Cc$omp+reduction(+:din)
C	DO  K=1,NTR
C	   CALL DECO(K,NIMA,I,J)
C	   CALL  CALDIL
C     &	     (PRJ(1,1,I),P(1,I),PRJ(1,1,J),P(1,J),LENPROJ,NANG,DID)
C	   DIN=DIN+DID
C#else
	DO  I=1,NIMA-1
	 DO  J=I+1,NIMA
	  CALL  CALDIL
     &	  (PRJ(1,1,I),P(1,I),PRJ(1,1,J),P(1,J),LENPROJ,NANG,DID)
	  DIN=DIN+DID
	 ENDDO
C#endif
	ENDDO
	DIST=DIN
	END


	SUBROUTINE  DECO(M,N,I,J)
CCCCCCCCCCCCCCCCCCCCCCCCCCC  I<J
	k=0
	DO  IN=1,N-1
	 DO  JN=IN+1,N
	  k=k+1
		IF(k.eq.m)  THEN
		 I=IN
		 J=JN
		 return
		ENDIF
	 ENDDO
	 ENDDO
	END

	SUBROUTINE  CALDIL(PRJ1,FI1,PRJ2,FI2,LENPROJ,NANG,DID)

C  CALCULATES DISTANCE DID USING COMMON LINE
C  WARNING - THE RESULT IS NOT THE SAME AFTER CHANGING THE ORDER
C            OF ARGUMENTS:  FI1<->FI2 !!
C            SUCH CHANGE MEANS THAT ANGLES FOUND SHOULD BE REVERSED TOO:
C                        ALPHA1<->ALPHA2

	DIMENSION  PRJ1(LENPROJ,2*NANG),FI1(3),
     &             PRJ2(LENPROJ,2*NANG),FI2(3)
C	DOUBLE PRECISION  EDL1,EDL2,EDL3,DID,R1(3,3),R2(3,3),R3(3,3)
	DOUBLE PRECISION  EDL2,EDL3,DID,R1(3,3),R2(3,3),R3(3,3)
	DOUBLE PRECISION  ECL1,ECL2,ECL3
	DOUBLE PRECISION  PSI,THETA,PHI,DEPS
	CHARACTER*1  MODIS
	COMMON  /POLS/ MODIS
	DOUBLE PRECISION  QUADPI,RAD_TO_DGR
	PARAMETER (QUADPI = 3.141592653589793238462643383279502884197)
	PARAMETER (RAD_TO_DGR = (180.0/QUADPI))
	PARAMETER (DEPS = 1.0D-7)

	CALL  BLDR(R1,-FI1(3),-FI1(2),-FI1(1))
	CALL  BLDR(R2,FI2(1),FI2(2),FI2(3))
	DO  1  I=1,3
	   DO  1  J=1,3
	      R3(I,J)=0.0
	      DO  1  K=1,3
1	R3(I,J)=R3(I,J)+R2(I,K)*R1(K,J)

C<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
C  LIMIT PRECISION
         DO  5  J=1,3
            DO  5  I=1,3
               IF(DABS(R3(I,J)).LT.DEPS)  R3(I,J)=0.0D0
               IF(R3(I,J)-1.0D0.GT.-DEPS)  R3(I,J)=1.0D0
               IF(R3(I,J)+1.0D0.LT.DEPS)  R3(I,J)=-1.0D0
5        CONTINUE

         IF (R3(3,3).EQ.1.0)  THEN
            THETA=0.0
            PSI=0.0
            IF (R3(1,1).EQ.0.0)  THEN
               PHI=RAD_TO_DGR*DASIN(R3(1,2))
            ELSE
               PHI=RAD_TO_DGR*DATAN2(R3(1,2),R3(1,1))
            ENDIF

         ELSEIF(R3(3,3).EQ.-1.0)  THEN
            THETA=180.0
            PSI=0.0
            IF (R3(1,1).EQ.0.0)  THEN
               PHI=RAD_TO_DGR*DASIN(-R3(1,2))
            ELSE
               PHI=RAD_TO_DGR*DATAN2(-R3(1,2),-R3(1,1))
            ENDIF
         ELSE
            THETA=RAD_TO_DGR*DACOS(R3(3,3))
            ST=DSIGN(1.0D0,THETA)
            IF (R3(3,1).EQ.0.0)  THEN
               IF(ST.NE.DSIGN(1.0D0,R3(3,2)))  THEN
                  PHI=270.0
               ELSE
                  PHI=90.0
               ENDIF
            ELSE
               PHI=RAD_TO_DGR*DATAN2(R3(3,2)*ST,R3(3,1)*ST)
            ENDIF
            IF (R3(1,3).EQ.0.0)  THEN
               IF(ST.NE.DSIGN(1.0D0,R3(2,3)))  THEN
                  PSI=270.0
               ELSE
                  PSI=90.0
               ENDIF
            ELSE
               PSI=RAD_TO_DGR*DATAN2(R3(2,3)*ST,-R3(1,3)*ST)
            ENDIF
         ENDIF
         IF (PSI.LT.0.0)  PSI=PSI+360.0
         IF (THETA.LT.0.0)  THETA=THETA+360.0
         IF (PHI.LT.0.0)  PHI=PHI+360.0
C<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
C	IF(DABS(R3(3,1)).LT.DEPS .AND. DABS(R3(3,2)).LT.DEPS)  THEN
C	PRINT *,'  ALPHA 1  CANNOT BE CALCULATED'
C	DID=2.0
C	RETURN
C	ENDIF
C	IF(DABS(R3(1,3)).LT.DEPS .AND. DABS(R3(2,3)).LT.DEPS)  THEN
C	PRINT *,'  ALPHA 2  CANNOT BE CALCULATED'
C	DID=2.0
C	RETURN
C	ENDIF

	ALPHA1=90.0+PHI
	ALPHA2=90.0-PSI

	IF (ALPHA1.GE.0.0)  THEN
	   L1=MOD(INT(NANG*ALPHA1/180.0),2*NANG)+1
	ELSE
	   L1=MOD(INT(NANG*(360.0+ALPHA1)/180.0),2*NANG)+1
	ENDIF
	IF (ALPHA2.GE.0.0)  THEN
	   L2=MOD(INT(NANG*ALPHA2/180.0),2*NANG)+1
	ELSE
	   L2=MOD(INT(NANG*(360.0+ALPHA2)/180.0),2*NANG)+1
	ENDIF

	IF (MODIS.EQ.'E')  THEN
	   DID = EDL1(PRJ1(1,L1),PRJ2(1,L2),LENPROJ)

	ELSEIF (MODIS.EQ.'C')  THEN

	   IF (L1.GT.NANG)  THEN
              L1=L1-NANG
              IF(L2.GT.NANG)  THEN
		   L2=L2-NANG
		   DID=ECL1(PRJ1(1,L1),PRJ2(1,L2),LENPROJ)
              ELSE
		   DID=ECL2(PRJ1(1,L1),PRJ2(1,L2),LENPROJ)
              ENDIF
	   ELSE
              IF (L2.GT.NANG)  THEN
		   L2=L2-NANG
		   DID=ECL3(PRJ1(1,L1),PRJ2(1,L2),LENPROJ)
              ELSE
		   DID=ECL1(PRJ1(1,L1),PRJ2(1,L2),LENPROJ)
              ENDIF
           ENDIF
	ELSE
	   STOP
	ENDIF

C	PRINT  *,ALPHA1,L1,ALPHA2,L2,DID
	END


	SUBROUTINE  CALDILW1(FI1,FI2,NANG,L1,L2)

C       CALCULATES DISTANCE DID USING COMMON LINE
C       WARNING - THE RESULT IS NOT THE SAME AFTER CHANGING THE ORDER
C            OF ARGUMENTS:  FI1<->FI2 !!
C            SUCH CHANGE MEANS THAT ANGLES FOUND SHOULD BE REVERSED TOO:
C                        ALPHA1<->ALPHA2

	DIMENSION         FI1(3),FI2(3)
	DOUBLE PRECISION  R1(3,3),R2(3,3),R3(3,3)
	DOUBLE PRECISION  PSI,THETA,PHI,DEPS
	CHARACTER*1       MODIS
	COMMON  /POLS/ MODIS

	DOUBLE PRECISION  QUADPI,RAD_TO_DGR
	PARAMETER (QUADPI = 3.141592653589793238462643383279502884197)
	PARAMETER (RAD_TO_DGR = (180.0/QUADPI))
	PARAMETER (DEPS = 1.0D-7)

	CALL  BLDR(R1,-FI1(3),-FI1(2),-FI1(1))
	CALL  BLDR(R2,FI2(1),FI2(2),FI2(3))
	DO  1  I=1,3
	DO  1  J=1,3
	R3(I,J)=0.0
	DO  1  K=1,3
1	R3(I,J)=R3(I,J)+R2(I,K)*R1(K,J)

C<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
C        LIMIT PRECISION
         DO  5  J=1,3
         DO  5  I=1,3
         IF(DABS(R3(I,J)).LT.DEPS)  R3(I,J)=0.0D0
         IF(R3(I,J)-1.0D0.GT.-DEPS)  R3(I,J)=1.0D0
         IF(R3(I,J)+1.0D0.LT.DEPS)  R3(I,J)=-1.0D0
5        CONTINUE

         IF(R3(3,3).EQ.1.0)  THEN
         THETA=0.0
         PSI=0.0
         IF(R3(1,1).EQ.0.0)  THEN
         PHI=RAD_TO_DGR*DASIN(R3(1,2))
         ELSE
         PHI=RAD_TO_DGR*DATAN2(R3(1,2),R3(1,1))
         ENDIF
         ELSEIF(R3(3,3).EQ.-1.0)  THEN
         THETA=180.0
         PSI=0.0
         IF(R3(1,1).EQ.0.0)  THEN
         PHI=RAD_TO_DGR*DASIN(-R3(1,2))
         ELSE
         PHI=RAD_TO_DGR*DATAN2(-R3(1,2),-R3(1,1))
         ENDIF
         ELSE
         THETA=RAD_TO_DGR*DACOS(R3(3,3))
         ST=DSIGN(1.0D0,THETA)
         IF(R3(3,1).EQ.0.0)  THEN
         IF(ST.NE.DSIGN(1.0D0,R3(3,2)))  THEN
         PHI=270.0
         ELSE
         PHI=90.0
         ENDIF
         ELSE
            PHI=RAD_TO_DGR*DATAN2(R3(3,2)*ST,R3(3,1)*ST)
         ENDIF
         IF(R3(1,3).EQ.0.0)  THEN
         IF(ST.NE.DSIGN(1.0D0,R3(2,3)))  THEN
            PSI=270.0
         ELSE
            PSI=90.0
         ENDIF
         ELSE
            PSI=RAD_TO_DGR*DATAN2(R3(2,3)*ST,-R3(1,3)*ST)
         ENDIF
         ENDIF
         IF (PSI.LT.0.0)  PSI=PSI+360.0
         IF (THETA.LT.0.0)  THETA=THETA+360.0
         IF (PHI.LT.0.0)  PHI=PHI+360.0
C<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
C	IF(DABS(R3(3,1)).LT.DEPS .AND. DABS(R3(3,2)).LT.DEPS)  THEN
C	PRINT *,'  ALPHA 1  CANNOT BE CALCULATED'
C	DID=2.0
C	RETURN
C	ENDIF
C	IF(DABS(R3(1,3)).LT.DEPS .AND. DABS(R3(2,3)).LT.DEPS)  THEN
C	PRINT *,'  ALPHA 2  CANNOT BE CALCULATED'
C	DID=2.0
C	RETURN
C	ENDIF

	ALPHA1=90.0+PHI
	ALPHA2=90.0-PSI

	IF(ALPHA1.GE.0.0)  THEN
	L1=MOD(INT(NANG*ALPHA1/180.0),2*NANG)+1
	ELSE
	L1=MOD(INT(NANG*(360.0+ALPHA1)/180.0),2*NANG)+1
	ENDIF
	IF(ALPHA2.GE.0.0)  THEN
	L2=MOD(INT(NANG*ALPHA2/180.0),2*NANG)+1
	ELSE
	L2=MOD(INT(NANG*(360.0+ALPHA2)/180.0),2*NANG)+1
	ENDIF

	END



	FUNCTION  EDL1(X1,X2,N)
	DIMENSION  X1(N),X2(N)
	TDL1=0.0
	DO  1  I=1,N
1       TDL1=TDL1+(X1(I)-X2(I))*(X1(I)-X2(I))
	EDL1=TDL1
	END


	DOUBLE  PRECISION  FUNCTION  EDL1_(X1,X2,N)
	DIMENSION  X1(N),X2(N)
	DOUBLE PRECISION  TDL1
	TDL1=0.0
	DO  1  I=1,N
1	TDL1=TDL1+(X1(I)-X2(I))*DBLE(X1(I)-X2(I))
	EDL1_=TDL1
	END
C
	DOUBLE  PRECISION  FUNCTION  EDL2(X1,X2,N)
	DIMENSION  X1(N),X2(N)
	DOUBLE PRECISION  TDL2
	TDL2=0.0
	DO  1  I=1,N,2
	TDL2=TDL2+(X1(I)-X2(I))*DBLE(X1(I)-X2(I))
1	TDL2=TDL2+(X1(I+1)-X2(I+1))*DBLE(X1(I+1)+X2(I+1))
	EDL2=TDL2
	END
C
	DOUBLE  PRECISION  FUNCTION  EDL3(X1,X2,N)
	DIMENSION  X1(N),X2(N)
	DOUBLE PRECISION  TDL3
	TDL3=0.0
	DO  1  I=1,N,2
	TDL3=TDL3+(X1(I)-X2(I))*DBLE(X1(I)-X2(I))
1	TDL3=TDL3+(X1(I+1)-X2(I+1))*DBLE(X1(I+1)+X2(I+1))
	EDL3=TDL3
	END
C
	DOUBLE  PRECISION  FUNCTION  ECL1(X1,X2,N)
	DIMENSION  X1(N),X2(N)
	DOUBLE PRECISION  TCL1
	TCL1=1.0D0
	DO  1  I=1,N
1	TCL1=TCL1-X1(I)*X2(I)
	ECL1=TCL1
	END
C
	DOUBLE  PRECISION  FUNCTION  ECL2(X1,X2,N)
	DIMENSION  X1(N),X2(N)
	DOUBLE PRECISION  TCL2
	TCL2=1.0D0
	DO  1  I=1,N
1	TCL2=TCL2-X1(N-I+1)*X2(I)
	ECL2=TCL2
	END
C
	DOUBLE  PRECISION  FUNCTION  ECL3(X1,X2,N)
	DIMENSION  X1(N),X2(N)
	DOUBLE PRECISION  TEMP
	TEMP=1.0D0
	DO  1  I=1,N
1	TEMP=TEMP-X1(I)*X2(N-I+1)
	ECL3=TEMP
	END
C
	SUBROUTINE  NRL(X,M)
	DIMENSION   X(M)
	DOUBLE PRECISION  A,S
	A=0.0
	S=0.0
	A=SUM(X)
	S=DOT_PRODUCT(X,X)
	A=A/M
	S=DSQRT(S-M*A*A)
	X=(X-A)/S
	END
 


      SUBROUTINE SORT2(RA,RB,N)

      INTEGER RA(N),RB(N),RRA,RRB

      L=N/2+1
      IR=N
10    CONTINUE
        IF (L.GT.1)THEN
          L=L-1
          RRA=RA(L)
          RRB=RB(L)
        ELSE
          RRA=RA(IR)
          RRB=RB(IR)
          RA(IR)=RA(1)
          RB(IR)=RB(1)
          IR=IR-1
          IF(IR.EQ.1)THEN
            RA(1)=RRA
            RB(1)=RRB
            RETURN
          ENDIF
        ENDIF
        I=L
        J=L+L
20      IF(J.LE.IR)THEN
          IF(J.LT.IR)THEN
            IF(RA(J).LT.RA(J+1))J=J+1
          ENDIF
          IF(RRA.LT.RA(J))THEN
            RA(I)=RA(J)
            RB(I)=RB(J)
            I=J
            J=J+J
          ELSE
            J=IR+1
          ENDIF
        GO TO 20
        ENDIF
        RA(I)=RRA
        RB(I)=RRB
      GO TO 10
      END



	SUBROUTINE  PREPANG(DM,NANG)

	DIMENSION   DM(2,NANG)
	DOUBLE PRECISION  PHI

	PHI=4.0D0*DATAN(1.0D0)/NANG
	DO  I=1,NANG
	   DM(1,I)=DCOS(PHI*(I-1))
	   DM(2,I)=DSIN(PHI*(I-1))
	ENDDO

C       USE NEXT TWO LINES TO GET THE SAME SINOGRAM AS IN _RM 2D_

C	DM(1,I)=-DSIN(PHI*(I-1))
C1	DM(2,I)=DCOS(PHI*(I-1))
	END



	SUBROUTINE  RDL_P(N,NANG,LENPROJ,RI,INUMBRT,NIMA,PRJ,LENB,LENF)

        INCLUDE 'CMBLOCK.INC'
        INCLUDE 'CMLIMIT.INC'

 	DIMENSION  PRJ(LENF,2*NANG,NIMA)

	DIMENSION  INUMBRT(NIMA)
C       AUTOMATIC ARRAYS, PROJECTION IS ASSUMED TO HAVE ODD LENGTH
	DIMENSION  B1(LENPROJ+1),B2(LENPROJ+15),BT(LENPROJ+1)

	REAL, ALLOCATABLE, DIMENSION(:,:)    :: X,PROJ,DM
	INTEGER, ALLOCATABLE, DIMENSION(:,:) :: IPCUBE
	LOGICAL      BREAK

	CHARACTER(LEN=MAXNAM) :: FINPAT,FINPIC,FINFO,FINDOC
	COMMON  /F_SPEC/         FINPAT,FINPIC,FINFO,FINDOC,NLET

	!COMMON  /F_SPEC/  FINPAT,FINPIC,FINFO,FINDOC,NLET
	!CHARACTER*80      FINPAT,FINPIC,FINFO,FINDOC

	COMMON  /PI/ PI

	DATA  INPIC/99/
	DATA  NDOUT/89/

	PI=4.0*DATAN(1.0D0)
C       CALCULATE DIMENSIONS FOR NORMAS
        NSB=-N/2
        NSE=-NSB-1+MOD(N,2)
        NRB=-N/2
        NRE=-NRB-1+MOD(N,2)
C       RADIUS FOR NORMAS
	IR1=0
	IR2=LENPROJ/2

	ALLOCATE(DM(2,NANG),STAT=IRTFLG)
	IF (IRTFLG.NE.0) CALL  ERRT(46,'OP, DM',IER)

	ALLOCATE(X(N,N),STAT=IRTFLG)
	IF (IRTFLG.NE.0) CALL  ERRT(46,'OP, X',IER)

	ALLOCATE(PROJ(LENPROJ,NANG),STAT=IRTFLG)
	IF (IRTFLG.NE.0) CALL  ERRT(46,'OP, PROJ',IER)

	CALL PREPANG(DM,NANG)

C       FIRST CALL JUST FIGURES NN, INUMBRT HERE IS A DUMMY ARGUMENT
	CALL  PSQU_P(N,NN,INUMBRT,RI,.FALSE.)

	ALLOCATE(IPCUBE(3,NN),STAT=IRTFLG)
	IF (IRTFLG.NE.0) CALL ERRT(46,'OP, IPCUBE',IER)

	CALL  PSQU_P(N,NN,IPCUBE,RI,.TRUE.)

#ifdef SP_LIBFFT
	LDA=1
	CALL  SCFFT1DUI(LENPROJ,B2)
#endif
	DO  8  K=1,NIMA

C       READ ONE IMAGE
	CALL FILGET(FINPAT,FINPIC,NLET,INUMBRT(K),INTFLAG)
	MAXIM = 0
	CALL  OPFILEC(0,.FALSE.,FINPIC,INPIC,'O',IFORM,
     &                LSAM,LROW,NSL,MAXIM,' ',.FALSE.,NF)
	IF (NF.NE.0)  RETURN

	DO  J=1,N
           CALL  REDLIN(INPIC,X(1,J),N,J)
	ENDDO
	CLOSE(INPIC)

C       NORMALIZE UNDER THE MASK
        CALL NORMAS(X,NSB,NSE,NRB,NRE,IR1,IR2)

C       CALCULATE LINE PROJECTIONS
	CALL  PRJC2_P(X,N,DM,NANG,PROJ,LENPROJ,IPCUBE,NN)
C--------------------------------------------------------------
	BREAK=.FALSE.
Cc$omp parallel do private(j,b1,bt),shared(break)
	DO  1  J=1,NANG
	 B1(1:LENPROJ)=PROJ(1:LENPROJ,J)

C        NORMALIZE THE LINE
	 CALL  NRL(B1,LENPROJ)

C        MIRROR THE LINES
	 DO  L=1,LENPROJ
	    BT(L)=B1(LENPROJ-L+1)
	 ENDDO
	 INV=+1

#ifdef SP_LIBFFT
	 CALL  SCFFT1DU(INV,LENPROJ,B1,LDA,B2)
#else
	 CALL FMR_1(B1,LENPROJ,B2,INV)
#endif
	 IF (INV.NE.1)  THEN
	    BREAK=.TRUE.
	 ELSE
	    DO  L=LENB,LENB+LENF-1
	       PRJ(L-LENB+1,J,K)=B1(L)
	    ENDDO
	 ENDIF
	 INV=+1
#ifdef SP_LIBFFT
	 CALL  SCFFT1DU(INV,LENPROJ,BT,LDA,B2)
#else
	 CALL FMR_1(BT,LENPROJ,B2,INV)
#endif
	 DO  L=LENB,LENB+LENF-1
	    PRJ(L-LENB+1,J+NANG,K)=BT(L)
	 ENDDO
1	CONTINUE

	IF (BREAK) THEN
	    CALL ERRT(38,'OP',NE)
	    RETURN
	ENDIF

8	CONTINUE
	DEALLOCATE(IPCUBE)
	DEALLOCATE(PROJ)
	DEALLOCATE(X)
	DEALLOCATE(DM)
	END


	SUBROUTINE  PRJC2_P (SQUARE,N,DM,NANG,PROJ,LENPROJ,IPCUBE,NN)

        DIMENSION  DM(2,NANG)
	DIMENSION  SQUARE(N,N),PROJ(LENPROJ,NANG)
	INTEGER    IPCUBE(3,NN)

	COMMON /PAR/  LDP,NM,LDPNM

	PROJ=0.0
CC$OMP PARALLEL DO PRIVATE(I)
	DO  I=1,NANG
	  CALL  PRJC11_P(SQUARE,N,DM(1,I),PROJ(1,I),LENPROJ,IPCUBE,NN)
	ENDDO
	END



	SUBROUTINE  PRJC11_P(SQUARE,N,DM,PROJ,LENPROJ,IPCUBE,NN)

        DIMENSION  DM(2)
	DIMENSION  SQUARE(N,N),PROJ(LENPROJ)
	INTEGER  IPCUBE(3,NN)
	COMMON /PAR/  LDP,NM,LDPNM

	DO  1  I=1,NN
           IY=IPCUBE(2,I)
           XB=(IPCUBE(1,I)-LDP)*DM(1)+(IY-LDP)*DM(2)
           DO  1  J=IPCUBE(1,I),IPCUBE(3,I)
              IQX=IFIX(XB+FLOAT(LDPNM))
	      IF(IQX.GT.0 .AND.  IQX.LT.LENPROJ) THEN
               DIPX=XB+LDPNM-IQX
               PROJ(IQX)=PROJ(IQX)+(1.0-DIPX)*SQUARE(J,IY)
               PROJ(IQX+1)=PROJ(IQX+1)+DIPX*SQUARE(J,IY)
	      ENDIF
1	XB=XB+DM(1)
	END



	SUBROUTINE  PSQU_P(N,NN,IPCUBE,RI,FILL)

	INTEGER  IPCUBE(3,*)
	LOGICAL  FIRST,FILL
	COMMON /PAR/  LDP

C       IPCUBE: 
C       1 - IX
C       2 - IY
C       3 - END OF IX

	R=RI*RI

	NN=0

	DO  25  I1=1,N
	T=I1-LDP
	XX=T*T
	FIRST=.TRUE.
	DO 20 I2=1,N
           T=I2-LDP
           RC=T*T+XX
           IF (FIRST)  THEN
              IF (RC.GT.R)  GOTO 14
              FIRST = .FALSE.
              NN = NN+1
              IF (FILL) THEN
                 IPCUBE(1,NN)=I2
                 IPCUBE(2,NN)=I1
                 IPCUBE(3,NN)=I2
              ENDIF
           ELSE
              IF (FILL)  IPCUBE(3,NN)=I2
              IF (RC.GT.R)  GOTO  16
           ENDIF
14	   CONTINUE
20	CONTINUE
16	CONTINUE
25	CONTINUE

	END


	SUBROUTINE  GENAT(ANGTAB,DPSI,NANGT,FILL)

	DIMENSION  ANGTAB(2,*)
	LOGICAL FILL
	PARAMETER (QUADPI = 3.141592653589793238462643383279502884197)
        PARAMETER (DGR_TO_RAD = (QUADPI/180))

C       ANGTAB(1  - THETA
C       ANGTAB(2  - PHI
	NANGT=0
	P1=0.0
	P2=359.9
	DO THETA=0.,179.999,DPSI
           IF (THETA.EQ.0.0.OR.THETA.EQ.180.0)  THEN
	      DETPHI=360.0
	      LT=1
           ELSE
	      DETPHI=DPSI/SIN(DGR_TO_RAD*THETA)
	      LT=MAX0(INT((P2-P1)/DETPHI)-1,1)
	      DETPHI=(P2-P1)/LT
           ENDIF
C	   DO 1  PHI=P1,P2,DETPHI
           DO I=1,LT
              PHI   = P1+(I-1)*DETPHI
              NANGT = NANGT+1
	      IF (FILL)  THEN
	         ANGTAB(1,NANGT)=THETA
	         ANGTAB(2,NANGT)=PHI
	      ENDIF
           ENDDO
        ENDDO
	END

#ifdef SP_IBMSP3
        REAL FUNCTION ETIME(TARRAY)

        DIMENSION TARRAY(2)

C       CLOCK RESETS AT ICMAX!!
        CALL SYSTEM_CLOCK(ICOUNT,ICPSEC,ICMAX)

        ETIME = ICOUNT / ICPSEC

        RETURN
        END


#endif
