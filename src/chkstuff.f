C++*********************************************************************
C
C  CHKSTUFF.F                    
C
C **********************************************************************
C=*                                                                    *
C=* This file is part of:   SPIDER - Modular Image Processing System.  *
C=* SPIDER System Authors:  Joachim Frank & ArDean Leith               *
C=* Copyright 1985-2008  Health Research Inc.,                         *
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
C PURPOSE:  UTILITY ROUTINES FOR QUICK DEBUGGING
C
C
C **********************************************************************

C     --------------------- CHKFILE ------------------------------------

      SUBROUTINE CHKFILE(FILNAM,LUNOUT,ITYPE,NX,NY,NZ, BUF,IRTFLG)

      IMPLICIT NONE

      CHARACTER (LEN=*) :: FILNAM  
      INTEGER           :: LUNOUT,ITYPE,NX,NY,NZ,IRTFLG
      REAL              :: BUF(*)

      INTEGER           :: MAXIM
 
      !write(6,*) 'writing:',filnam,lunout,itype,nx,ny,nz
      MAXIM = 0
      CALL OPFILEC(0,.FALSE.,FILNAM,LUNOUT,'U',ITYPE,
     &               NX,NY,NZ, MAXIM,' ',.TRUE.,IRTFLG)

      CALL WRTVOL(LUNOUT,NX,NY, 1,NZ, BUF,IRTFLG)
      CLOSE(LUNOUT)

      END 

C     --------------------- CHKPADFILE ------------------------------------

      SUBROUTINE CHKPADFILE(FILNAM,LUNOUT,ITYPE,
     &            NXP,NYP,NZP, NX,NY,NZ, BUF,IRTFLG)

      IMPLICIT NONE

      CHARACTER (LEN=*) :: FILNAM  
      INTEGER           :: LUNOUT,ITYPE, NXP,NYP,NZP,NX,NY,NZ 
      REAL              :: BUF(NXP,NYP,NZP)
      INTEGER           :: IRTFLG

      INTEGER           :: MAXIM,IREC,IZ,IY
 
      MAXIM = 0
      CALL OPFILEC(0,.FALSE.,FILNAM,LUNOUT,'U',ITYPE,
     &               NX,NY,1, MAXIM,' ',.TRUE.,IRTFLG)

      IREC = 0
      DO IZ = 1,NZ
         DO IY = 1,NY
           IREC = IREC + 1
           CALL WRTLIN(LUNOUT,BUF(1,IY,IZ),NX,IREC)
         ENDDO
      ENDDO                      

      CLOSE(LUNOUT)

      END 


C     --------------------- CHKCMPLX ------------------------------------

      SUBROUTINE CHKCMPLX(MSG,  CQC,N, NEND,NBY, NXTRA)

      COMPLEX           :: CQC(N)
      CHARACTER (LEN=*) :: MSG

      WRITE(6,*) ' ',MSG, ' ---------------'

      DO I = 1,NEND,NBY
         WRITE(6,90)I, CQC(I)
90       FORMAT(I10,'  ( ',F12.2,',',F12.2,' )')
      ENDDO
      IF (NXTRA > 0) WRITE(6,90)NXTRA, CQC(NXTRA)
      WRITE(6,*)' '

      END 

C     --------------------- CHKREAL ------------------------------------

      SUBROUTINE CHKREAL(MSG, FQC,N, NEND,NBY, NXTRA)

      REAL              :: FQC(N)
      CHARACTER (LEN=*) :: MSG

      WRITE(6,*) '  ',MSG, ' ---------------'

      DO I = 1,NEND,NBY
         WRITE(6,90)I, FQC(I)
90       FORMAT(I10,'  ( ',F12.3,' )')
      ENDDO
      IF (NXTRA > 0) WRITE(6,90)NXTRA, FQC(NXTRA)
      WRITE(6,*)' '

      END 

