
C++*********************************************************************
C
C  FMRS_1.F                      ADDED FFTW        AUG 2000 BIMAL RATH
C                                WORK REDIMENSIOND NOV 2005 ARDEAN LEITH
C                                FFTW3 REACTIVATED DEC 2007 ARDEAN LEITH
C                                FMRS REWRITE      JAN 2008 ARDEAN LEITH
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
C  D REAL MIXED RADIX FFT.
C  INPUT:  X(N) - REAL ARRAY
C  OUTPUT: N EVEN  X(N+2)
C  ORDER OF ELEMENTS:
C  R(0),0.0, R(1), I(1), R(2), I(2), ....., R(N/2-1), I(N/2-1), R(N/2),0.0
C
C         N ODD  X(N+1)
C  R(0),0.0, R(1), I(1), R(2), I(2), ....., R(N/2-1), I(N/2-1), R(N/2),I(N/2)
C 
C  HERE WE FOLLOW THE CONVENTION THAT INTEGER DIVISION 
C  IS ROUNDED DOWN, E.G. 5/2 =2)
C
C  INV: +1 FORWARD FFT
C       -1 INVERSE FFT
C
C  ON OUTPUT INV=0 INDICATES ERROR (NOT GUARANTEED)!!!
C
C--*********************************************************************

        SUBROUTINE  FMRS_1(X,NSAM,INV)

        REAL, INTENT(INOUT) :: X(*)
        INTEGER, INTENT(INOUT) :: INV

        CALL FMRS(X,NSAM,1,1, 0.0D0, .TRUE.,.TRUE., INV,IRTFLG)

        IF (IRTFLG .NE. 0) INV = 0

        END

