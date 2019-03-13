CSD_INPUT_DIR := _input/csd
CSD_OUTPUT_DIR := csd
CSD_SRC  := $(wildcard $(CSD_INPUT_DIR)/*.xml)
BIB_OUTPUT_DIR := bib
BIBCOLL_OUTPUT_DIR := bibcoll
BIB_CSD_YAML := $(addprefix bib/,$(patsubst %.xml,%.rxl,$(notdir $(CSD_SRC))))
CSD_BASENAMES := $(basename $(CSD_SRC))
CSD_OUTPUT_DIRS := $(patsubst $(CSD_INPUT_DIR)/%,$(CSD_OUTPUT_DIR)/%,$(CSD_BASENAMES))
CSD_OUTPUT_XML := $(addsuffix .xml,$(CSD_OUTPUT_DIRS))
CSD_OUTPUT_HTML := $(patsubst %.xml,%.html,$(CSD_OUTPUT_XML))
CSD_OUTPUT_PDF := $(patsubst %.xml,%.pdf,$(CSD_OUTPUT_XML))
CSD_OUTPUT_DOC := $(patsubst %.xml,%.doc,$(CSD_OUTPUT_XML))
CSD_OUTPUT_RXL := $(patsubst %.xml,%.rxl,$(CSD_OUTPUT_XML))

SHELL := /bin/bash
SED_INFO := $(shell sed --version >/dev/null 2>&1; echo $$?)
ifeq ($(SED_INFO),1)
	# macOS
  SED_COMMAND := sed -i ""
else
	# Linux
  SED_COMMAND := sed -i --
endif

NAME_ORG := "CalConnect : The Calendaring and Scheduling Consortium"
CSD_REGISTRY_NAME := "CalConnect Document Registry: Standards"
ADMIN_REGISTRY_NAME := "CalConnect Document Registry: Administrative Documents"
INDEX_OUTPUT := index.xml admin.rxl external.rxl
RXL_COL_OUTPUT := _input/csd.yaml bibcoll/csd.rxl bibcoll/admin.rxl bibcoll/external.rxl
RXL_COL_OUTPUT_2 := $(wildcard _input/*.rxl)
MN_ARTIFACTS := .tmp.xml *_images

all: _documents $(CSD_OUTPUT_HTML)

clean:
	rm -f $(INDEX_OUTPUT)
	rm -rf _site _documents $(RXL_COL_OUTPUT) $(RXL_COL_OUTPUT_2)
	rm -rf $(MN_ARTIFACTS)
	rm -rf $(BIB_OUTPUT_DIR) $(BIBCOLL_OUTPUT_DIR)

build-csd: $(CSD_OUTPUT_HTML)

clean-csd:
	rm -rf $(CSD_OUTPUT_HTML) $(CSD_OUTPUT_PDF) $(CSD_OUTPUT_DOC) $(CSD_OUTPUT_RXL)

_site: all
	bundle exec jekyll build

distclean: clean clean-csd

# Make collection YAML files into adoc files
_documents: $(RXL_COL_OUTPUT)
	mkdir -p $@
	for filename in bib/*.yaml; do \
		FN=$${filename##*/}; \
		$(MAKE) $@/$${FN//yaml/adoc}; \
	done

_documents/%.adoc: $(BIB_OUTPUT_DIR)/%.yaml
	cp $< $@ && \
	echo "---" >> $@;

serve:
	bundle exec jekyll serve

$(BIB_OUTPUT_DIR):
	mkdir -p $@

$(BIBCOLL_OUTPUT_DIR):
	mkdir -p $@


# Here we concatenate all RXL files generated by metanorma
# This allows us to generate the RXL links within the RXL collection
_input/csd.rxl: $(CSD_OUTPUT_DIR) $(CSD_OUTPUT_RXL)
	bundle exec relaton concatenate \
	  -t $(CSD_REGISTRY_NAME) \
		-g $(NAME_ORG) \
	  $(CSD_OUTPUT_DIR) $@; \
	$(SED_COMMAND) 's+$(CSD_INPUT_DIR)+csd+g' $@

_input/%.rxl: _input/%.yaml
	bundle exec relaton yaml2xml $<

_input/csd.yaml: _input/csd.rxl
	bundle exec relaton xml2yaml $<

$(BIBCOLL_OUTPUT_DIR)/%.rxl: _input/%.rxl $(BIB_OUTPUT_DIR) $(BIBCOLL_OUTPUT_DIR)
	bundle exec relaton split \
		$< \
		$(BIB_OUTPUT_DIR) \
		-x rxl; \
	bundle exec relaton split \
		$< \
		$(BIB_OUTPUT_DIR) \
		-x yaml;

$(CSD_OUTPUT_DIR):
	mkdir -p $@

$(CSD_OUTPUT_DIR)/%.html $(CSD_OUTPUT_DIR)/%.pdf $(CSD_OUTPUT_DIR)/%.doc $(CSD_OUTPUT_DIR)/%.rxl $(CSD_OUTPUT_DIR)/%.xml:
	cp $(CSD_INPUT_DIR)/$(notdir $*).xml $(CSD_OUTPUT_DIR) && \
	cd $(CSD_OUTPUT_DIR) && \
	bundle exec metanorma -t csd -R $*.rxl -x html,pdf,doc,xml $*.xml

# This empty target is necessary so that make detects changes in _input/*.yaml
_input/%.yaml:

update-init:
	git submodule update --init

update-modules:
	git submodule foreach git pull origin master

.PHONY: bundle all open serve clean clean-csd build-csd update update-modules
