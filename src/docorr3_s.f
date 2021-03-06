
C ++********************************************************************
C                                                                      *
C   DOCORR3_S                                                            *
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
C  DOCORR3_S                                                             *
C                                                                      *
C  PURPOSE:                                                            *
C                                                                      *
C  PARAMETERS:                                                         *
C                                                                      *
C***********************************************************************

	SUBROUTINE  DOCORR3_S(BCKE,BCN,NMAT,IPCUBE,NN,ALA,SBQO)

	DIMENSION    BCKE(NMAT),BCN(NMAT),IPCUBE(5,NN)

        SBQ=0.0
c$omp parallel do  private(i,j,temp),reduction(+:sbq)
        DO    I=1,NN
           DO    J=IPCUBE(1,I),IPCUBE(2,I)
 		BCKE(J)=BCKE(J)+ALA*BCN(J)
		TEMP=BCN(J)*BCN(J)
		SBQ=SBQ+TEMP
           ENDDO
        ENDDO

	SBQO=SBQ
	END
