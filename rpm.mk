RELEASE=1
TARGET=target/packaging
_PACKAGING=$(if $(PACKAGING), $(PACKAGING), ../.packaging)
_SOURCES=$(if $(SOURCES), $(SOURCES), src)

POST_INSTALL=$(TARGET)/_post-install.sh
PRE_UNINSTALL=$(TARGET)/_pre_uninstall.sh

_RPMROOT=$(TARGET)/rpmroot
_OUT=$(TARGET)/packages
_REQUIRES:=$(foreach f, $(REQUIRES_PACKAGES), --depends $f)
_REPLACES:=$(foreach f, $(REPLACES_PACKAGES), --replaces $f)
_CONFLICTS:=$(foreach f, $(CONFLICTS), --conflicts $f)
_PROFILES:=$(if $(wildcard profiles/*), $(foreach f, $(wildcard profiles/*), $(notdir $f)), default)
_PROVIDES:=$(if $(PROVIDES), $(foreach p, $(PROVIDES), --provides $p), --provides $(PACKAGE))
_CONFIG_FILES:=$(if $(CONFIG_FILES), $(foreach f, $(CONFIG_FILES), --config-files $f),)

all: $(_PROFILES) clean-temp
	echo "##teamcity[buildNumber '$(VERSION)-$(RELEASE)']"
	mkdir -p $(_OUT)
	mv $(PACKAGE)*.rpm $(_OUT)

clean: clean-temp
	rm -rf $(TARGET)

clean-temp::
	rm -f $(POST_INSTALL)
	rm -f $(PRE_UNINSTALL)
	rm -rf $(_RPMROOT)

$(REQUIRES_SERVICES):
	cat $(_PACKAGING)/service-install.sh | sed s/SERVICE/$(@)/g >> $(POST_INSTALL)

$(OPTIONAL_SERVICES):
	cat $(_PACKAGING)/service-opt-install.sh | sed s/SERVICE/$(@)/g >> $(POST_INSTALL)

$(PROVIDES_SERVICES):
	cat $(_PACKAGING)/service-install.sh | sed s/SERVICE/$(@)/g >> $(POST_INSTALL)
	cat $(_PACKAGING)/service-remove.sh | sed s/SERVICE/$(@)/g >> $(PRE_UNINSTALL)

$(_PROFILES): _P_REPLACES=$(foreach f, $(shell cat profiles/$(@)/rpm.mk | grep REPLACES_PACKAGES | sed 's/REPLACES_PACKAGES=\(.*\)/\1/g'), --replaces $f)
$(_PROFILES): _P_REQUIRES=$(foreach f, $(shell cat profiles/$(@)/rpm.mk | grep REQUIRES_PACKAGES | sed 's/REQUIRES_PACKAGES=\(.*\)/\1/g'), --depends $f)
$(_PROFILES): rpm-prepare $(REQUIRES_SERVICES) $(OPTIONAL_SERVICES) $(PROVIDES_SERVICES) rpm-post-init
	for s in `cat profiles/$(@)/rpm.mk | grep REQUIRES_SERVICES | sed 's/REQUIRES_SERVICES=\(.*\)/\1/g'` ; do \
	cat $(_PACKAGING)/service-install.sh | sed s/SERVICE/$$s/g >> $(POST_INSTALL) ; done
	
	mkdir -p $(_RPMROOT)/$(@)
	cp -r $(_SOURCES)/* $(_RPMROOT)/$(@) || true
	cp -r profiles/$(@)/* $(_RPMROOT)/$(@) || true
	fpm -C $(_RPMROOT)/$(@) -s dir -t rpm -n $(PACKAGE)$(if $(subst default,,$@),-$@,) \
	    --version=$(VERSION) --iteration=$(RELEASE) \
	    $(if $(_CONFIG_FILES), $(shell [ "$(@)" != "test" ] && echo "$(_CONFIG_FILES)"), $(shell [ -d profiles/$(@)/opt/$(PACKAGE)/conf ] && [ "$(@)" != "test" ] && echo --config-files opt/$(PACKAGE)/conf)) \
	    $(_REQUIRES) $(_P_REQUIRES) \
	    $(_REPLACES) $(_P_REPLACES) \
	    $(_PROVIDES) $(_CONFLICTS) \
	    --post-install $(POST_INSTALL) \
	    --pre-uninstall $(PRE_UNINSTALL) \
	    --verbose

rpm-prepare::
	mkdir -p $(TARGET)
	echo "set -x" > $(POST_INSTALL)
	echo "set -x" > $(PRE_UNINSTALL)
	[ -f rpm/post-install.sh ] && cat rpm/post-install.sh >> $(POST_INSTALL) || true
	echo "[ -e /usr/bin/systemctl ] && systemctl daemon-reload || true" >> $(POST_INSTALL)
	[ -f rpm/pre-uninstall.sh ] && cat rpm/pre-uninstall.sh >> $(PRE_UNINSTALL) || true

rpm-post-init:
	[ -f rpm/post-init.sh ] && cat rpm/post-init.sh >> $(POST_INSTALL) || true
