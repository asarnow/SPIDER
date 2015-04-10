C++*********************************************************************
C
C TTEST.F
C
C **********************************************************************
C *                                                                        *
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
C SUPPORT_ROUTINE
C
C23456789012345678901234567890123456789012345678901234567890123456789012
C--*********************************************************************

         SUBROUTINE  TTEST1(LUN1,LUN2,LUN5,N1,UM,NSAM,NROW,NSLICE)

         DIMENSION  A1(NSAM),S1(NSAM),P(NSAM)
         DOUBLE PRECISION  T, DF, BETAI

         DF = N1-1

         DO  K = 1, NSLICE
           DO  J = 1, NROW
             CALL  REDLIN(LUN1,A1,NSAM,(K-1)*NROW+J)
             CALL  REDLIN(LUN2,S1,NSAM,(K-1)*NROW+J)
             DO  I = 1, NSAM
               T = ABS(A1(I)-UM)/DSQRT(DBLE(S1(I))/N1)

C              BETAI FUNCTION IS DESCRIBED IN THE BOOK 
C              "NUMERICAL RECIPES" PAGE 167
C              BY      WILLIAM H PRESS ET ALL.
C
C              FROM TTEST ROUTINE PAGE 466

               P(I) = BETAI(0.5 * DF, 0.5D0, DF / (DF + T**2))
             END DO
             CALL  WRTLIN(LUN5,P,NSAM,(K-1)*NROW+J)
           END DO
         END DO
         END