C     --------------------- CHKMAX ------------------------------------

      SUBROUTINE CHKMAX(MSG,  QC,N)

      REAL              :: QC(N)
      CHARACTER (LEN=*) :: MSG   

      FMAXT = MAXVAL(QC(1:n))                               
      WRITE(6,90)MSG,FMAXT
90    FORMAT(' Max ',A,': ',1pG12.4)

      end

C     --------------------- CHKMIN ------------------------------------

      SUBROUTINE CHKMIN(MSG,  QC,N)

      REAL              :: QC(N)
      CHARACTER (LEN=*) :: MSG   

      FMINT = MINVAL(QC(1:N))                               
      WRITE(6,90)MSG,FMINT
90    FORMAT(' Min ',A,': ',1pG12.4)

      END 

C     --------------------- CHKRANGE ------------------------------------

      SUBROUTINE CHKRANGE(MSG,  QC,N)

      REAL              :: QC(N)
      CHARACTER (LEN=*) :: MSG   

      FMAXT = MAXVAL(QC(1:N))                               
      FMINT = MINVAL(QC(1:N))                               
      WRITE(6,90)MSG,FMINT,FMAXT
90    FORMAT(' Range ',A,': ',1pG12.4,' ...',1pG12.4)

      END

C     --------------------- CHKMINLOC ------------------------------------

      SUBROUTINE CHKMINLOC(MSG,QC,N)

      IMPLICIT NONE
      REAL              :: QC(N)
      CHARACTER (LEN=*) :: MSG 
      INTEGER           :: N
  
      INTEGER           :: MINL_ARRAY(1),LOCT
      REAL              :: FMINT

      MINL_ARRAY = MINLOC(QC(1:N)) ! RETURNS ARRAY OF LENGTH: 1
      LOCT       = MINL_ARRAY(1)

      FMINT      = QC(LOCT)                               
      WRITE(6,90)MSG,FMINT,LOCT                                  
90    FORMAT(' MIN ',A,': ',1pG12.4,' LOCATION: ',I9)                        

      END 

C     --------------------- CHKMAXLOC ------------------------------------

      SUBROUTINE CHKMAXLOC(MSG,QC,N)

      IMPLICIT NONE
      REAL              :: QC(N)
      CHARACTER (LEN=*) :: MSG 
      INTEGER           :: N
  
      INTEGER           :: MAXL_ARRAY(1),LOCT
      REAL              :: FMAXT

      MAXL_ARRAY = MAXLOC(QC(1:N)) ! RETURNS ARRAY OF LENGTH: 1
      LOCT       = MAXL_ARRAY(1)

      FMAXT      = QC(LOCT)                               
      WRITE(6,90)MSG,FMAXT,LOCT                                  
90    FORMAT(' MAX ',A,': ',1pG12.4,' LOCATION: ',I9)                        

      END 

C     --------------------- CHKMAXLOC2D ------------------------------------

      SUBROUTINE CHKMAXLOC2D(MSG,QC,NX,NY)

      IMPLICIT NONE
      REAL              :: QC(NX,NY)
      CHARACTER (LEN=*) :: MSG 
      INTEGER           :: NX,NY
  
      INTEGER           :: MAXL_ARRAY(2),LOCX,LOCY
      REAL              :: FMAXT

      MAXL_ARRAY = MAXLOC(QC) ! RETURNS ARRAY OF LENGTH: 2
      LOCX       = MAXL_ARRAY(1)
      LOCY       = MAXL_ARRAY(2)

      FMAXT      = QC(LOCX,LOCY)                               
      WRITE(6,90)MSG, FMAXT, LOCX,LOCY                                  
90    FORMAT(' MAX ',A,': ',1PG12.4,' LOCATION: (',I9,',',I9,')',/)                        

      END 


C     --------------------- CHKAVG ------------------------------------

      SUBROUTINE CHKAVG(MSG,QC,NPIX)

      IMPLICIT NONE
      REAL              :: QC(NPIX)
      CHARACTER (LEN=*) :: MSG 
      INTEGER           :: NPIX
  
      INTEGER           :: I
      REAL              :: SUM,AVT

      SUM = 0.0

      DO I= 1,NPIX
         SUM = SUM + QC(I)
      ENDDO

      AVT = SUM / FLOAT(NPIX)

      WRITE(6,90)MSG, AVT                                 
