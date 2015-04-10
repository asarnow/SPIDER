
C ++********************************************************************
C                                                                      *
C                                                                      *
C                                                                      *
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
C                                                                      *
C                                                                      *
C                                                                      *
C  PURPOSE:                                                            *
C                                                                      *
C  PARAMETERS:                                                         *
C                                                                      *
C        0         2         3         4         5         6         7 *
C23456789012345678901234567890123456789012345678901234567890123456789012
C***********************************************************************

       SUBROUTINE DIST2(II,NMAX,MD,XMEAN,N,LIN,LINE,E)

       IMPLICIT REAL*8 (A-H,O-Z)
       IMPLICIT INTEGER*2 (I-N)
       DIMENSION XMEAN(NMAX,MD),N(NMAX),LIN(90),E(NMAX)
       CHARACTER*1  LINE(90),IX
       DATA IX /'.'/

       Y=3.0-REAL(II)/7.0
       DO  I=1,90
       X=REAL(I)/15.-3.0
       L=0
       XMAX=1.E30
       DO 2 J=1,NMAX
       IF(N(J).EQ.0) GOTO 2
       Z=(X-XMEAN(J,1))**2+(Y-XMEAN(J,2))**2-E(J)
       IF(Z.GE.XMAX) GOTO 2
       XMAX=Z
       L=J
 2     CONTINUE
       IF(I.EQ.1) GOTO 3
       IF(L.NE.L0) LINE(I)=IX
 3     L0=L
       IF(L.NE.LIN(I)) LINE(I)=IX
       LIN(I)=L
       ENDDO
       END
