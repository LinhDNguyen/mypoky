do_populate_sdk[depends] += "rpm-native:do_populate_sysroot"
do_populate_sdk[depends] += "rpmresolve-native:do_populate_sysroot"
do_populate_sdk[depends] += "createrepo-native:do_populate_sysroot"
do_populate_sdk[recrdeptask] += "do_package_write_rpm"

rpmlibdir = "/var/lib/rpm"
RPMOPTS="--dbpath ${rpmlibdir} --define='_openall_before_chroot 1'"
RPM="rpm ${RPMOPTS}"

do_populate_sdk[lockfiles] += "${DEPLOY_DIR_RPM}/rpm.lock"

populate_sdk_post_rpm () {

	local target_rootfs=$1

	# remove lock files
	rm -f ${target_rootfs}/__db.*

	# Move manifests into the directory with the logs
	mv ${target_rootfs}/install/*.manifest ${T}/

	# Remove all remaining resolver files
	rm -rf ${target_rootfs}/install
}

populate_sdk_rpm () {

	package_update_index_rpm
	package_generate_rpm_conf

	## install target ##
	# This needs to work in the same way as rootfs_rpm.bbclass!
	#
	export INSTALL_ROOTFS_RPM="${SDK_OUTPUT}/${SDKTARGETSYSROOT}"
	export INSTALL_PLATFORM_RPM="${TARGET_ARCH}"
	export INSTALL_CONFBASE_RPM="${RPMCONF_TARGET_BASE}"
	export INSTALL_PACKAGES_RPM="${TOOLCHAIN_TARGET_TASK}"
	export INSTALL_PACKAGES_ATTEMPTONLY_RPM="${TOOLCHAIN_TARGET_TASK_ATTEMPTONLY}"
	export INSTALL_PACKAGES_LINGUAS_RPM=""
	export INSTALL_PROVIDENAME_RPM="/bin/sh /bin/bash /usr/bin/env /usr/bin/perl pkgconfig pkgconfig(pkg-config)"
	export INSTALL_TASK_RPM="populate_sdk-target"
	export INSTALL_COMPLEMENTARY_RPM=""

	# Setup base system configuration
	mkdir -p ${INSTALL_ROOTFS_RPM}/etc/rpm/
	mkdir -p ${INSTALL_ROOTFS_RPM}${rpmlibdir}
	mkdir -p ${INSTALL_ROOTFS_RPM}${rpmlibdir}/log
	cat > ${INSTALL_ROOTFS_RPM}${rpmlibdir}/DB_CONFIG << EOF
# ================ Environment
set_data_dir            .
set_create_dir          .
set_lg_dir              ./log
set_tmp_dir             ./tmp

# -- thread_count must be >= 8
set_thread_count        64

# ================ Logging

# ================ Memory Pool
set_mp_mmapsize         268435456

# ================ Locking
set_lk_max_locks        16384
set_lk_max_lockers      16384
set_lk_max_objects      16384
mutex_set_max           163840

# ================ Replication
EOF

	# List must be prefered to least preferred order
	INSTALL_PLATFORM_EXTRA_RPM=""
	for each_arch in ${MULTILIB_PACKAGE_ARCHS} ${PACKAGE_ARCHS} ; do
		INSTALL_PLATFORM_EXTRA_RPM="$each_arch $INSTALL_PLATFORM_EXTRA_RPM"
	done
	export INSTALL_PLATFORM_EXTRA_RPM

	package_install_internal_rpm
	${POPULATE_SDK_POST_TARGET_COMMAND}
	populate_sdk_post_rpm ${INSTALL_ROOTFS_RPM}

	## install nativesdk ##
	echo "Installing NATIVESDK packages"
	export INSTALL_ROOTFS_RPM="${SDK_OUTPUT}"
	export INSTALL_PLATFORM_RPM="${SDK_ARCH}"
	export INSTALL_CONFBASE_RPM="${RPMCONF_HOST_BASE}"
	export INSTALL_PACKAGES_RPM="${TOOLCHAIN_HOST_TASK}"
	export INSTALL_PACKAGES_ATTEMPTONLY_RPM="${TOOLCHAIN_TARGET_HOST_ATTEMPTONLY}"
	export INSTALL_PACKAGES_LINGUAS_RPM=""
	export INSTALL_PROVIDENAME_RPM="/bin/sh /bin/bash /usr/bin/env /usr/bin/perl pkgconfig libGL.so()(64bit) libGL.so"
	export INSTALL_TASK_RPM="populate_sdk_rpm-nativesdk"
	export INSTALL_COMPLEMENTARY_RPM=""

	# List must be prefered to least preferred order
	INSTALL_PLATFORM_EXTRA_RPM=""
	for each_arch in ${SDK_PACKAGE_ARCHS} ; do
		INSTALL_PLATFORM_EXTRA_RPM="$each_arch $INSTALL_PLATFORM_EXTRA_RPM"
	done
	export INSTALL_PLATFORM_EXTRA_RPM

	package_install_internal_rpm
	populate_sdk_post_rpm ${INSTALL_ROOTFS_RPM}

	# move host RPM library data
	install -d ${SDK_OUTPUT}/${SDKPATHNATIVE}${localstatedir_nativesdk}/lib/rpm
	mv ${SDK_OUTPUT}${rpmlibdir}/* ${SDK_OUTPUT}/${SDKPATHNATIVE}${localstatedir_nativesdk}/lib/rpm/
	rm -Rf ${SDK_OUTPUT}/var

	install -d ${SDK_OUTPUT}/${SDKPATHNATIVE}/${sysconfdir}
	mv ${SDK_OUTPUT}/etc/* ${SDK_OUTPUT}/${SDKPATHNATIVE}/${sysconfdir}/
	rm -rf ${SDK_OUTPUT}/etc

	populate_sdk_log_check populate_sdk

	# Workaround so the parser knows we need the resolve_package function!
	if false ; then
		resolve_package_rpm foo ${RPMCONF_TARGET_BASE}.conf || true
	fi
}

python () {
    # The following code should be kept in sync w/ the rootfs_rpm version.
    ml_package_archs = ""
    ml_prefix_list = ""
    multilibs = d.getVar('MULTILIBS', True) or ""
    for ext in multilibs.split():
        eext = ext.split(':')
        if len(eext) > 1 and eext[0] == 'multilib':
            localdata = bb.data.createCopy(d)
            default_tune = localdata.getVar("DEFAULTTUNE_virtclass-multilib-" + eext[1], False)
            if default_tune:
                localdata.setVar("DEFAULTTUNE", default_tune)
            package_archs = localdata.getVar("PACKAGE_ARCHS", True) or ""
            package_archs = " ".join([i in "all noarch any".split() and i or eext[1]+"_"+i for i in package_archs.split()])
            ml_package_archs += " " + package_archs
            ml_prefix_list += " " + eext[1]
            #bb.note("ML_PACKAGE_ARCHS %s %s %s" % (eext[1], localdata.getVar("PACKAGE_ARCHS", True) or "(none)", overrides))
    d.setVar('MULTILIB_PACKAGE_ARCHS', ml_package_archs)
    d.setVar('MULTILIB_PREFIX_LIST', ml_prefix_list)
}

