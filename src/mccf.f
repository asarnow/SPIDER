C++*********************************************************************
C
C MCCF.F
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
C23456789012345678901234567890123456789012345678901234567890123456789012
C--*********************************************************************

        SUBROUTINE MCCF
        
        INCLUDE 'CMBLOCK.INC'
        INCLUDE 'CMLIMIT.INC' 
 
        CHARACTER(LEN=MAXNAM)   ::  FILNAM
        REAL, ALLOCATABLE, DIMENSION(:,:) :: X,Y

        CHARACTER *1  NULL,ASK

        DATA  LUN1,LUN2,LUN3/7,8,9/

        NULL = CHAR(0)

C       MASKED CROSSCORELATION FUNCTION
        IDUM = 0
        CALL OPFILEC(0,.TRUE.,FILNAM,LUN1,'O',ITYPE,NSAM,NROW,NSLICE,
     &             IDUM,'INPUT',.TRUE.,IRTFLG)
        IF (IRTFLG .EQ. -1) RETURN

        IF (ITYPE.NE.1) GOTO 145

        IDUM = 0
        CALL OPFILEC(0,.TRUE.,FILNAM,LUN3,'O',ITYPE,NSAM,NROW,NSLICE,
     &             IDUM,'REFERENCE',.TRUE.,IRTFLG)
        IF (IRTFLG .EQ. -1) GOTO 130

        IF(ITYPE.NE.1) GOTO 145

        CALL FILERD(FILNAM,NLETO,NULL,'OUTPUT',IRTFLG)
        IF (IRTFLG .EQ. -1) GOTO 5
        
        CALL RDPRMI(IRA,IDUM,NOT_USED,'MASK RADIUS')
        IF(IRA.LT.2.OR.IRA.GT.NSAM/2.OR.IRA.GT.NROW/2)  THEN
           CALL  ERRT(31,'MCCF  ',NE)
            GOTO  5
        ENDIF
	LSD=2*NSAM+2-MOD(2*NSAM,2)

        KB=1+2*LSD*NROW
C
        CALL  RDPRMC(ASK,NCHAR,.TRUE.,
     &   '(F)ULL OR (H)ALF OUTPUT (F/H)',NULL,IRTFLG)
       
        IF (ASK.EQ.'H')  THEN
 	  IDUM = 0
	  CALL OPFILEC(LUN1,.FALSE.,FILNAM,LUN2,'U',ITYPE,
     &            NSAM,NROW,1,IDUM,' ',.FALSE.,NF)
          GOTO (130,951),NF
     
        ELSEIF(ASK.EQ.'F')  THEN
	   IDUM = 0
	   CALL OPFILEC(0,.FALSE.,FILNAM,LUN2,'U',ITYPE,
     &                2*NSAM,2*NROW,1, IDUM,' ' ,.FALSE.,NF)

           GOTO (130,951),NF
       ELSE
          CALL  ERRT(31,'MCCF  ',NE)
          GOTO  5
       ENDIF

951	ALLOCATE (X(LSD,2*NROW), STAT=IRTFLG)
        IF (IRTFLG.NE.0) THEN 
           CALL ERRT(46,'CC MS, X',IER)
           GOTO 5
        ENDIF

 	ALLOCATE (Y(LSD,2*NROW), STAT=IRTFLG)
        IF (IRTFLG.NE.0) THEN 
           CALL ERRT(46,'CC MS, X',IER)
           GOTO 5
        ENDIF

        NSAM1 = LSD
	NROW1 = 2*NROW
       
        CALL READV(LUN1,X,NSAM1,NROW1,NSAM,NROW,NSLICE)
        CALL READV(LUN3,Y,NSAM1,NROW1,NSAM,NROW,NSLICE)

        CALL  MCCF_P(NSAM,NROW,X,Y,LSD,IRA,ASK)
     
        NS2=NSAM/2+1
        NR2=NROW/2+1    
 
        NSAM1 = LSD
	NROW1 = 2*NROW

   	IF (ASK .EQ. 'F')  THEN
           CALL WRITEV(LUN2,X,NSAM1,NROW1,2*NSAM,2*NROW,NSLICE)
        ELSE
           DO J=NR2,NROW+NR2-1
              CALL  WRTLIN(LUN2,X(NS2,J),NSAM,J-NR2+1)
	   ENDDO 
        ENDIF

        DEALLOCATE (X,Y)
5       CLOSE(LUN1)
        CLOSE(LUN2)
        CLOSE(LUN3)
        RETURN

130     CALL ERRT(4,'MCCF  ',NE)
        GOTO 5

145     CALL ERRT(2,'MCCF  ',NE)
        GOTO 5
        END
