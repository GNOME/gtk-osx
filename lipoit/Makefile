ROOT=$(JHBUILD_SOURCE)/$(DIR)/build
DEST=$(ROOT)/universal

LIPO=./lipo-r.sh
INSTALL=cp -RXf

all: lipoit

lipoit: clean
	-mkdir -p $(DEST)
	$(LIPO) $(ROOT) "ppc i386" $(DEST)

install:
	$(INSTALL) $(DEST)/* /

clean:
	-rm -R $(DEST)