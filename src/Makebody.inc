# 
#  SOURCE:  Makebody.inc
#  PURPOSE: MAKEFILE body FOR Linux SPIDER  
#  AUTHOR:  ArDean Leith -- 13 MARCH 1997
#  NOTE:    You may ignore undefined $(DEST) 
# 
#  NOTE:  June 2015. I have reports that ifort requires *.o be retained??

../bin/$(EXE)$(DEST) : $(LIB)
	$(COMP) $(LF)  $(LIB) $(LINKLIBS) -o ../bin/$(EXE)$(DEST) 
	@echo "Created: ../bin/$(EXE)$(DEST)"
	@echo " "

$(LIB) : $(ELEMENTS)
	@echo "        linking $(EXE)$(DEST) now ----"
.f.a:
	$(COMP) $(FFLAGS) $<
	$(AR) $(AFLAGS) $(LIB) $*.o
	@\rm $*.o

