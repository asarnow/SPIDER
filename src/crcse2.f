C++*********************************************************************
C
C CRCSE2.F
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
C--*********************************************************************

         SUBROUTINE CRCSE2(LUN,BUF,NSAM,NROW,SEC,SNO,IR)

 

C        I DO NOT KNOW IF SAVE IS NEEDED FEB 99 al
         SAVE

         DIMENSION BUF(NSAM),SEC(IR),SNO(IR)
         DO    I=1,IR
            SEC(I)=0.0
            SNO(I)=0.0
	 ENDDO

         DO  1  J=1,NROW
            KJ=J-NROW/2-1
            IF(IABS(KJ).GT.IR-1)  GOTO  1
            CALL REDLIN(LUN,BUF,NSAM,J)
            DO  2  I=1,NSAM
               KI=I-NSAM/2-1
               R=SQRT(FLOAT(KJ*KJ)+FLOAT(KI*KI))+1.0
               L=R
               IF(L.GT.IR-1)  GOTO  2
               XD=R-L
               SEC(L)=SEC(L)+BUF(I)*(1.0-XD)
               SEC(L+1)=SEC(L+1)+BUF(I)*XD
               SNO(L)=SNO(L)+1.0-XD
               SNO(L+1)=SNO(L+1)+XD
2           CONTINUE
1        CONTINUE

         DO    I=1,IR
            SEC(I)=SEC(I)/AMAX1(1.0,SNO(I))
	 ENDDO
         END
