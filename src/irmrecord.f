
C FUNCTION TO CALCULATE LINE IN 3D VOLUME FROM EULER ANGLES AND LINE
C LOCATION IN 2D RADON TRANSFORM
C MEANING OF VARIABLES:
C SG,CG   SIN(GAMMA), COS(GAMMA) (= FIRST EULER ANGLE PHI IN PJ 3)
C SB,CB   SIN(BETA), COS(BETA)   (= SECOND EULER ANGLE THETA IN PJ 3)
C SA,CA   SIN(ALPHA), COS(ALPHA) (= THIRD EULER ANGLE PSI - IN PLANE
C                                   ROTATION)
C LOGICALS:                                  
C MIRR    FLAG IF LINE IS MIRRORED BECAUSE OF REDUNCANCIES IN THE
C         RADON TRANSFORM
C DEBFLAG INDICATES LOTS OF DEBUGGING OUTPUT DESIRED
C EFLAG   INDICATES OPTION FOR EQUALIZED SAMPLING
C INTEGERS:
C IRTFLG  ERROR FLAG, 1 FOR O.K., -1 FOR NOT O.K.
C FURTHER DATA REFER TO THE 3D RADON TRANSFORM:
C PINC    INCREMENT IN PHI
C TINC    INCREMENT IN THETA
C TTO     END VALUE OF THETA
C TFRO    START VALUE OF THETA
C PTO     END VALUE OF PHI
C PFRO    START VALUE OF PHI
C ALL ANGLES ARE IN RADIANS
C NROW    Y-DIMENSION OF 3D RADON TRANSFORM
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


	INTEGER FUNCTION IRMRECORD
     $	(SG,CG,SB,CB,SA,CA,MIRR,DEBFLAG,EFLAG,IRTFLG,PINC,TINC,
     $   TTO,TFRO,PTO,PFRO,NROW)
     
        INCLUDE 'CMBLOCK.INC'
        LOGICAL MIRR,DEBFLAG,EFLAG
        DIMENSION R(7)
        IRTFLG=1
        PI=3.1415927
        RTOD=180./PI
        XX = (CB*SA*CG + CA*SG)
        YY = (CA*CG-CB*SA*SG)
        ZZ = SB*SA
C CALCULATE BACKWARDS:
        YI=YY
        IF(YI.GT.1.) THEN
           WRITE(NOUT,201) YI
201        FORMAT(1X,'COSINE = ',E10.4, ' SET TO +-1')
           YI=1.
        ENDIF
        IF(YI.LT.-1.) THEN
           WRITE(NOUT,201) YI
           YI=-1.
        ENDIF
        PHI=ACOS(YI)
        SPHI=SIN(PHI)
        IF(SPHI.NE.0) THEN
           CT=XX/SPHI
           ST=ZZ/SPHI
        ELSE 
           CT=1
           ST=0
        ENDIF
        IF(CT.NE.0) THEN
           THET=ATAN2(ST,CT)
        ELSE
           IF(ST.GT.0) THET=PI/2.
           IF(ST.LT.0) THET=-PI/2
        ENDIF

C       RECALCULATE COORDINATES IN TERMS OF THETA AND PHI:
        ST=SIN(THET)
        CT=COS(THET)
        SP=SIN(PHI)
        CP=COS(PHI)
        XNEW=CT*SP
        YNEW=CP
        ZNEW=ST*SP
   
        R(1)=XX
        R(2)=YY
        R(3)=ZZ
        R(4)=ST
        R(5)=CT
        R(6)=PHI/PI*180.
        IF(DEBFLAG) WRITE(NDAT,101) (R(LL),LL=1,6)
101     FORMAT(1X,'XX,YY,ZZ,ST,CT,PHI',6(1X,F12.4))
        R(2)=XNEW
        R(3)=YNEW
        R(4)=ZNEW
        R(5)=THET/PI*180.
        R(6)=PHI/PI*180.
        IF(DEBFLAG) WRITE(NDAT,102) (R(LL),LL=1,6)
102     FORMAT(1X,'XNEW,YNEW,ZNEW,THETA,PHI',6(1X,F12.4))
C       CALCULATE THETA AND PHI ACCORDING TO EQUALIZED SAMPLING:
        IF(EFLAG) THEN
           TPHI=PHI
           TTHET=THET
           PHI=QPHI(TPHI,PINC)
           THET=QTHETA(TTHET,TINC,PHI)
           IF(DEBFLAG) 
     $   WRITE(NOUT,999) TPHI*RTOD,PHI*RTOD, TTHET*RTOD, THET*RTOD
999      FORMAT(1X,'PHI,THETA BEFORE AND AFTER:',4(F12.4,1X))
        ENDIF
C       DO ROUNDINGS:
        T=ABS(THET)
        ITET=T/TINC+.5

        IF(THET.LT.0) THEN
           THET=-ITET*TINC
        ELSE
           THET=ITET*TINC
        ENDIF

        P=ABS(PHI)
        IPHI=P/PINC+.5

        IF(PHI.LT.0) THEN
           PHI=-IPHI*PINC
        ELSE
           PHI=IPHI*PINC
        ENDIF

C       CALCULATE LINE IN RADON VOLUME:
        IF(THET.GT.TTO+0.01)THEN 
           THET=THET-PI
           IF(THET.LT.TFRO-.01) THEN
              WRITE(NOUT,*) THET,' THETA OUT OF RANGE'
              GOTO 1000
           ENDIF
           PHI=-PHI
        ENDIF

        IF(THET.LT.TFRO-0.01)THEN 
           THET=THET+PI
           IF(THET.GT.TTO+.01) THEN
              WRITE(NOUT,*) THET,' THETA OUT OF RANGE'
              GOTO 1000
           ENDIF
           PHI=-PHI
        ENDIF

        IF(PHI.GT.PTO+0.01)THEN 
           PHI=PHI-2*PI
        ENDIF

        IF(PHI.LT.PFRO-0.01)THEN 
           PHI=PHI+2*PI
           IF(PHI.GT.PTO+.01) THEN
              IF(DEBFLAG) WRITE(NOUT,*) PHI,' PHI OUT OF RANGE'
              MIRR=.TRUE.
              PHI=PHI-PI
           ENDIF
        ENDIF

        R(2)=XNEW
        R(3)=YNEW
        R(4)=ZNEW
        R(5)=THET/PI*180.
        R(6)=PHI/PI*180.
        IF(DEBFLAG) WRITE(NDAT,103) (R(LL),LL=1,6)
103     FORMAT(1X,'XNEW,YNEW,ZNEW,THETA,PHI',6(1X,F12.4))

C       THE ADDITIONAL CONSTANT WAS 1.01, CHANGED TO 1.5 (I.E. ROUNDING)
        IPLANE=(THET-TFRO)/TINC+1.5
        IROW=(PHI-PFRO)/PINC+1.5
        IRMRECORD=(IPLANE-1)*NROW+IROW
C       WRITE(NDAT,998) IPLANE,IROW,IRMRECORD
998     FORMAT(1X,'IRMRECORD: IPLANE,IROW,IREC', 3(I6,2X))
        RETURN
1000    IRTFLG=-1
        IRMRECORD=1
        RETURN
        END
