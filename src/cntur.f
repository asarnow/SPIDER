
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

C++*************************************************************************
C
C    CNTUR.FOR 
C
C **************************************************************************
C       LAST UPDATE  26 AUG 96 al,  20 NOV 89 al
C       MODIFIED FROM CONTUR.FOR TO REMOVE SOME OUTPUT AND TO ADD MULTI-Z CAPABILITY
C       PREVIOUS UPDATES  5 DEC 86 al    01/08/78       17/01/78  22/11/73
C **************************************************************************
C
C   CNTUR(AM,NSAM,NROW,V1,V2,V3,SCRTCH,X,Y,NMAX,LUN,MULTIZ,MAXPTS)
C
C   PURPOSE:      SUBROUTINE TO CONTROL CONTOUR PLOTTING
C
C   PARAMETERS:   AM        2-D ARRAY FOR THIS IMAGE LEVEL
C                 NSAM      X DIMENSION OF AM
C                 NROW      Y DIMENSION OF AM
C                 V1,V2,V3  CONTOUR LEVELS
C                 SCRATCH   WORKING ARRAY
C                 X,Y       COORDINATE ARRAYS
C                 NMAX      DIMENSIONS OF X, Y, & SCRATCH
C                 LUN       LOGICAL UNIT FOR CONTOUR OUTPUT
C                 MULTIZ    LOGICAL VARIABLE FOR MULTIPLE Z LEVELS
C                 MAXPTS    MAX. NO. OF POINTS WANTED ON A CONTOUR
C   
C   CALLED BY:    CNINT3
C
C   CALLS:        CNSCAN
C
C--********************************************************************

      SUBROUTINE CNTUR(AM,NSAM,NROW,V1,V2,V3,IRRX,X,Y,NMAX,LUN,
     &                  MULTIZ,MAXPTS,MAXIRR)


C     I DO NOT KNOW IF SAVE IS NEEDED FEB 99 al
      SAVE


C-------- START OF EM-PLOTT-COMMON-------------------------------------
C     INTEGERS
      COMMON /CONT1/ ICALL, IDIDIT, IDONE, IDX, IDY, ILINE, INTT,
     &               IRCD, ISS, ISTART, ISUM1, ISUM2, ISUM3, IT, IV, 
     &               IXX1, IXX2, IXX3, IX, IY, JSUM1, JSUM2, JSUM3, JT,
     &               LEVEL, LW, M, MF, MI, MT, N, NDIV, NF, NI, NT, NW

C     FLOATING POINT
      COMMON /CONT2/ APDIV, APDIVX, CV, DL, PY, RA, RC, RS, SKALE, THE,
     &               SX, SY, DENSL

C     ARRAYS
      COMMON /CONT3/ INCX(3), IORGX(3), INX(8),
     &               INY(8),  IPT(3,3), IMAP(12), NG(3), NP(3)

      COMMON /CONT4/ CTRI(6),FCTR(6),CTRDEL(6),ICNDSH(6),ICNCEL

C--------END OF EM-PLOTT-COMMON----------------------------------------

      COMMON /UNITS/LUNC,NIN,NOUT

C     AM IS THE ARRAY INPUT DATA IN THE CURRENT LAYER.
C     TRUE DIMENSION:  AM(NSAM * NROW)

      DIMENSION      AM(1)
      DIMENSION      IRRX(MAXIRR),  X(NMAX),  Y(NMAX)
      LOGICAL        MULTIZ
       
C*    MULTIZ IS A FLAG THAT THE FILE ZCOO VARIABLE IS FOR MULTIPLE Z
C     LEVELS, NOT FOR DIFFERENT CONTOUR LEVELS ON A SINGLE Z LEVEL.

      IF (ICNCEL .EQ. 0) THEN
         IMAP(1) = 0.
         IMAP(2) = 0.
         IMAP(3) = 5.
         IMAP(4) = 5.
         IMAP(5) = 5.
         DO I = 6,12
           IMAP(I) = 0.
         ENDDO
      ENDIF

      NCV = 1
