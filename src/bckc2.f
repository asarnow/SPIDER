
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

	SUBROUTINE  BCKC2(CUBE,LTC,DM,IM,B,IPCUBE,NN,NSAM)

        DIMENSION  DM(9,IM)
	DIMENSION  CUBE(LTC),B(nsam,im)
	INTEGER    IPCUBE(5,NN)

C
C  B - linear array containing all projections
C  CUBE - linear array containing cube
C  IPCUBE - pointers to CUBE
C
c$omp parallel do private(i)
	DO   I=1,LTC
	   CUBE(I)=0.0
	ENDDO
	DO    I=1,IM
	   CALL  BCKC0(CUBE,LTC,DM(1,I),B(1,i),NSAM,IPCUBE,NN)
	ENDDO
      	END
