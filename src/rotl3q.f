
C++*********************************************************************
C
C ROTL3Q.F                            TRI QUAD  May 4 2002 ArDean Leith
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
C  ROTL3Q(LUN2,Q1,NSAM,NROW,NSLICE,P1,P2,ALPHA)
C
C  PURPOSE: ROTATE VOLUME AROUND LINE USING TRI-QUADRATIC INTERP.
C
C23456789012345678901234567890123456789012345678901234567890123456789012
C--*********************************************************************

         SUBROUTINE ROTL3Q(LUN2,Q1,NSAM,NROW,NSLICE,P1,P2,ALPHA)

         REAL, DIMENSION(3)               :: P1,P2
         REAL, DIMENSION(NSAM,NROW,NSLICE):: Q1

         REAL, DIMENSION(NSAM)            :: Q2
         DOUBLE PRECISION,DIMENSION(3)    :: QR
         DOUBLE PRECISION,DIMENSION(3,3)  :: RM,R1,R3
         DOUBLE PRECISION                 :: DX,DY,DZ,XD,YD,ZD,DTEMP

         INTEGER, PARAMETER               :: NSIZE = 27
         INTEGER, DIMENSION(NSIZE)        :: X,Y,Z
         REAL, DIMENSION(NSIZE)           :: F

	 PARAMETER (QUADPI = 3.141592653589793238462643383279502884197)
	 PARAMETER (RAD_TO_DGR = (180.0/QUADPI))

C        SET THE KNOWN COORDINATE GRID
	 DO  L=1,NSIZE,3
	    X(L)   = -1
	    X(L+1) = 0
	    X(L+2) = 1
	    Y(L)   = MOD(L/3,3)-1
	    Y(L+1) = MOD(L/3,3)-1
	    Y(L+2) = MOD(L/3,3)-1
	 ENDDO
	 DO  L=1,NSIZE
	    Z(L) = (L-1)/9-1
	 ENDDO


	 XD = P2(1) - P1(1)
	 YD = P2(2) - P1(2)
	 ZD = P2(3) - P1(3)

         IF (ALPHA.EQ.0.0 .OR.
     &      (XD.EQ.0.0.AND.YD.EQ.0.0.AND.ZD.EQ.0.0)) THEN
C           NO ROTATION NEEDED
            CALL WRTVOL(LUN2,NSAM,NROW,1,NSLICE,Q1,IRTFLG)
            RETURN
         ENDIF

	PSI   = -RAD_TO_DGR * ATAN2(YD,XD)
        DTEMP = SQRT(XD*XD+YD*YD)
	THETA =  RAD_TO_DGR * ATAN2(ZD,DTEMP)

	CALL BLDR(R1,PSI,THETA,90.0)
	CALL BLDR(RM,0.0,ALPHA,0.0)

         DO I=1,3
            DO J=1,3
               R3(J,I) = 0.0
               DO K=1,3
                  R3(J,I) = R3(J,I) + RM(K,I) * R1(J,K)
	       ENDDO
	    ENDDO
	 ENDDO

         DO I=1,3
            DO J=1,3
               RM(J,I) = 0.0
               DO K=1,3
                  RM(J,I) = RM(J,I) + R1(I,K) * R3(J,K)
	       ENDDO
	    ENDDO
	 ENDDO

         IREC  = 0

	 DO IZ=1,NSLICE
	    ZZ = IZ - P1(3)

	    DO IY=1,NROW
	       YY = IY - P1(2)

               DO  IX=1,NSAM
                 XX = IX - P1(1)

                 QR(1) = RM(1,1)*XX+RM(2,1)*YY+RM(3,1)*ZZ+P1(1)
                 QR(2) = RM(1,2)*XX+RM(2,2)*YY+RM(3,2)*ZZ+P1(2)
                 QR(3) = RM(1,3)*XX+RM(2,3)*YY+RM(3,3)*ZZ+P1(3)

C                IOX..  INTEGER LOCATION IN 1...NSAM ARRAY
                 IOX = FLOOR(QR(1))   
                 IOY = FLOOR(QR(2))   
                 IOZ = FLOOR(QR(3))   

C                DX.. OFFSET FROM INTEGER ARRAY
                 DX  = QR(1) - IOX
                 DY  = QR(2) - IOY
                 DZ  = QR(3) - IOZ

                 IF ((IOX .GT. 1 .AND. IOX .LT. NSAM ) .AND.
     &               (IOY .GT. 1 .AND. IOY .LT. NROW ) .AND.
     &               (IOZ .GT. 1 .AND. IOZ .LT. NSLICE )) THEN
C                   ROTATED POSITION IS INSIDE OF VOLUME

C                   FIND INTENSITIES ON 3x3x3 COORDINATE GRID
                    DO L = 1,NSIZE
                       I    = IOX + X(L)
                       J    = IOY + Y(L)
                       K    = IOZ + Z(L)
                       F(L) = Q1(I,J,K)
                    ENDDO

C                   EVALUATE INTENSITY AT PX,PY,PZ
                    Q2(IX) = TRIQUAD(DX,DY,DZ,F)
                 ELSE
C                   ROTATED POSITION IS OUTSIDE VOLUME
                    Q2(IX) = Q1(IX,IY,IZ)
                ENDIF
              ENDDO
              IREC = IREC + 1
              CALL WRTLIN(LUN2,Q2,NSAM,IREC)

           ENDDO
        ENDDO
        END


