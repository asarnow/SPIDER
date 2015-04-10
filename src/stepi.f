C ++********************************************************************
C                                                                      *
C   STEPI                                                              *
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
C STEPI(X,N,NU,NV) 
C                                                                     *
C***********************************************************************

	FUNCTION  STEPI(X,N,NU,NV)

	DIMENSION  X(N)


	LL=NU-NV-1
	LH=NU+NV+1
	AS=0.0
	AQ=0.0
	BS=0.0
	BQ=0.0
	IF (LL .GE. 1)  THEN
	   DO    I=1,LL
	      AS=AS+X(I)
	      AQ=AQ+X(I)*X(I)
	   ENDDO
	ENDIF

	DO    I=NU-NV,NU+NV
	   BS=BS+X(I)
	   BQ=BQ+X(I)*X(I)
	ENDDO

	IF (LH .LE. N)  THEN
	   DO I=LH,N
	      AS=AS+X(I)
	      AQ=AQ+X(I)*X(I)
	   ENDDO
	ENDIF

	AVG1=AS/FLOAT(N-2*NV-1)
	AVG2=BS/FLOAT(2*NV+1)

	IF (AVG2 .GE. AVG1) THEN
           NB=2*NV+1
           NA=MAX0(N-NB,1)
           STEPI=(AQ-AS*AS/NA)/NA+(BQ-BS*BS/NB)/NB
	ELSE
           STEPI=1.E20
	ENDIF

        RETURN
	END
