CSD_INPUT_DIR := _input/csd
CSD_OUTPUT_DIR := csd
CSD_SRC  := $(wildcard $(CSD_INPUT_DIR)/*.xml)
BIB_OUTPUT_DIR := relaton
BIB_YAML_OUTPUT_DIR := relaton/yaml
BIB_XML_OUTPUT_DIR := relaton/xml
BIB_COLL_OUTPUT_DIR := relaton/collections
CSD_BASENAMES := $(basename $(CSD_SRC))
CSD_OUTPUT_DIRS := $(patsubst $(CSD_INPUT_DIR)/%,$(CSD_OUTPUT_DIR)/%,$(CSD_BASENAMES))
CSD_OUTPUT_XML := $(addsuffix .xml,$(CSD_OUTPUT_DIRS))
CSD_OUTPUT_HTML := $(patsubst %.xml,%.html,$(CSD_OUTPUT_XML))
CSD_OUTPUT_PDF := $(patsubst %.xml,%.pdf,$(CSD_OUTPUT_XML))
CSD_OUTPUT_DOC := $(patsubst %.xml,%.doc,$(CSD_OUTPUT_XML))
CSD_OUTPUT_RXL := $(patsubst %.xml,%.rxl,$(CSD_OUTPUT_XML))
BIB_XML_CSD_OUTPUT := $(patsubst $(CSD_OUTPUT_DIR)/%,$(BIB_XML_OUTPUT_DIR)/%,$(CSD_OUTPUT_RXL))
BIB_YAML_CSD_OUTPUT := $(patsubst $(CSD_OUTPUT_DIR)/%,$(BIB_YAML_OUTPUT_DIR)/%,$(patsubst %.rxl,%.yaml,$(CSD_OUTPUT_RXL)))

SHELL := /bin/bash

ifdef METANORMA_DOCKER
  PREFIX_CMD := echo "Running via docker..."; docker run -v "$$(pwd)":/metanorma/ $(METANORMA_DOCKER)
else
  PREFIX_CMD := echo "Running locally..."; bundle exec
endif

SED_INFO := $(shell sed --version >/dev/null 2>&1; echo $$?)
ifeq ($(SED_INFO),1)
	# macOS
  SED_COMMAND := sed -i ""
else
	# Linux
  SED_COMMAND := sed -i --
endif

NAME_ORG := "CalConnect"
CSD_REGISTRY_NAME := "CalConnect Document Registry"
RXL_COL_OUTPUT := $(BIB_COLL_OUTPUT_DIR)/csd.rxl $(BIB_COLL_OUTPUT_DIR)/admin.rxl $(BIB_COLL_OUTPUT_DIR)/external.rxl
MN_ARTIFACTS := .tmp.xml *_images
RELATON_INDEX_OUTPUT := $(BIB_OUTPUT_DIR)/index.rxl $(BIB_OUTPUT_DIR)/index.yaml

all: _documents $(CSD_OUTPUT_HTML) $(RELATON_INDEX_OUTPUT)

clean:
	rm -rf _site _documents
	rm -rf $(MN_ARTIFACTS)
	rm -rf _input/*.rxl _input/csd.yaml
	rm -rf $(BIB_OUTPUT_DIR)

build-csd: $(CSD_OUTPUT_HTML)

clean-csd:
	rm -rf $(CSD_OUTPUT_DIR)

_site: all
	bundle exec jekyll build

distclean: clean clean-csd

# Make collection YAML files into adoc files
_documents: _input/csd.yaml $(BIB_YAML_OUTPUT_DIR)
	mkdir -p $@; \
	for filename in $(BIB_YAML_OUTPUT_DIR)/*.yaml; do \
		FN=$${filename##*/}; \
		$(MAKE) $@/$${FN//yaml/adoc}; \
	done

_documents/%.adoc: $(BIB_YAML_OUTPUT_DIR)/%.yaml
	cp $< $@ && \
	echo "---" >> $@;

serve:
	bundle exec jekyll serve

$(BIB_OUTPUT_DIR):
	mkdir -p $@

$(BIB_COLL_OUTPUT_DIR):
	mkdir -p $@

# Here we concatenate all RXL files generated by metanorma
# This allows us to generate the RXL links within the RXL collection
_input/csd.rxl: $(CSD_OUTPUT_DIR) $(CSD_OUTPUT_RXL)
	${PREFIX_CMD} relaton concatenate \
	  -t $(CSD_REGISTRY_NAME) \
		-g $(NAME_ORG) -n \
	  $(CSD_OUTPUT_DIR) $@; \
	$(SED_COMMAND) 's+$(CSD_INPUT_DIR)+csd+g' $@

_input/%.rxl: _input/%.yaml
	${PREFIX_CMD} relaton yaml2xml $<

_input/csd.yaml: _input/csd.rxl
	${PREFIX_CMD} relaton xml2yaml $<

$(BIB_OUTPUT_DIR)/index.rxl: $(BIB_XML_OUTPUT_DIR)
	${PREFIX_CMD} relaton concatenate \
	  -t $(CSD_REGISTRY_NAME) \
		-g $(NAME_ORG) -n \
	  $(BIB_XML_OUTPUT_DIR) $@

$(BIB_XML_OUTPUT_DIR): $(RXL_COL_OUTPUT)
	mkdir -p $@; \
	for coll in $^; do \
	${PREFIX_CMD} relaton split \
		$$coll \
		$(BIB_XML_OUTPUT_DIR) \
		-x rxl -n; \
	done

$(BIB_OUTPUT_DIR)/index.yaml: $(BIB_YAML_OUTPUT_DIR)
	${PREFIX_CMD} relaton concatenate \
	  -t $(CSD_REGISTRY_NAME) \
		-g $(NAME_ORG) \
	  $(BIB_YAML_OUTPUT_DIR) $@

$(BIB_YAML_OUTPUT_DIR): $(RXL_COL_OUTPUT)
	mkdir -p $@; \
	for coll in $^; do \
	${PREFIX_CMD} relaton split \
		$$coll \
		$(BIB_YAML_OUTPUT_DIR) \
		-x yaml -n; \
	done

$(BIB_COLL_OUTPUT_DIR)/%.rxl:	_input/%.rxl | $(BIB_COLL_OUTPUT_DIR)
	cp $< $@;

$(BIB_COLL_OUTPUT_DIR)/%.yaml:	_input/%.yaml | $(BIB_COLL_OUTPUT_DIR)
	cp $< $@;

$(CSD_OUTPUT_DIR):
	mkdir -p $@

$(CSD_OUTPUT_DIR)/%.html $(CSD_OUTPUT_DIR)/%.pdf $(CSD_OUTPUT_DIR)/%.doc $(CSD_OUTPUT_DIR)/%.rxl $(CSD_OUTPUT_DIR)/%.xml:
	cp $(CSD_INPUT_DIR)/$(notdir $*).xml $(CSD_OUTPUT_DIR) && \
	cd $(CSD_OUTPUT_DIR) && \
	${PREFIX_CMD} metanorma -t csd -x html,pdf,doc,xml,rxl $*.xml

# This empty target is necessary so that make detects changes in _input/*.yaml
_input/%.yaml:

update-init:
	git submodule update --init

update-modules:
	git submodule foreach git pull origin master

.PHONY: bundle all open serve clean clean-csd build-csd update update-modules
