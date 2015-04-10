
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

        SUBROUTINE MRAND(OUT,J,GFLAG,NWR)

C       RANDOM GENERATOR SIMULATING THE TRUNCATION OF AN INTEGER*8
C       NUMBER TRUNCATED MODULO 2**48. MULTIPLIER 11**13.
C       SEE: LITERATURE ABOUT RANDOM GENERATORS
C       M.RADERMACHER 3/14/84

C**     IMPLICIT INTEGER*4 I,J,K,L,M,N !REMOVED FOR UNIX COMPATIBILITY

        DIMENSION IA(5),IB(5),IC(10)
        INTEGER NWR
	CHARACTER*40 ALPHA,CLEAR
        LOGICAL GFLAG,GFLA
	EQUIVALENCE (ALPHA,IC(1))
	DATA IC/10*0/

	CLEAR=ALPHA
	GFLA=GFLAG
	NOUT=NWR
C       DEFINE BASIS OF INTEGER REPRESENTATION
        IBAS=2**12
C       NORMALIZATION FACTOR
        XNORM=IBAS*IBAS
C       START VALUE OF FIRST FACTOR
        IA(1)=J
        IA(2)=0
        IA(3)=0
        IA(4)=0
        IA(5)=0
C       CODE SECOND FACTOR (11**13) TO THE BASIS OF 2**12
        IB(1)=2107
        IB(2)=4071
        IB(3)=1521
        IB(4)=502
        IB(5)=0
        RETURN
        ENTRY GETRAND(OUT)
C       SIMULATE MULTIPLICATION OF 4-DIGIT INTEGER TO THE BASIS 
C       OF 2**12
C
C       N=NUMBER OF INPUT DIGITS
        N=4
C       CLEAR ARRAY IC:

        ALPHA=CLEAR
        DO  K=1,N
           IUE=0
           DO  I=1,N
              L=I-1+K
              IZC=IA(I)*IB(K)+IUE+IC(L)
              IU=MOD(IZC,IBAS)
              IUE=IZC/IBAS
              IC(L)=IU
C             WRITE(NOUT,9910) IA(I),IB(K),IC(L),IUE
9910          FORMAT(' ',I5,' MAL',I5,' + LETZER WERT =',
     $         1X,I5,' HIN',I5,' IM SINN')
           ENDDO
           IC(L+1)=IUE
        ENDDO
C       END OF MULTIPLICATION
C
C       STORE RESULT MODULO 2**48  AS NEXT FIRST VARIABLE
        IA(1)=IC(1)
        IA(2)=IC(2)
        IA(3)=IC(3)
        IA(4)=IC(4)
C       USE FIRST TWO DIGITS AS RANDOM VARIABLE
        IZ1=IC(4)
        IZ2=IC(3)
C       NORMALIZE RANDOM NUMBER TO INTERVAL [0,1]
        OUT=FLOAT(IZ1*IBAS+IZ2)/XNORM
C	WRITE (NOUT,77) GFLA
77 	FORMAT(' ',A1)
        IF(.NOT.GFLA)GOTO 199
C       CREATE GAUSSIAN DISTRIBUTION:
C       INVGDIST CAN EITHER BE IMSL OR THE SUBSTITUTE
C       PROGRAM WRITTEN BY S.FULLER 
        CALL INVGDIST(OUT,RES)
        OUT=RES
C       WRITE(NOUT,100)OUT
100     FORMAT(' ',E28.20)
10      FORMAT(' ',4I2,'*',4I2,'=',8I2)
199     RETURN
        END