90    FORMAT(' AVG ',A,': ',1PG12.4)                        

      END 


C     --------------------- CHKRAY ------------------------------------


       SUBROUTINE CHKRAY(IRAY,TRANS, CIRC,LCIRC, 
     &                    NUMR,NRING, NLOCS,NRAYSC)
 
        IMPLICIT NONE

        INTEGER,          INTENT(IN)  :: IRAY
        LOGICAL,          INTENT(IN)  :: TRANS

        COMPLEX,          INTENT(IN)  :: CIRC(LCIRC)
        INTEGER,          INTENT(IN)  :: LCIRC
        INTEGER,          INTENT(IN)  :: NUMR(3,NRING)
        INTEGER,          INTENT(IN)  :: NRING
        INTEGER,          INTENT(IN)  :: NLOCS(2,NRAYSC)
        INTEGER,          INTENT(IN)  :: NRAYSC

        INTEGER                       :: NVAL,JGO,J,IRING,IGO,NRAYS,IR
        INTEGER                       :: MAXRIN,IR1

        WRITE(6,*) ' -------------- CHKRAY:',IRAY,'  ------'

        MAXRIN = NUMR(3,NRING)

        IF (TRANS) THEN
C          CIRC HAS TRANSFORMED RING ORDER (BY RAYS)
           IF (IRAY .GT. NRAYSC) THEN
              WRITE(6,*) ' *** MAX RAY IS:',NRAYSC
              STOP
           ENDIF

           NVAL   = NLOCS(1,IRAY)       ! # PTS (#RINGS) ON THIS RAY 
           JGO    = NLOCS(2,IRAY)       ! INDEX OF RAY START
           IR1    = NRING-NVAL+1        ! # OF FIRST RING

           WRITE(6,*) ' PTS ON RAY (WITH FFT PAD):',NVAL,' IGO:',JGO
 
           DO J= JGO,JGO+NVAL-1         ! LOOP OVER RINGS ON RAY
              IR    = J-JGO             ! RELATIVE RING NUMBER
              IRING = IR1+IR            ! RING NUMBER 
              WRITE(6,90) J,IRING,CIRC(J)
           ENDDO

        ELSE