C     START SERIES OF PLOTS
      KAM = NSAM*NROW
      IF (V3 .NE. 0) THEN
         CTRI(1)   = V1
         FCTR(1)   = V2
         CTRDEL(1) = V3
      ENDIF

C     SET CONTOUR LEVELS IF NONE ARE STATED
C     COUNT THE NUMBER OF LEVELS, NCV

      IF (CTRDEL(1) .EQ. 0) THEN
        WRITE(NOUT,*) '*** INVALID CONTOUR LEVELS STATED'
        RETURN
      ENDIF

      DO  I = 2,6
        IF (CTRDEL(I) .EQ. 0) GOTO 110
        NCV = NCV + 1
      ENDDO

  110 DO  I = 1,3
        IORGX(I) = 0
        INCX(I)  = 1
      ENDDO

      NG(2) = NSAM - 1
      NP(2) = NSAM
      NG(3) = NROW - 1
      NP(3) = NROW
      JSUM1 = 3
      JSUM2 = 2
      JSUM3 = 1
      NIVE  = IORGX(1)
      NIVS  = NIVE
      NIVD  = 1
      NIV   = NIVS
      MI    = 1
      MF    = NP(3)
      M     = MF - MI + 1
      MT    = NP(3)

C     FIND THE A PER DIVISION
      SNTHE  = SQRT(1.0-IMAP(JSUM1+5)**2)
      APDIV  = IMAP(JSUM2+2)*FLOAT(INCX(2))*SNTHE /FLOAT(NG(2))
      APDIVX = IMAP(JSUM3+2)*FLOAT(INCX(3)) / FLOAT(NG(3))
      RA     = APDIV / APDIVX
      THE    = FLOAT(IMAP(JSUM1+5))
      NDIV   = NP(2) - 1

C     SET ALL COUNTS EQUAL TO ZERO
      IDONE  = 0
      LW     = 0

C     READ POINTS IN LAYER BY LAYER AND STORE THEM IN AM
      IXX1  = 1
      NF    = 1
C     MAKE III PLOTS OF THIS LAYER
      LEVEL = IORGX(1) + INCX(1) * (IXX1-1)

 3024 IF (LEVEL .GT. NIVE .OR. LEVEL .LT. NIV)  THEN
         GOTO 8000

      ELSEIF (LEVEL .GT. NIV) THEN
        NIV = NIV + NIVD
        GOTO 3024
      ENDIF
      

  207 NI = NF
      NF = NI + NDIV
      IF (NF .GT. NP(2)) NF = NP(2)

C     DETERMINE ALL CONTOUR LEVELS FOR NCV INTERVALS
      DO 130 I = 1,NCV
         IF (ICNDSH(I) .EQ. -1) ICNDSH(I) = 4
         DL    = ICNDSH(I)
         LIM   = (FCTR(I)-CTRI(I)) / CTRDEL(I) + 1.99999
         FCTR0 = CTRI(I)
         CTRI0 = FCTR(I)
         IF (LIM .LT. 1) GO TO 130
         JLEV  = 0
         DO 128 J=1,LIM
            CV = CTRI(I) + (FLOAT(J)-1.0) * CTRDEL(I)

C*          MODIFIED MAR 86 al
            IF (.NOT. MULTIZ) ZCOO = CV

C           DRAW CONTOUR LINES FOR THIS LEVEL
            X(1) = -100000.
            CALL CNSCAN(AM,KAM,IRRX,X,Y,NMAX,LUN,MULTIZ,
     &                  MAXPTS,MAXIRR)
            IF (X(1) .NE. -100000.) THEN
C              CONTOUR LINES FOUND ON LAST LEVEL
               IF (CTRI0.EQ.FCTR(I)) CTRI0 = CV
               JLEV  = 1
               FCTR0 = CV
            ELSEIF (JLEV .GT. 0) THEN
               GOTO 129
            ENDIF

 128     CONTINUE

 129     CTRI(I) = CTRI0
         FCTR(I) = FCTR0
 130  CONTINUE

      NIV = NIV + NIVD

8000  IDONE = 1
      RETURN
      END
