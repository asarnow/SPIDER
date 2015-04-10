C=**********************************************************************
C  CC1GFILT
C
C  OPFILEC                                         FEB 03 ARDEAN LEITH
C
C=**********************************************************************
C=* From: SPIDER - MODULAR IMAGE PROCESSING SYSTEM                     *
C=* Copyright (C)2000  M. Radermacher                                  *
C=*                                                                    *
C=* Email:  spider@wadsworth.org                                       *
C=*                                                                    *
C=* This program is free software; you can redistribute it and/or      *
C=* modify it under the terms of the GNU General Public License as     *
C=* published by the Free Software Foundation; either version 2 of the *
C=* License, or (at your option) any later version.                    *
C=*                                                                    *
C=* This program is distributed in the hope that it will be useful,    *
C=* but WITHOUT ANY WARRANTY; without even the implied warranty of     *
C=* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU  *
C=* General Public License for more details.                           *
C=*                                                                    *
C=* You should have received a copy of the GNU General Public License  *
C=* along with this program; if not, write to the                      *
C=* Free Software Foundation, Inc.,                                    *
C=* 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.      *
C=*                                                                    *
C=**********************************************************************
C
C  CC1GFILT
C       SUBROUTINE TO ASK FOR FILTER OPTION AND CALCULATE FILTER FUNCTION.
C       FILTER FUNTION IS RETURNED IN FIL. IDIM SHOULD BE THE X-DIMENSION
C       OF THE FOURIER TRANSFORM. (NORMALLY NSAM/2+1). FIL(1)=1 BEING THE
C       FACTOR FOR F(0).
C
C        OPFILEC                                  FEB 03 ARDEAN LEITH
C=**********************************************************************

        SUBROUTINE CC1GFILT(FIL,IDIM,FFLAG,IROW)
        
        INCLUDE 'CMBLOCK.INC'
        INCLUDE 'CMLIMIT.INC'

        DIMENSION    FIL(IDIM)
        DIMENSION    FLINE(1024)
        LOGICAL      FFLAG,MFLAG,PRESERVE,DIVIDE,RECIP
        CHARACTER*1  YN,NULL
        INTEGER      H

        CHARACTER (LEN=MAXNAM) :: FILN1

        NULL=CHAR(0)
        FFLAG=.FALSE.
        NC=1
C 
        CALL RDPRMC(YN,NC,.TRUE.,'FOURIER FILTER Y/N$',NULL,IRTFLG)
        IF(YN.EQ.'Y') FFLAG=.TRUE.
        IF(.NOT.FFLAG) RETURN
        CALL RDPRMI(MANY,IDUM,NOT_USED,'# OF FILTRATIONS 1/2$')
C       IF(MANY.GT.2) MANY=2
        MFLAG=.FALSE.
        NC=1
        CALL RDPRMC(YN,NC,.TRUE.,'(A)DDITIVE (=DEF),(M)ULTIPLICATIVE$'
     $  ,NULL,IRTFLG)
        DO 10 H=2,IDIM
10      FIL(H)=0.
        FIL(1)=1.
        DO 6 I=1,MANY
           IF(I.GT.1.AND.YN.EQ.'M') MFLAG=.TRUE.
           WRITE(NOUT,1001) 
1001       FORMAT(' FILTER OPTIONS:'/
     $ '   (1)CUTOFF L.P. (2) CUTOFF H.P.'/
     $ '   (3)GAUSSIAN .L.P. (4)GAUSSIAN .H.P.'/
     $ '   (5)FERMI L.P. (6)FERMI H.P.'/ 
     $ '   (7)R*, (8)SQRT(R*), (9) READ FILTER')
           CALL RDPRMI(IOPT,IDUM,NOT_USED,'FILTER OPTION')
           IF(.NOT.FFLAG) RETURN

         IF(IOPT.LT.7) CALL RDPRM(PARM1,NOT_USED,'FILTER RADIUS')
C          IF PARM1 <= 0.5 THEN ABSOLUTE FOURIER UNITS WERE USED. CALCULATE 
C          THE RADIUS IN FOURIER PIXELS:
           IF(PARM1.LE.0.5) PARM1=PARM1*2*(IDIM-1)
           GOTO(100,200,300,400,500,500,700,800,900),IOPT

100        R2 = PARM1
           DO 150 H = 1,IDIM-1
              IF(MFLAG)  THEN
                 IF(H.GT.R2) THEN 
                    FIL(H+1)=FIL(H+1)*0.
                 ELSE
                    FIL(H+1)=FIL(H+1)*1.
                 ENDIF
              ELSE
                 IF(H.GT.R2) THEN 
                    FIL(H+1)=FIL(H+1)+0.
                 ELSE
                    FIL(H+1)=FIL(H+1)+1.
                 ENDIF
              ENDIF
150        CONTINUE
           GOTO 6

200        R2 = PARM1
           DO 250 H = 1,IDIM-1
              IF(MFLAG)THEN
                 IF(H.LT.R2) THEN
                    FIL(1+H)=FIL(1+H)*0.
                 ELSE
                    FIL(1+H)=FIL(1+H)*1.
                 ENDIF
              ELSE
                 IF(H.LT.R2) THEN
                    FIL(1+H)=FIL(1+H)+0.
                 ELSE
                    FIL(1+H)=FIL(1+H)+1.
                 ENDIF
              ENDIF
250        CONTINUE

           GOTO 6
300        F1 = -1./(PARM1**2)

           DO 350 H =1,IDIM-1
	      FH2=FLOAT(H)**2
              IF(MFLAG) THEN
	         FIL(1+H)=FIL(1+H)*EXP(F1*FH2)
              ELSE
	         FIL(1+H)=FIL(1+H)+EXP(F1*FH2)
              ENDIF
