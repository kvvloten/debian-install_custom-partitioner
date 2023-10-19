.PHONY: clean all directories package version_file

UDEB_NAME=custom-partitioner
UDEB_VERSION=2.0

SOURCE_DIR=src
BUILD_DIR=build
PACKAGE_DIR=${BUILD_DIR}/${UDEB_NAME}-${UDEB_VERSION}
FILES=custom-partitioner \
      debian/changelog \
      debian/compat \
      debian/control \
      debian/copyright \
      debian/custom-partitioner.install \
      debian/custom-partitioner.isinstallable \
      debian/custom-partitioner.templates \
      debian/postinst \
      debian/rules

SOURCE_FILES = $(addprefix ${SOURCE_DIR}/,${FILES})
PACKAGE_FILES = $(addprefix ${PACKAGE_DIR}/,${FILES})

${BUILD_DIR}:
	mkdir ${BUILD_DIR}

${PACKAGE_DIR}:
	mkdir ${PACKAGE_DIR}

${PACKAGE_DIR}/debian:
	mkdir ${PACKAGE_DIR}/debian

${PACKAGE_FILES}: ${SOURCE_FILES}
	echo "${PACKAGE_FILES}"
	for file in $?; do cp $${file} ${PACKAGE_DIR}/$$(echo $$file | cut -d '/' -f 2-); done

${BUILD_DIR}/${UDEB_NAME}_${UDEB_VERSION}_all.udeb: ${PACKAGE_FILES}
	cd ${PACKAGE_DIR} && dh_make -n -i -y || true
	rm ${PACKAGE_DIR}/debian/*.dirs || true
	sed -i "s/${UDEB_VERSION}-1/${UDEB_VERSION}.1/" ${PACKAGE_DIR}/debian/changelog
	cd ${PACKAGE_DIR} && dpkg-buildpackage -rfakeroot -uc -us

${PACKAGE_DIR}/custom-partitioner.version: Makefile
	echo "${UDEB_VERSION}" > ${BUILD_DIR}/custom-partitioner.version

clean:
	rm -r ${BUILD_DIR}

directories: ${BUILD_DIR} ${PACKAGE_DIR} ${PACKAGE_DIR}/debian

package: ${BUILD_DIR}/${UDEB_NAME}_${UDEB_VERSION}_all.udeb

version_file: ${PACKAGE_DIR}/custom-partitioner.version

all: directories package version_file