C          USUAL NON-TRANSFORMED RING ORDER (BY RINGS)
           IR = 0
           DO IRING = 1,NRING

              IGO   = NUMR(2,IRING)/2+1   ! STARTING INDEX FOR RING 
              NRAYS = NUMR(3,IRING)/2     ! LENGTH OF RING (# RAYS)

              !WRITE(6,*) ' RING:',IRING,' RAYS :',NRAYS

              J     = IGO+IRAY-1          ! CURRENT CIRC INDEX
              IR    = IR+1                ! CURRENT RAY NUMBER

              IF (IRAY .GT. NRAYS) THEN
                 !WRITE(6,*) IRING,IGO,NRAYS,IR,J
                 CYCLE
              ENDIF

              WRITE(6,90) J,IR,CIRC(J)
90            FORMAT( ' ',I5,I8,': (',F10.3,',',F10.3,')')  
           ENDDO
        ENDIF

        END

C     --------------------- CHKRING ------------------------------------


       SUBROUTINE CHKRING(IRING,TRANS, CIRC,LCIRC, 
     &                    NUMR,NRING, NLOCS,NRAYSC)
 
        IMPLICIT NONE

        INTEGER,          INTENT(IN)  :: IRING
        LOGICAL,          INTENT(IN)  :: TRANS

        COMPLEX,          INTENT(IN)  :: CIRC(LCIRC)
        INTEGER,          INTENT(IN)  :: LCIRC
        INTEGER,          INTENT(IN)  :: NUMR(3,NRING)
        INTEGER,          INTENT(IN)  :: NRING
        INTEGER,          INTENT(IN)  :: NLOCS(2,NRAYSC)
        INTEGER,          INTENT(IN)  :: NRAYSC

        INTEGER                       :: IRAY,NR,JGO,IR1,IR,J
        INTEGER                       :: IGO,NRAYS

        WRITE(6,*) ' -------------- CHKRING:',IRING,'  ------'
        WRITE(6,*) '    J     IRAY          CIRC(J)'

        IF (IRING .GT. NRING) THEN
           WRITE(6,*) ' *** MAX RING IS:',NRING
           STOP
        ENDIF
        !write(6,*) '     iray,   nr,    jgo,    ir1,     ir,       j'

        IF (TRANS) THEN
C          CIRC HAS TRANSFORMED RING ORDER (BY RAYS)

           DO IRAY = 1,NRAYSC
              NR   = NLOCS(1,IRAY)      ! # PTS (#RINGS) ON THIS RAY 
              JGO  = NLOCS(2,IRAY)      ! INDEX OF RAY START
              IR1  = NRING-NR+1         ! ACTUAL # OF FIRST RING ON RAY

              IF (IRING >= IR1) THEN    ! RING INCLUDED IN THIS RAY
                 IR = IRING-IR1         ! RELATIVE RING #
                 J  = JGO+IR          
                 !write(6,91) iray,nr,jgo,ir1,ir,j,CIRC(J)
91               FORMAT( ' ',6i7,': (',F9.3,',',F9.3,')')
                 WRITE(6,90) J,IRAY,CIRC(J)
              ELSE
                 EXIT
              ENDIF
           ENDDO

        ELSE
C          USUAL NON-TRANSFORMED RING ORDER (BY RINGS)

           IGO   = NUMR(2,IRING)/2+1   ! STARTING CMPLX INDEX FOR RING 
           NRAYS = NUMR(3,IRING)/2     ! CMPLX LENGTH OF RING (# RAYS)

           DO J = IGO, IGO+NRAYS-1
              IRAY = J-IGO+1
              WRITE(6,90) J,IRAY,CIRC(J)
90            FORMAT( ' ',I5,I8,': (',F10.3,',',F10.3,')') 
           ENDDO 
        ENDIF

        END

C     --------------------- CHKPLOT ------------------------------------

      SUBROUTINE CHKPLOT(FILNAM,LUNOUT,NX,NY, NYT,BUF,IRTFLG)

C     PLOTS A 1D LINE:BUF  IN SPIDER IMAGE

      IMPLICIT NONE

      CHARACTER (LEN=*)  :: FILNAM  
      INTEGER            :: LUNOUT,NX,NY,NYT
      REAL               :: BUF(NX)

      INTEGER            :: ITYPE,MAXIM,IRTFLG 
      INTEGER            :: IX,IY
      REAL               :: BUFOUT(NX,NYT)
      REAL               :: FMINT,FMAXT

      !write(6,*) 'writing:',filnam,lunout,itype,nx,ny,nz
      MAXIM = 0
      ITYPE = 1
      CALL OPFILEC(0,.FALSE.,FILNAM,LUNOUT,'U',ITYPE,
     &               NX,NY,1, MAXIM,' ',.TRUE.,IRTFLG)

      FMINT = MINVAL(BUF)
      FMAXT = MINVAL(BUF)

      BUFOUT = 0.0  ! ARRAY OP
   
      DO IX = 1,NX

C        CURVE HEIGHT

         IY = BUF(IX) - FMINT / (FMAXT - FMINT) * NY

         IF (IY < 1 .OR. IY > NYT) THEN
            CALL ERRT(102,'CHKPLOT; BAD IY VALUE',IY)
            RETURN
         ENDIF

         BUFOUT(IX,IY) = 1.0
      ENDDO

      CALL WRTVOL(LUNOUT,NX,NYT, 1,1, BUFOUT,IRTFLG)
      CLOSE(LUNOUT)

      END 
