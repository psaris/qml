include $(dir $(lastword $(MAKEFILE_LIST)))common.mk

VERSION := 0.7.1-$(shell date +%Y%m%d)

OBJS := const.o alloc.o util.o opt.o \
        libm.o cephes.o lapack.o conmin.o conmax.o nlopt.o
INCLUDES := alloc.h util.h opt.h wrap.h conmin.h conmax.h nlopt.h

PKG_INCLUDES := $(addprefix ../include/, \
    cprob.h lapack.h k.h \
    neldermead.h cobyla.h nlopt.h nlopt-util.h)

# Don't use -L../lib -lprob etc. to avoid unintentionally linking to possibly
# incompatible system libraries if the libraries we built are missing.

# OpenBLAS has custom implementations of some LAPACK routines, so link
# libopenblas before (and after) liblapack. The same approach doesn't work below
# for dynamically-linked system libraries, but that should be handled by the
# system (e.g. Debian provides an OpenBLAS version of liblapack).

PKG_LIBS := $(patsubst %,../lib/lib%.a, \
    prob conmax nlopt \
    $(if $(BUILD_OPENBLAS),openblas) \
    $(if $(BUILD_LAPACK),lapack) $(if $(BUILD_BLAS),refblas) \
    $(if $(BUILD_OPENBLAS),openblas) \
    $(if $(WINDOWS),q))

CFLAGS += -std=gnu99 -Wall -Wextra -Wno-missing-field-initializers
DEFINES = -DQML_VERSION=$(VERSION) -DKXARCH=$(KXARCH) -DKXVER=$(KXVER)

all: build

build: $(foreach proj,qml svm linear,$(proj).$(DLLEXT))

%.o: %.c $(INCLUDES) $(PKG_INCLUDES)
	$(CC) -I../include \
	    $(FLAGS) \
	    $(CFLAGS) \
	    $(DEFINES) \
	    -c -o $@ $<

svm.o: svm.c $(INCLUDES) $(PKG_INCLUDES)
	$(CC) -I../include -shared \
	    $(FLAGS) \
	    $(CFLAGS) \
	    $(DEFINES) \
	    -c -o $@ $<

linear.o: linear.c $(INCLUDES) $(PKG_INCLUDES)
	$(CC) -I../include -shared \
	    $(FLAGS) \
	    $(CFLAGS) \
	    $(DEFINES) \
	    -c -o $@ $<

qml.$(DLLEXT): $(OBJS) qml.symlist qml.mapfile $(PKG_LIBS)
	$(CC) $(FLAGS) $(LD_SHARED) -o $@ $(OBJS) \
	    $(PKG_LIBS) \
	    $(LDFLAGS) \
	    $(LIBS_LAPACK) $(LIBS_BLAS) \
	    $(call ld_static,$(LIBS_FORTRAN)) \
	    -lm \
	    $(call ld_export,qml)

svm.$(DLLEXT): svm.symlist svm.mapfile $(LIBS_SVM) svm.o
	$(CC) $(FLAGS) $(LD_SHARED) -o $@ svm.o \
	    ../lib/libsvm.o \
	    -lstdc++ $(LDFLAGS) \
	    $(call ld_static,$(LIBS_SVM)) \
	    -lm \
	    $(call ld_export,svm)

linear.$(DLLEXT): linear.symlist linear.mapfile $(LIBS_LINEAR) linear.o
	$(CC) $(FLAGS) $(LD_SHARED) -o $@ linear.o \
	    ../lib/liblinear.o ../lib/libtron.o \
	    -lstdc++ $(LDFLAGS) \
	    $(if $(BUILD_BLAS),,$(if $(BUILD_OPENBLAS),../lib/libopenblas.a,$(LIBS_BLAS))) \
	    $(call ld_static,$(LIBS_LINEAR)) \
	    -lm \
	    $(call ld_export,linear)

qml.symlist: $(OBJS)
	$(call nm_exports,$(OBJS)) | sed -n 's/^qml_/_&/p' >$@.tmp
	$(if $(BUILD_BLAS)$(BUILD_OPENBLAS),,echo _xerbla_ >>$@.tmp)
	mv $@.tmp $@

qml.mapfile: qml.symlist
	echo "{ global:"             >$@.tmp
	sed 's/^_/    /;s/$$/;/' $< >>$@.tmp
	echo "  local: *; };"       >>$@.tmp
	mv $@.tmp $@

svm.symlist: svm.o
	$(call nm_exports,$^) | sed -n 's/^qml_/_&/p' >$@.tmp
	mv $@.tmp $@

svm.mapfile: svm.symlist
	echo "{ global:"             >$@.tmp
	sed 's/^_/    /;s/$$/;/' $< >>$@.tmp
	echo "  local: *; };"       >>$@.tmp
	mv $@.tmp $@

linear.symlist: linear.o
	$(call nm_exports,$^) | sed -n 's/^qml_/_&/p' >$@.tmp
	mv $@.tmp $@

linear.mapfile: linear.symlist
	echo "{ global:"             >$@.tmp
	sed 's/^_/    /;s/$$/;/' $< >>$@.tmp
	echo "  local: *; };"       >>$@.tmp
	mv $@.tmp $@

ifneq ($(QHOME),)
# don't export QHOME because q below should get it from the general environment
install: build
	install $(addsuffix .$(DLLEXT),qml svm linear) '$(QHOME)'/$(KXARCH)/
	install qml.q svm.q linear.q                   '$(QHOME)'/

uninstall:
	rm -f -- $(foreach proj,qml svm linear,'$(QHOME)'/$(KXARCH)/$(proj).$(DLLEXT))
	rm -f -- $(foreach proj,qml svm linear,'$(QHOME)'/$(proj).q
endif

# can override on make command-line
TEST_OPTS=
testqml: build
	q test.q -cd -s 16 $(TEST_OPTS) </dev/null
testsvm: build
	cd ../svm/work && q ../../src/testsvm.q 2>/dev/null </dev/null
testlinear: build
	cd ../linear/work && q ../../src/testlinear.q 2>/dev/null </dev/null

ifneq ($(BUILD_LIBSVM),)
test: testsvm
endif
ifneq ($(BUILD_LIBLINEAR),)
test: testlinear
endif
test: testqml

BENCH_OPTS=
bench: build
	q bench.q -cd $(BENCH_OPTS) </dev/null

.PHONY: clean_src clean_misc
clean_src:
clean_misc:
clean: clean_src clean_misc
	rm -f $(foreach proj,qml svm linear,$(proj).so $(proj).dll $(proj).symlist $(proj).mapfile)
	rm -rf $(foreach proj,qml svm linear,$(proj).so.dSYM)
	rm -f $(OBJS) svm.o linear.o


SRC = $(patsubst %.o,%.c,$(OBJS) svm.o linear.o) $(INCLUDES)

define rule_cp
$(1): $(2)
	cp -- $(2) $(1)
endef

define rule_clean_src
clean_src:
	rm -f -- $$(SRC)
endef

define copy_src
$(foreach src,$(SRC),$(eval $(call rule_cp,$(src),$(addprefix $(1)/,$(src)))))\
$(eval $(rule_clean_src))
endef
