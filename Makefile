INCLUDEPATH = cmurphi-master/include
SRCPATH = cmurphi-master/src/

CXX = g++ -g -O3 -DDISK_MURPHI

# scalar set of the left half of the tree and the right half of the tree
# CFLAGS = -DYYSTACKSIZE=10000000

# optimization
OFLAGS =
#OFLAGS = -O3

#Murphi options
MURPHIOPTS = -b -c

MSI: MSI.cpp
	${CXX} ${CFLAGS} ${OFLAGS} -o MSI MSI.cpp -I${INCLUDEPATH} -lm

MSI.cpp: MSI.m
	${SRCPATH}mu ${MURPHIOPTS} MSI.m