350	   CONTINUE
           GOTO 6

400        F1 = -1./(PARM1**2)
           DO 450 H = 1,IDIM-1
	      FH2=FLOAT(H)**2
              IF(MFLAG) THEN
                 FIL(1+H)=FIL(1+H)*(1.-EXP(F1*FH2))
              ELSE
                 FIL(1+H)=FIL(1+H)+1.-EXP(F1*FH2)
              ENDIF
450	   CONTINUE
           GOTO 6

500	   CALL RDPRM(TEMP,NOT_USED,'TEMPERATURE(0=CUTOFF)$')
C          IF TEMP <= 0.5 THEN ABSOLUTE FOURIER UNITS WERE USED. CALCULATE 
C          THE TEMP IN FOURIER PIXELS:
           IF(TEMP.LE.0.5) TEMP=TEMP*2*(IDIM-1)
	   IF(IOPT.EQ.6)TEMP=-TEMP
           DO 550 H = 1,IDIM-1
	      R=FLOAT(H) 
	      ARG=(R-PARM1)/TEMP
	      IF(ARG.GT.10.)ARG=10.
	      IF(ARG.LT.-10.)ARG=-10.
              IF(MFLAG) THEN
	         FIL(1+H)=FIL(1+H)*(1./(1+EXP(ARG)))
              ELSE
	         FIL(1+H)=FIL(1+H)+(1./(1+EXP(ARG)))
              ENDIF
550	   CONTINUE
           GOTO 6
700        DO 750 H =1,IDIM-1
              IF(MFLAG)THEN
	         FIL(1+H)=FIL(1+H)*H
              ELSE
	         FIL(1+H)=FIL(1+H)+H
              ENDIF
750	   CONTINUE
           FIL(1)=0.
           GOTO 6       
800        DO 850 H =1,IDIM-1
              S=FLOAT(H)
              IF(MFLAG)THEN
	         FIL(1+H)=FIL(1+H)*SQRT(S)
              ELSE
	         FIL(1+H)=FIL(1+H)+SQRT(S)
              ENDIF
850	   CONTINUE
           FIL(1)=0.
           GOTO 6 
         
900        CALL FILERD(FILN1,NLET,NULL,'INPUT',IRTFLG)
           IF(FILN1(1:1).EQ.'*') RETURN
           LUN1=77
           
C          USE OPFILE, BR      
           MAXIMA = 0
           CALL OPFILEC(0,.FALSE.,FILN1,LUN1,'O',IFORM,NSAM,NROW,
     &                  NSLICE,MAXIMA,' ',.FALSE.,IRTFLG)
        
           WRITE(NOUT,901) NROW
901        FORMAT(1X,' FILE HAS ',I6,'ROWS')
           CALL RDPRMI(KROW,IDUM,NOT_USED,
     $     'WHICH LINE DO YOU WANT TO USE AS FILTER$')
           CALL REDLIN(LUN1,FLINE,NSAM,KROW)
           CLOSE(LUN1)
C          NORMALIZE LINE TO A MAXIMUM OF 1:
           FMAX=FLINE(1)
           AVG=0.
           DO KK=2,NSAM
              IF(FLINE(KK).GT.FMAX) FMAX=FLINE(KK)
              AVG=AVG+FLINE(KK)
           ENDDO
           AVG=AVG/FLOAT(NSAM)
           AVG=AVG/FMAX
           DO KK=1,NSAM
              FLINE(KK)=FLINE(KK)/FMAX
           ENDDO    
           WRITE(NOUT,903)
903        FORMAT(1X,'AVERAGE OF NORMALIZED FILTER FUNCTION:',G12.4)
           CALL RDPRMC(YN,NC,.TRUE.,
     $      '(S)TRAIGHT OR (R)RECIPROCAL$',NULL,IRTFLG)
           IF(YN.EQ.'R') THEN
              RECIP=.TRUE.
              CALL RDPRM(WIEN,NOT_USED,'WIENER FACTOR$')
           ELSE
              RECIP=.FALSE.
           ENDIF
           RATIO=FLOAT(NSAM)/FLOAT(IDIM)
           DO 902 L=1,IDIM
              FIND=L*RATIO
              IIND1=INT(FIND)
              IF(IIND1.GT.NSAM) IIND1=NSAM
              IF(IIND1.EQ.0) THEN
                 V=FLINE(1)
              ELSE
                 DELTA=FIND-FLOAT(IIND1)
                 IIND2=IIND1+1
                 IF(IIND2.GT.NSAM) IIND2=NSAM
                 V=FLINE(IIND2)*DELTA+FLINE(IIND1)*(1-DELTA)
              ENDIF

              IF(RECIP) THEN
                 FIL(L)=1./(V+WIEN)
              ELSE
                 FIL(L)=V
              ENDIF
902        CONTINUE
           GOTO 6
6       CONTINUE
        WRITE(NDAT,82) (FIL(I),I=1,IDIM)
82      FORMAT(1H ,'FILTER: ',10(E10.4,1X))
5       CONTINUE
        WRITE(NOUT,1002)
        PRESERVE=.FALSE.
        DIVIDE=.FALSE.
1002    FORMAT(' (P)RESERVE AVERAGE,(D)IVIDE AVERAGE BY NROW,'/
     $' (A)PPLY FILTER ALSO TO AVERAGE (=DEFAULT)')
        CALL RDPRMC(YN,NC,.TRUE.,' P, D OR A',NULL,IRTFLG)
        IF(YN.EQ.'P') PRESERVE=.TRUE.
        IF(YN.EQ.'D') DIVIDE=.TRUE.
        IF(PRESERVE) FIL(1)=1.
        IF(DIVIDE) FIL(1)=1/FLOAT(IROW)
        RETURN
        END
