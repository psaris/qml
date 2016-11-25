include ../mk/src.mk

CFLAGS += \
    -Wno-uninitialized -Wno-parentheses -Wno-sign-compare \
    -Wno-unused -Wno-unused-parameter

build:
	$(STRIP) $(STRIP_FLAGS) $(addsuffix .$(DLLEXT),qml svm linear)
