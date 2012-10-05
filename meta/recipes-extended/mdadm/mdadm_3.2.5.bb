DESCRIPTION = " A tool for managing Soft RAID under Linux"
HOMEPAGE = "http://www.kernel.org/pub/linux/utils/raid/mdadm/"
BUGTRACKER = "n/a"

# Some files are GPLv2+ while others are GPLv2.
LICENSE = "GPLv2 & GPLv2+"
LIC_FILES_CHKSUM = "file://COPYING;md5=b234ee4d69f5fce4486a80fdaf4a4263 \
                    file://mdmon.c;beginline=4;endline=18;md5=af7d8444d9c4d3e5c7caac0d9d34039d \
                    file://mdadm.h;beglinlne=4;endline=22;md5=462bc9936ac0d3da110191a3f9994161"

PR = "r1"

SRC_URI = "${KERNELORG_MIRROR}/linux/utils/raid/mdadm/${BPN}-${PV}.tar.bz2 \
	    file://mdadm-3.2.2_fix_for_x32.patch \
	  "

SRC_URI[md5sum] = "83ba4a6249ae24677e915e44c9cfcc58"
SRC_URI[sha256sum] = "5ae2bfd241c88601c1ef9072806248491e025fa09a388c40230d72d65eabbd3c"

CFLAGS += "-fno-strict-aliasing"

inherit autotools

# We don't DEPEND on binutils for ansidecl.h so ensure we don't use the header
do_configure_prepend () {
	sed -i -e '/.*ansidecl.h.*/d' ${S}/sha1.h
}

do_compile() {
	oe_runmake
}

do_install() {
	export STRIP=""
	autotools_do_install
}

FILES_${PN} += "${base_libdir}/udev/rules.d/*.rules"
