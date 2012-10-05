# Version 5 of the Berkeley DB from Sleepycat
#
# At present this package only installs the DB code
# itself (shared libraries, .a in the dev package),
# documentation and headers.
#
# The headers have the same names as those as v3
# of the DB, only one version can be used *for dev*
# at once - DB3 and DB5 can both be installed on the
# same system at the same time if really necessary.
SECTION = "libs"
DESCRIPTION = "Berkeley DB v5."
HOMEPAGE = "http://www.oracle.com/technology/products/berkeley-db/db/index.html"
LICENSE = "Sleepycat"
VIRTUAL_NAME ?= "virtual/db"
RCONFLICTS_${PN} = "db3"
PR = "r8"

SRC_URI = "http://download.oracle.com/berkeley-db/db-${PV}.tar.gz"
SRC_URI += "file://arm-thumb-mutex_db5.patch;patchdir=.."

SRC_URI[md5sum] = "5493fb5f7cc3915887c836b096f18773"
SRC_URI[sha256sum] = "4f4f7d548984dde3584fcda0e4f96901cb8bafb08033a7781aec64ef2ea1f579"

LIC_FILES_CHKSUM = "file://../LICENSE;md5=12cc3ff983ed4ecc6cc091370ee4dbc3"

inherit autotools

# Put virtual/db in any appropriate provider of a
# relational database, use it as a dependency in
# place of a specific db and use:
#
# PREFERRED_PROVIDER_virtual/db
#
# to select the correct db in the build (distro) .conf
PROVIDES += "${VIRTUAL_NAME}"

# bitbake isn't quite clever enough to deal with sleepycat,
# the distribution sits in the expected directory, but all
# the builds must occur from a sub-directory.  The following
# persuades bitbake to go to the right place
S = "${WORKDIR}/db-${PV}/dist"
B = "${WORKDIR}/db-${PV}/build_unix"

# The executables go in a separate package - typically there
# is no need to install these unless doing real database
# management on the system.
inherit lib_package

# The dev package has the .so link (as in db3) and the .a's -
# it is therefore incompatible (cannot be installed at the
# same time) as the db3 package
# sort out the .so since they do version prior to the .so
SOLIBS = "-5*.so"
FILES_SOLIBSDEV = "${libdir}/libdb.so"

#configuration - set in local.conf to override
# All the --disable-* options replace --enable-smallbuild, which breaks a bunch of stuff (eg. postfix)
DB5_CONFIG ?= "--enable-o_direct --disable-cryptography --disable-queue --disable-replication --disable-verify --disable-compat185 --disable-sql"

EXTRA_OECONF = "${DB5_CONFIG}"

# Override the MUTEX setting here, the POSIX library is
# the default - "POSIX/pthreads/library".
# Don't ignore the nice SWP instruction on the ARM:
# These enable the ARM assembler mutex code, this won't
# work with thumb compilation...
ARM_MUTEX = "--with-mutex=ARM/gcc-assembly"
MUTEX = ""
MUTEX_arm = "${ARM_MUTEX}"
MUTEX_armeb = "${ARM_MUTEX}"
EXTRA_OECONF += "${MUTEX}"

# Cancel the site stuff - it's set for db3 and destroys the
# configure.
CONFIG_SITE = ""
do_configure() {
	export STRIP="true"
	oe_runconf
}

do_install_append() {
	mkdir -p ${D}/${includedir}/db51
	#mv ${D}/${includedir}/db_185.h ${D}/${includedir}/db51/.
	mv ${D}/${includedir}/db.h ${D}/${includedir}/db51/.
	mv ${D}/${includedir}/db_cxx.h ${D}/${includedir}/db51/.
	#mv ${D}/${includedir}/dbsql.h ${D}/${includedir}/db51/.
	#ln -s db51/db_185.h ${D}/${includedir}/db_185.h
	ln -s db51/db.h ${D}/${includedir}/db.h
	ln -s db51/db_cxx.h ${D}/${includedir}/db_cxx.h
	#ln -s db51/dbsql.h ${D}/${includedir}/dbsql.h

	# The docs end up in /usr/docs - not right.
	if test -d "${D}/${prefix}/docs"
	then
		mkdir -p "${D}/${datadir}"
		test ! -d "${D}/${docdir}" || rm -rf "${D}/${docdir}"
		mv "${D}/${prefix}/docs" "${D}/${docdir}"
	fi

	chown -R root:root ${D}
}

INSANE_SKIP_${PN} = "dev-so"

BBCLASSEXTEND = "native nativesdk"

