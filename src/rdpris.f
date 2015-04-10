
C++*********************************************************************
C
C   RDPRIS.F          ALTERED RDPRI  JULY 87 TO ADD IRTFLG ARDEAN LEITH
C                     BUG IN IBUF ACCESS FIXED NOV 94      ARDEAN LEITH  
C                     USED RDPRINC             MAR 99      ARDEAN LEITH    
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
C   RDPRIS(I1,I2,NOT_USED,STRING,IRTFLG)
C
C   PURPOSE:    READ TWO INTEGERS
C
C   PARAMETERS:
C        I1       FIRST INTEGER ENTERED                       (RETURNED)
C        I2       SECOND INTEGER ENTERED                      (RETURNED)
C        NOT_USED                                                 (SENT)
C        STRING   SOLICITATION MESSAGE                            (SENT)
C        IRTFLG   RETURN FLAG (0 IS NORMAL,                   (RETURNED)
C                             -1 IS GOTO PREVIOUS QUESTION
C                             -3 IS ACCEPTED NULL RETURN
C
C  NOTE:          RDPRIS DOES NOT ALTER RECEIVED VALUE OF I1 OR I2 IF
C                 IT RECEIVES NULL INPUT.
C
C23456789012345678901234567890123456789012345678901234567890123456789012
C--*********************************************************************

      SUBROUTINE RDPRIS(I1,I2,NOT_USED,PROMPT,IRTFLG)

      INCLUDE        'CMBLOCK.INC' 

      CHARACTER *(*)  PROMPT

C     DO NOT ZERO THE RETURNED VALUES (DIFFERENT FROM NORMAL SPIDER METHOD)

      VAL1 = I1
      VAL2 = I2

      CALL RDPRINC(PROMPT,2,.TRUE.,NOT_USED, VAL1,VAL2,VAL3,IRTFLG)
      IF (IRTFLG .EQ. -1) RETURN

      I1 = VAL1
      I2 = VAL2

      RETURN
      END



