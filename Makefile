config ?= debug

ifdef config
  ifeq (,$(filter $(config),debug release))
    $(error Unknown configuration "$(config)")
  endif
endif

ifeq ($(config),debug)
    PONYC-FLAGS += --debug
endif

NAME = kuafu
BUILDDIR = /dev/shm/$(NAME)
TARGET = $(BUILDDIR)/$(config)/test
BUILDSCRIPTS = corral.json lock.json
SRCDIR = $(NAME)
SRCS = $(wildcard $(SRCDIR)/*.pony)

EXAMPLES-DIR := examples
EXAMPLES := $(notdir $(shell find $(EXAMPLES-DIR)/* -type d))
EXAMPLES-SOURCE_FILES := $(shell find $(EXAMPLES-DIR) -name *.pony)
EXAMPLES-BINARIES := $(addprefix $(BUILDDIR)/,$(EXAMPLES))

PONYC ?= ponyc
COMPILE-WITH := corral run -- $(PONYC)
PONYC-FLAGS += -V1 -o $(BUILDDIR)/$(config)

ifeq ($(ssl),1.1.x)
  PONYC-FLAGS += -Dopenssl_1.1.x
else ifeq ($(ssl),0.9.0)
  PONYC-FLAGS += -Dopenssl_0.9.0
else
  PONYC-FLAGS += -Dopenssl_1.1.x
endif

DEPS = _corral/github_com_ponylang_logger/ \
       _corral/github_com_ponylang_http_server/ \
       _corral/github_com_titan_pony_bitset_router/

all: $(TARGET)

$(TARGET): $(SRCS) $(DEPS)
	$(COMPILE-WITH) $(PONYC-FLAGS) --bin-name=test $(NAME)

$(DEPS): corral.json
	corral fetch

examples: $(EXAMPLES-BINARIES)

$(EXAMPLES-BINARIES): $(BUILDDIR)/%: $(SOURCE-FILES) $(EXAMPLES-SOURCE-FILES) $(DEPS)
	$(COMPILE-WITH) $(PONYC-FLAGS) $(EXAMPLES-DIR)/$*

prebuild:
ifeq "$(wildcard $(BUILDDIR))" ""
	@mkdir -p $(BUILDDIR)/$(config)
endif

clean:
	rm -rf $(BUILDDIR)

.PHONY: all clean examples prebuild
