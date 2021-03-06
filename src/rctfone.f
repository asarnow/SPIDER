C++*********************************************************************
C
C RCTFONE.F                FROM RCTFSS              NOV 10 ARDEAN LEITH
C **********************************************************************
C=*                                                                    *
C=* This file is part of:   SPIDER - Modular Image Processing System.  *
C=* SPIDER System Authors:  Joachim Frank & ArDean Leith               *
C=* Copyright 1985-2014  Health Research Inc.,                         *
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
C  RCTFONE(LUN1)
C
C  PARAMETERS  WITHCONJ  USE CONJUGATE FOR MULTIPLCATION.
C
C  PURPOSE: 2D and 3D CTF CORRECTION USING WIENER FILTERING            
C
C23456789012345678901234567890123456789012345678901234567890123456789012
C--*********************************************************************

        SUBROUTINE RCTFONE(LUN1)

        INCLUDE 'CMBLOCK.INC'
        INCLUDE 'CMLIMIT.INC'

        CHARACTER(LEN=MAXNAM) :: FILNAM,FILNAMC
        COMPLEX, ALLOCATABLE  :: VOLIN(:,:,:) 
        COMPLEX, ALLOCATABLE  :: VOLSUM(:,:,:)
        COMPLEX, ALLOCATABLE  :: CTF2(:,:,:)
        CHARACTER(LEN=1)      :: NULL

        CALL SET_MPI(ICOMM,MYPID,MPIERR)  ! SET MYPID

           NULL = CHAR(0)

C          OPEN IMAGE/VOLUME  FILE (CAN BE IN FOURIER FORMAT)
           MAXIM = 0
           CALL OPFILEC(0,.TRUE.,FILNAM,LUN1,'O',IFORM,
     &               NSAM1,NROW1,NSLICE1,
     &               MAXIM,'IMAGE/VOLUME',.TRUE.,IRTFLG)
           IF (IRTFLG.NE.0)  GOTO 9999

C          PROCESS THE IMAGE/VOLUME

           INUMDEM = 0  ! INUMDEM RECORDS 3D OR 2D: 3=3D, 1=2D

           IF (IFORM == -11)  THEN
              LRCL    = NSAM1
              LS      = NSAM1
              NSAM1   = NSAM1-1
              INUMDEM = 1
           ELSEIF (IFORM == -12)   THEN
              LRCL    = NSAM1
              LS      = NSAM1
              NSAM1   = NSAM1-2
              INUMDEM = 1
           ELSEIF (IFORM  ==  1)   THEN
              LS      =NSAM1+2-MOD(NSAM1,2)
              LRCL    =NSAM1
              INUMDEM = 1
           ELSEIF (IFORM  ==  -21) THEN
              LRCL    = NSAM1
              LS      = NSAM1
              NSAM1   = NSAM1-1
              INUMDEM = 3
           ELSEIF (IFORM  ==  -22) THEN
              LRCL    = NSAM1
              LS      = NSAM1
              NSAM1   = NSAM1-2
              INUMDEM = 3
           ELSEIF (IFORM  ==  3)   THEN
              LS      = NSAM1+2-MOD(NSAM1,2)
              LRCL    = NSAM1
              INUMDEM = 3
           ELSE
              CALL ERRT(2,'TF CTF',NE)
              GOTO 9999
           ENDIF

C          GET THE DIMENSION INFORMATION 
           NSAM   = NSAM1
           NROW   = NROW1
           NSLICE = NSLICE1

           MWANT = (LS/2) * NROW * NSLICE
           ALLOCATE(VOLIN( LS/2,NROW,NSLICE),
     &              VOLSUM(LS/2,NROW,NSLICE),  STAT=IRTFLG)
           IF (IRTFLG .NE. 0) THEN
               CALL ERRT(46,'RCTFONE, VOLIN...',2*MWANT)
               RETURN
           ENDIF

C          SET OUTPUT VOLUME TO ZERO
           VOLSUM = 0.0
 
C          READ INPUT VOLUME/IMAGE FILE (DO NOT USE REDVOL)
           DO L=1,NSLICE
              DO J=1,NROW
                 CALL REDLIN(LUN1,VOLIN(1,J,L),LRCL,J+(L-1)*NROW)
              ENDDO
           ENDDO
           IF (MYPID .LE. 0) CLOSE(LUN1)

           IF ((IFORM == 1) .OR. (IFORM == 3)) THEN
