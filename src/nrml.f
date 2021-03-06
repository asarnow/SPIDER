C++*********************************************************************
C
C    NRML.F  
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
C
C
C23456789012345678901234567890123456789012345678901234567890123456789012
C--*********************************************************************
 
	SUBROUTINE  NRML(X,N)
	DIMENSION  X(N)
	DOUBLE PRECISION  AV,VR
        AV=0.0D0
        VR=0.0D0
c$omp parallel do private(i),reduction(+:av,vr)
	DO    I=1,N	
          AV=AV+X(I)
          VR=VR+X(I)*DBLE(X(I))
	ENDDO
        AV=AV/N
        VR=1.0/DSQRT((VR-N*AV*AV)/(N-1))
c$omp parallel do private(i)
        DO    I=1,N
          X(I)=(X(I)-AV)*VR
	ENDDO
        END
