ROOT=$(JHBUILD_SOURCE)/$(DIR)/build
DEST=$(ROOT)/universal

LIPO=./lipo-r.sh
INSTALL=cp -RXf
ARCH=ppc i386 x86_64

all: lipoit

lipoit: clean
	-mkdir -p $(DEST)
	$(LIPO) $(ROOT) ${ARCH} $(DEST)

install:
	$(INSTALL) $(DEST)/* /

clean:
	-rm -R $(DEST)