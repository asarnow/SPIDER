
C **********************************************************************
C SETNUMRINGS.F        FROM ALPRBS_Q_NEQ          DEC 12 ARDEAN LEITH
C                   
C  C **********************************************************************
C=* This file is part of:   SPIDER - Modular Image Processing System.  *
C=* Authors: J. Frank & A. Leith                                       *
C=* Copyright 1985-2012  Health Research Inc.,                         *
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
C=* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU  *
C=* General Public License for more details.                           *
C=* You should have received a copy of the GNU General Public License  *
C=* along with this program. If not, see <http://www.gnu.org/licenses> *
C=*                                                                    *
C **********************************************************************
C
C SETNUMRINGS(MR,NR,ISKIP,MODE, IRAY, NUMR,NRING,LCIRC, IRTFLG)
C
C PURPOSE: CREATES NUMR ARRAY HOLDING THE SPECIFICATIONS FOR THE
C          RADIAL RINGS.
C
C PARAMETERS:   MR,NR,ISKIP RING START, END, SKIP               SENT
C               IRAY        RAY SKIP INCREMENT (1,2,4,8...)     SENT
C               MODE        FULL OR HALF CIRCLE                 SENT
C               NUMR(:,:)   RING SPEC. ARRAY                    RET.
C               NUMR(1,I)   RING NUMBER = RADIUS                SENT
C               NUMR(2,I)   BEGINNING IN CIRC                   RET.
C               NUMR(3,I)   LENGTH IN CIRC                      RET.
C               NRING       # OF RINGS                          RET.
C               LCIRC       TOTAL LENGTH OF CIRCLE ARRAYS       RET.
C               IRTFLG      ERROR FLAG                          RET.
C               LCIRC        TOTAL LENGTH OF CIRC               RET.
C               IRAY        RAY SKIP INCREMENT (1,2,4,8...)     SENT
C
C23456789 123456789 123456789 123456789 123456789 123456789 123456789 12
C--*********************************************************************

#ifdef NEVER

     ----------- SETNUMRINGS ------------------------------------
C      SETNUMRINGS EXPLICIT INTERFACE NEEDED BY SUBROUTINES THAT CALL
C      SETNUMRINGS

        INTERFACE ! ---------------------
        SUBROUTINE SETNUMRINGS(MR,NR,ISKIP,MODE, IRAY,
     &                         NUMR,NRING,LCIRC,
     &                         IRTFLG)
        INTEGER, INTENT(IN)     :: MR,NR,ISKIP ! RING START, END, SKIP
        INTEGER, INTENT(IN)     :: IRAY        ! RAY SKIP
        CHARACTER*1, INTENT(IN) :: MODE        ! FULL OR HALF CIRCLE
        INTEGER, ALLOCATABLE    :: NUMR(:,:)   ! RING SPEC. ARRAY
        INTEGER, INTENT(OUT)    :: NRING       ! # OF RINGS
        INTEGER, INTENT(OUT)    :: LCIRC       ! TOTAL LENGTH OF CIRCLE ARRAYS
        INTEGER, INTENT(OUT)    :: IRTFLG      ! ERROR FLAG

        END SUBROUTINE SETNUMRINGS
        END INTERFACE !--------------------
#endif

C       ----------- SETNUMRINGS ------------------------------------

        SUBROUTINE SETNUMRINGS(MR,NR,ISKIP,MODE, IRAY,
     &                         NUMR,NRING,LCIRC,
     &                         IRTFLG)

        IMPLICIT NONE

C       FOR MAXFFT
        INCLUDE 'CMLIMIT.INC'

        INTEGER, INTENT(IN)     :: MR,NR,ISKIP ! RING START, END, SKIP
        INTEGER, INTENT(IN)     :: IRAY        ! RAY SKIP
        CHARACTER*1, INTENT(IN) :: MODE        ! FULL OR HALF CIRCLE
        INTEGER, ALLOCATABLE    :: NUMR(:,:)   ! RING SPEC. ARRAY
        INTEGER, INTENT(OUT)    :: NRING       ! # OF RINGS
        INTEGER, INTENT(OUT)    :: LCIRC       ! TOTAL LENGTH OF CIRCLE ARRAYS
        INTEGER, INTENT(OUT)    :: IRTFLG      ! ERROR FLAG

        REAL*8                  :: PI
        INTEGER                 :: MAXFFTT
        INTEGER                 :: I,JP,IP
        INTEGER                 :: log2

C       FIND NUMBER OF REFERENCE-RINGS IN USE
        NRING=0
        DO I=MR,NR,ISKIP
           NRING = NRING + 1
        ENDDO

        ALLOCATE(NUMR(3,NRING),STAT=IRTFLG)
        IF (IRTFLG .NE. 0) THEN
           CALL ERRT(46,'SETNUMRINGS; NUMR',3*NRING)
           RETURN
        ENDIF

C       INITIALIZE NUMR ARRAY WITH RING RADII
        NRING = 0
        DO I=MR,NR,ISKIP
           NRING         = NRING + 1
           NUMR(1,NRING) = I
        ENDDO

C       CALCULATES NUMR & LCIRC, EACH RING HAS FFT PAD OF 2 FLOATS
        !CALL ALPRBS_Q_NEW(NUMR,NRING,LCIRC,MODE,IRAY)

        MAXFFTT = MAXFFT

C       PREPARATION OF PARAMETERS
        PI = 4.0 * DATAN(1.0D0)
        IF (MODE == 'F')  PI = 2 * PI

        LCIRC = 0              ! TOTAL LENGTH OF CIRCLE ARRAYS

        DO I=1,NRING
           JP = PI * NUMR(1,I)
           IP = 2 ** LOG2(JP)
           IF (I < NRING .AND. JP > IP+IP/2)IP = MIN(MAXFFTT,2*IP)
      
C          LAST RING OVERSAMPLED TO IMPROVE ACCURACY OF PEAK LOCATION (?).
           IF (I == NRING .AND. JP > IP+IP/5) IP = MIN(MAXFFTT,2*IP)

           IF (IRAY > 1) THEN
               !IPT = IP / IRAY    ! RAY SKIP 
               !write(6,*) ' ring,jp,ip --> ip:',i,jp,ip,ipt
               IP = IP / IRAY 
           ENDIF

C          ALL THE RINGS ARE POWER-OF-TWO. ADD 2 TO LEN TO USE FFT.
           IP        = IP + 2
           NUMR(3,I) = IP                ! LENGTH OF CIRCLE + PAD
           LCIRC     = LCIRC + IP        ! TOTAL LENGTH OF CIRCLE ARRAYS

           IF (I == 1) THEN
              NUMR(2,1) = 1
           ELSE
              NUMR(2,I) = NUMR(2,I-1) + NUMR(3,I-1)
           ENDIF
           !write(6,*) '  Numr:',numr(1:3,i)


        ENDDO

        END