C             FOURIER TRANSFORM NECESSARY
              INV = +1
              CALL FMRS_3(VOLIN,NSAM,NROW,NSLICE,INV)

              IF (INV  ==  0)  THEN
                 CALL ERRT(101,'FFT ERROR',NE)
                 GOTO 9999
              ENDIF
           ENDIF

           MAXIM = 0
           CALL OPFILEC(0,.TRUE.,FILNAMC,LUN1,'O',IFORM,
     &                  NSAM1,NROW1,NSLICE1,
     &                  MAXIM,'CTF',.TRUE.,IRTFLG)
           IF (IRTFLG.NE.0) GOTO 9999

           LRCL1   = NSAM1
           INUMCTF = 0  ! RECORDS 3D OR 2D INUMCTF: 3=3D, 1=2D

           IF    (IFORM  ==  -11) THEN
              NSAM1   = NSAM1-1
              INUMCTF = 1
           ELSEIF (IFORM  ==  -12) THEN
              NSAM1   = NSAM1-2
              INUMCTF = 1
           ELSEIF (IFORM  ==  -21) THEN
              NSAM1   = NSAM1-1
              INUMCTF = 3
           ELSEIF (IFORM  ==  -22) THEN
              NSAM1   = NSAM1-2
              INUMCTF = 3
           ELSE
              CALL  ERRT(101,'CTF FILE MUST BE IN FOURIER FORMAT',NE)
              GOTO 9999
           ENDIF

           IF (INUMCTF .NE. INUMDEM) THEN
              CALL ERRT(2,'INCONSISTENT DATA FORMAT',NE)
              GOTO 9999
           ENDIF

c          VERIFY DIMENSIONS OF THE CTF
           IF (NSAM.NE.NSAM1.OR.NROW.NE.NROW1.OR.NSLICE.NE.NSLICE1)THEN
              CALL ERRT(101,'INCONSISTENT DIMENSIONS',NE)
              GOTO 9999
           ENDIF

C          MUTLIPLY INPUT VOLUME STORED IN VOLIN BY CTF, 
C          PLACE OUTPUT IN VOLSUM.
           CALL MULFN3(LUN1,VOLIN,VOLSUM,     LRCL1/2,NROW,NSLICE)

C          REVERSE FFT 
           INV = -1
           CALL FMRS_3(VOLSUM,NSAM,NROW,NSLICE,INV)

C          OPEN THE OUTPUT FILE
           IFORM = INUMCTF
           MAXIM = 0
           CALL OPFILEC(0,.TRUE.,FILNAM,LUN1,'N',IFORM,NSAM,NROW,NSLICE,
     &              MAXIM,'OUTPUT',.FALSE.,IRTFLG)
           IF (IRTFLG.NE.0) GOTO 9999

C          WRITE THE OUTPUT TO FILE (DO NOT USE WRTVOL)
           DO L=1,NSLICE
              DO J=1,NROW
                 CALL WRTLIN(LUN1,VOLSUM(1,J,L),NSAM,J+(L-1)*NROW)
              ENDDO
           ENDDO

9999       IF (MYPID .LE. 0) CLOSE(LUN1)

           IF (ALLOCATED(CTF2))   DEALLOCATE(CTF2)
           IF (ALLOCATED(VOLSUM)) DEALLOCATE(VOLSUM)
           IF (ALLOCATED(VOLIN))  DEALLOCATE(VOLIN)

           END

 
C++*********************************************************************
C
C MULFN3.F                         
C
C **********************************************************************
C **********************************************************************
C
C  MULFN3(LUN1,VOLIN,VOLSUM, NN2,NROW,NSLICE)
C
C  PARAMETERS:  LUN1      INPUT UNIT FOR CTF FILE              (INPUT)
C               VOLIN     FFT OF INPUT IMAGE                   (INPUT)
C               VOLSUM    VOLOUT + VOLIN * B1                  (OUTPUT)
C               NN2       ROW LENGTH                           (INPUT)
C               NROW      IMAGE ROWS                           (INPUT)        
C               NSLICE    VOLUME SLICES                        (INPUT) 
C       
C  PURPOSE:    
C
C23456789012345678901234567890123456789012345678901234567890123456789012
C--*********************************************************************

        SUBROUTINE MULFN3(LUN1,VOLIN,VOLSUM, NN2,NROW,NSLICE)

        COMPLEX  :: VOLIN(NN2,NROW,NSLICE)
        COMPLEX  :: VOLSUM(NN2,NROW,NSLICE)

        COMPLEX  :: B1(NN2)

        DO K=1,NSLICE
          DO J=1,NROW
            NR1 = J+(K-1)*NROW
            CALL REDLIN(LUN1,B1,2*NN2,NR1)

            DO I=1,NN2
               VOLSUM(I,J,K) = VOLSUM(I,J,K) + VOLIN(I,J,K) * B1(I)
            ENDDO
          ENDDO
        ENDDO

	END

