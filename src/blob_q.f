
C++*********************************************************************
C
C $$ BLOB_Q.FOR
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
C IMAGE_PROCESSING_ROUTINE
C
C        1         2         3         4         5         6         7
C23456789012345678901234567890123456789012345678901234567890123456789012
C--*********************************************************************
C
C $$ BLOB_Q.FOR
C

        SUBROUTINE  BLOB_Q(X,LSD,NSAM,NROW,NR)

         DIMENSION   X(LSD,NROW)
         PI=4.0*DATAN(1.0D0)
         RR=NR*NR
         NO=NROW/2+1
         NS=NSAM/2+1
c$omp parallel do private(j,i,r,r2)
         DO J=1,NROW
            R=(J-NO)*(J-NO)
            DO I=1,LSD
               R2=R+(I-NS)*(I-NS)
               IF(R2.GT.RR)  THEN
                  X(I,J)=0.0
               ELSE
                  X(I,J)=(COS(SQRT(R2/RR)*PI)+1.0)*0.5
               ENDIF
            ENDDO
         ENDDO
         END
