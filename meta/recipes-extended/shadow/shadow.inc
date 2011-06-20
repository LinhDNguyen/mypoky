DESCRIPTION = "Tools to change and administer password and group data."
HOMEPAGE = "http://pkg-shadow.alioth.debian.org/"
BUGTRACKER = "https://alioth.debian.org/tracker/?group_id=30580"
SECTION = "base utils"
LICENSE = "BSD | Artistic"
LIC_FILES_CHKSUM = "file://COPYING;md5=08c553a87d4e51bbed50b20e0adcaede \
                    file://src/passwd.c;firstline=8;endline=30;md5=2899a045e90511d0e043b85a7db7e2fe"

PAM_PLUGINS = "  libpam-runtime \
                 pam-plugin-faildelay \
                 pam-plugin-securetty \
                 pam-plugin-nologin \
                 pam-plugin-env \
                 pam-plugin-group \
                 pam-plugin-limits \
                 pam-plugin-lastlog \
                 pam-plugin-motd \
                 pam-plugin-mail \
                 pam-plugin-shells \
                 pam-plugin-rootok"
                 
DEPENDS = "${@base_contains('DISTRO_FEATURES', 'pam', 'libpam', '', d)}"
RDEPENDS_${PN} = "${@base_contains('DISTRO_FEATURES', 'pam', '${PAM_PLUGINS}', '', d)}"

# since we deduce from ${SERIAL_CONSOLE}
PACKAGE_ARCH = "${MACHINE_ARCH}"

# Additional Policy files for PAM
PAM_SRC_URI = "file://pam.d/chfn \
               file://pam.d/chpasswd \
               file://pam.d/chsh \
               file://pam.d/login \
               file://pam.d/newusers \
               file://pam.d/passwd \
               file://pam.d/su"

SRC_URI = "ftp://pkg-shadow.alioth.debian.org/pub/pkg-shadow/shadow-${PV}.tar.bz2 \
           file://login_defs_pam.sed \
           ${@base_contains('DISTRO_FEATURES', 'pam', '${PAM_SRC_URI}', '', d)} \
           file://securetty"

inherit autotools gettext

EXTRA_OECONF += "--without-audit \
                 --without-libcrack \
                 ${@base_contains('DISTRO_FEATURES', 'pam', '--with-libpam', '--without-libpam', d)} \
                 --without-selinux"

do_install_append() {
	# Ensure that the image has as /var/spool/mail dir so shadow can put mailboxes there if the user
	# reconfigures Shadow to default (see sed below).
	install -d ${D}${localstatedir}/spool/mail

	if [ -e ${WORKDIR}/pam.d ]; then
		install -d ${D}${sysconfdir}/pam.d/
		install -m 0644 ${WORKDIR}/pam.d/* ${D}${sysconfdir}/pam.d/
		# Remove defaults that are not used when supporting PAM
		sed -i -f ${WORKDIR}/login_defs_pam.sed ${D}${sysconfdir}/login.defs
	fi

	# Enable CREATE_HOME by default.
	sed -i 's/#CREATE_HOME/CREATE_HOME/g' ${D}${sysconfdir}/login.defs

	# As we are on an embedded system ensure the users mailbox is in ~/ not
	# /var/spool/mail by default as who knows where or how big /var is.
	# The system MDA will set this later anyway.
	sed -i 's/MAIL_DIR/#MAIL_DIR/g' ${D}${sysconfdir}/login.defs
	sed -i 's/#MAIL_FILE/MAIL_FILE/g' ${D}${sysconfdir}/login.defs

	# disable checking emails at all
	sed -i 's/MAIL_CHECK_ENAB/#MAIL_CHECK_ENAB/g' ${D}${sysconfdir}/login.defs

	# now we don't have a mail system. disable mail creation for now
	sed -i 's:/bin/bash:/bin/sh:g' ${D}${sysconfdir}/default/useradd
	sed -i '/^CREATE_MAIL_SPOOL/ s:^:#:' ${D}${sysconfdir}/default/useradd

	install -d ${D}${sbindir} ${D}${base_sbindir} ${D}${base_bindir} 
	for i in passwd chfn newgrp chsh ; do
		mv ${D}${bindir}/$i ${D}${bindir}/$i.${PN}
	done

	mv ${D}${sbindir}/chpasswd ${D}${sbindir}/chpasswd.${PN}
	mv ${D}${sbindir}/vigr ${D}${base_sbindir}/vigr.${PN}
	mv ${D}${sbindir}/vipw ${D}${base_sbindir}/vipw.${PN}
	mv ${D}${bindir}/login ${D}${base_bindir}/login.${PN}

	# Ensure we add a suitable securetty file to the package that has most common embedded TTYs defined.
	if [ ! -z "${SERIAL_CONSOLE}" ]; then
	# our SERIAL_CONSOLE contains baud rate too and sometime -L option as well.
	# the following pearl :) takes that and converts it into newline sepated tty's and appends
	# them into securetty. So if a machine has a weird looking console device node (e.g. ttyAMA0) that securetty
	# does not know then it will get appended to securetty and root login will be allowed on
	# that console.
		echo "${SERIAL_CONSOLE}" | sed -e 's/[0-9][0-9]\|\-L//g'|tr "[ ]" "[\n]"  >> ${WORKDIR}/securetty
	fi
	install -m 0400 ${WORKDIR}/securetty ${D}${sysconfdir}/securetty 
}

pkg_postinst_${PN} () {
	update-alternatives --install ${bindir}/passwd passwd passwd.${PN} 200
	update-alternatives --install ${sbindir}/chpasswd chpasswd chpasswd.${PN} 200
	update-alternatives --install ${bindir}/chfn chfn chfn.${PN} 200
	update-alternatives --install ${bindir}/newgrp newgrp newgrp.${PN} 200
	update-alternatives --install ${bindir}/chsh chsh chsh.${PN} 200
	update-alternatives --install ${base_bindir}/login login login.${PN} 200
	update-alternatives --install ${base_sbindir}/vipw vipw vipw.${PN} 200
	update-alternatives --install ${base_sbindir}/vigr vigr vigr.${PN} 200

	if [ "x$D" != "x" ]; then
		exit 1
	fi  

	pwconv
	grpconv
}

pkg_prerm_${PN} () {
	for i in passwd chpasswd chfn newgrp chsh login vipw vigr ; do
		update-alternatives --remove $i $i.${PN}
	done
}