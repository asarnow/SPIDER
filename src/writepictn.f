
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


        SUBROUTINE WRITEPICTN(BUF,NSAM,NROW,NSLICE,LUN,FILNAM)
       
C       SUBROUTINE TO TEST THINGS.
        INCLUDE 'CMBLOCK.INC'

        CHARACTER*(*) FILNAM
        DIMENSION     BUF(NSAM*NROW*NSLICE)

        IF (FILNAM(1:1) .NE. '*') THEN
       
C          USE OPFILE, BR      
           MAXIM = 0
           CALL OPFILEC(0,.FALSE.,FILNAM,LUN,'U',IFORM,NSAM,NROW,
     &                  NSLICE,MAXIM,' ',.FALSE.,IRTFLG)
           IF (IRTFLG .NE. 0) RETURN
        
           DO IROW=1,NROW*NSLICE
              IND = (IROW-1)*NSAM+1
              CALL WRTLIN(LUN,BUF(IND),NSAM,IROW)
           ENDDO
           CLOSE(LUN)
        ENDIF

        RETURN
        END
