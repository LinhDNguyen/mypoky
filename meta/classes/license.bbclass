# Populates LICENSE_DIRECTORY as set in distro config with the license files as set by
# LIC_FILES_CHKSUM.
# TODO:
# - There is a real issue revolving around license naming standards.

LICENSE_DIRECTORY ??= "${DEPLOY_DIR}/licenses"
LICSSTATEDIR = "${WORKDIR}/license-destdir/"

addtask populate_lic after do_patch before do_package
do_populate_lic[dirs] = "${LICSSTATEDIR}/${PN}"
do_populate_lic[cleandirs] = "${LICSSTATEDIR}"

license_create_manifest() {
	mkdir -p ${LICENSE_DIRECTORY}/${IMAGE_NAME}
	# Get list of installed packages
	list_installed_packages | grep -v "locale" |sort > ${LICENSE_DIRECTORY}/${IMAGE_NAME}/package.manifest
	INSTALLED_PKGS=`cat ${LICENSE_DIRECTORY}/${IMAGE_NAME}/package.manifest`
	LICENSE_MANIFEST="${LICENSE_DIRECTORY}/${IMAGE_NAME}/license.manifest"
	# remove existing license.manifest file
	if [ -f ${LICENSE_MANIFEST} ]; then
		rm ${LICENSE_MANIFEST}
	fi
	# list of installed packages is broken for deb
	for pkg in ${INSTALLED_PKGS}; do
		# not the best way to do this but licenses are not arch dependant iirc
		filename=`ls ${TMPDIR}/pkgdata/*/runtime-reverse/${pkg}| head -1`
		pkged_pn="$(sed -n 's/^PN: //p' ${filename})"

		# exclude locale recipes
		if [ "${pkged_pn}" = "*locale*" ]; then
			continue
		fi

		# check to see if the package name exists in the manifest. if so, bail.
		if grep -q "^PACKAGE NAME: ${pkg}" ${LICENSE_MANIFEST}; then
			continue
		fi

		pkged_pv="$(sed -n 's/^PV: //p' ${filename})"
		pkged_name="$(basename $(readlink ${filename}))"
		pkged_lic="$(sed -n "/^LICENSE_${pkged_name}: /{ s/^LICENSE_${pkged_name}: //; s/[|&()*]/ /g; s/  */ /g; p }" ${filename})"
		if [ -z ${pkged_lic} ]; then
			# fallback checking value of LICENSE
			pkged_lic="$(sed -n "/^LICENSE: /{ s/^LICENSE: //; s/[|&()*]/ /g; s/  */ /g; p }" ${filename})"
		fi

		echo "PACKAGE NAME:" ${pkg} >> ${LICENSE_MANIFEST}
		echo "PACKAGE VERSION:" ${pkged_pv} >> ${LICENSE_MANIFEST}
		echo "RECIPE NAME:" ${pkged_pn} >> ${LICENSE_MANIFEST}
		printf "LICENSE:" >> ${LICENSE_MANIFEST}
		for lic in ${pkged_lic}; do
			# to reference a license file trim trailing + symbol
			if [ -e "${LICENSE_DIRECTORY}/${pkged_pn}/generic_${lic%+}" ]; then
				printf " ${lic}" >> ${LICENSE_MANIFEST}
			else
				echo "WARNING: The license listed ${lic} was not in the licenses collected for ${pkged_pn}"
			fi
		done
		printf "\n\n" >> ${LICENSE_MANIFEST}
	done

	# Two options here:
	# - Just copy the manifest
	# - Copy the manifest and the license directories
	# With both options set we see a .5 M increase in core-image-minimal
	if [ -n "${COPY_LIC_MANIFEST}" ]; then
		mkdir -p ${IMAGE_ROOTFS}/usr/share/common-licenses/
		cp ${LICENSE_MANIFEST} ${IMAGE_ROOTFS}/usr/share/common-licenses/license.manifest
		if [ -n "${COPY_LIC_DIRS}" ]; then
			for pkg in ${INSTALLED_PKGS}; do
				mkdir -p ${IMAGE_ROOTFS}/usr/share/common-licenses/${pkg}
				for lic in `ls ${LICENSE_DIRECTORY}/${pkg}`; do
					# Really don't need to copy the generics as they're 
					# represented in the manifest and in the actual pkg licenses
					# Doing so would make your image quite a bit larger
					if [[ "${lic}" != "generic_"* ]]; then
						cp ${LICENSE_DIRECTORY}/${pkg}/${lic} ${IMAGE_ROOTFS}/usr/share/common-licenses/${pkg}/${lic}
					elif [[ "${lic}" == "generic_"* ]]; then
						if [ ! -f ${IMAGE_ROOTFS}/usr/share/common-licenses/${lic} ]; then
							cp ${LICENSE_DIRECTORY}/${pkg}/${lic} ${IMAGE_ROOTFS}/usr/share/common-licenses/
						fi
						ln -s ../${lic} ${IMAGE_ROOTFS}/usr/share/common-licenses/${pkg}/${lic}
					fi
				done
			done
		fi
	fi

}

python do_populate_lic() {
    """
    Populate LICENSE_DIRECTORY with licenses.
    """
    import shutil
    import oe.license

    pn = d.getVar('PN', True)
    for package in d.getVar('PACKAGES', True):
        if d.getVar('LICENSE_' + pn + '-' + package, True):
            license_types = license_types + ' & ' + \
                            d.getVar('LICENSE_' + pn + '-' + package, True)

    #If we get here with no license types, then that means we have a recipe 
    #level license. If so, we grab only those.
    try:
        license_types
    except NameError:        
        # All the license types at the recipe level
        license_types = d.getVar('LICENSE', True)
 
    # All the license files for the package
    lic_files = d.getVar('LIC_FILES_CHKSUM', True)
    pn = d.getVar('PN', True)
    # The base directory we wrangle licenses to
    destdir = os.path.join(d.getVar('LICSSTATEDIR', True), pn)
    # The license files are located in S/LIC_FILE_CHECKSUM.
    srcdir = d.getVar('S', True)
    # Directory we store the generic licenses as set in the distro configuration
    generic_directory = d.getVar('COMMON_LICENSE_DIR', True)
    license_source_dirs = []
    license_source_dirs.append(generic_directory)
    try:
        additional_lic_dirs = d.getVar('LICENSE_PATH', True).split()
        for lic_dir in additional_lic_dirs:
            license_source_dirs.append(lic_dir)
    except:
        pass

    class FindVisitor(oe.license.LicenseVisitor):
        def visit_Str(self, node):
            #
            # Until I figure out what to do with
            # the two modifiers I support (or greater = +
            # and "with exceptions" being *
            # we'll just strip out the modifier and put
            # the base license.
            find_license(node.s.replace("+", "").replace("*", ""))
            self.generic_visit(node)

    def find_license(license_type):
        try:
            bb.mkdirhier(gen_lic_dest)
        except:
            pass
        spdx_generic = None
        license_source = None
        # If the generic does not exist we need to check to see if there is an SPDX mapping to it
        for lic_dir in license_source_dirs:
            if not os.path.isfile(os.path.join(lic_dir, license_type)):
                if d.getVarFlag('SPDXLICENSEMAP', license_type) != None:
                    # Great, there is an SPDXLICENSEMAP. We can copy!
                    bb.debug(1, "We need to use a SPDXLICENSEMAP for %s" % (license_type))
                    spdx_generic = d.getVarFlag('SPDXLICENSEMAP', license_type)
                    license_source = lic_dir
                    break
            elif os.path.isfile(os.path.join(lic_dir, license_type)):
                spdx_generic = license_type
                license_source = lic_dir
                break

        if spdx_generic and license_source:
            # we really should copy to generic_ + spdx_generic, however, that ends up messing the manifest
            # audit up. This should be fixed in emit_pkgdata (or, we actually got and fix all the recipes)

            bb.copyfile(os.path.join(license_source, spdx_generic), os.path.join(os.path.join(d.getVar('LICSSTATEDIR', True), pn), "generic_" + license_type))
            if not os.path.isfile(os.path.join(os.path.join(d.getVar('LICSSTATEDIR', True), pn), "generic_" + license_type)):
            # If the copy didn't occur, something horrible went wrong and we fail out
                bb.warn("%s for %s could not be copied for some reason. It may not exist. WARN for now." % (spdx_generic, pn))
        else:
            # And here is where we warn people that their licenses are lousy
            bb.warn("%s: No generic license file exists for: %s in any provider" % (pn, license_type))
            pass

    try:
        bb.mkdirhier(destdir)
    except:
        pass

    if not generic_directory:
        raise bb.build.FuncFailed("COMMON_LICENSE_DIR is unset. Please set this in your distro config")

    if not lic_files:
        # No recipe should have an invalid license file. This is checked else
        # where, but let's be pedantic
        bb.note(pn + ": Recipe file does not have license file information.")
        return True

    for url in lic_files.split():
        (type, host, path, user, pswd, parm) = bb.decodeurl(url)
        # We want the license file to be copied into the destination
        srclicfile = os.path.join(srcdir, path)
        ret = bb.copyfile(srclicfile, os.path.join(destdir, os.path.basename(path)))
        # If the copy didn't occur, something horrible went wrong and we fail out
        if not ret:
            bb.warn("%s could not be copied for some reason. It may not exist. WARN for now." % srclicfile)

    v = FindVisitor()
    try:
        v.visit_string(license_types)
    except oe.license.InvalidLicense as exc:
        bb.fatal('%s: %s' % (d.getVar('PF', True), exc))
    except SyntaxError:
        bb.warn("%s: Failed to parse it's LICENSE field." % (d.getVar('PF', True)))

}

def return_spdx(d, license):
    """
    This function returns the spdx mapping of a license.
    """
    if d.getVarFlag('SPDXLICENSEMAP', license) != None:
        return license
    else:
        return d.getVarFlag('SPDXLICENSEMAP', license_type)

def incompatible_license(d, dont_want_license, package=""):
    """
    This function checks if a recipe has only incompatible licenses. It also take into consideration 'or'
    operand.
    """
    import re
    import oe.license
    from fnmatch import fnmatchcase as fnmatch
    pn = d.getVar('PN', True)
    dont_want_licenses = []
    dont_want_licenses.append(d.getVar('INCOMPATIBLE_LICENSE', True))
    recipe_license = d.getVar('LICENSE', True)
    if package != "":
        if d.getVar('LICENSE_' + pn + '-' + package, True):
            license = d.getVar('LICENSE_' + pn + '-' + package, True)
        else:
            license = recipe_license
    else:
        license = recipe_license
    spdx_license = return_spdx(d, dont_want_license)
    dont_want_licenses.append(spdx_license)

    def include_license(license):
        if any(fnmatch(license, pattern) for pattern in dont_want_licenses):
            return False
        else:
            return True

    def choose_licenses(a, b):
        if all(include_license(lic) for lic in a):
            return a
        else:
            return b

    """
    If you want to exlude license named generically 'X', we surely want to exlude 'X+' as well.
    In consequence, we will exclude the '+' character from LICENSE in case INCOMPATIBLE_LICENSE
    is not a 'X+' license.
    """
    if not re.search(r'[+]',dont_want_license):
        licenses=oe.license.flattened_licenses(re.sub(r'[+]', '', license), choose_licenses)
    else:
        licenses=oe.license.flattened_licenses(license, choose_licenses)

    for onelicense in licenses:
        if not include_license(onelicense):
            return True
    return False

def check_license_flags(d):
    """
    This function checks if a recipe has any LICENSE_FLAGs that
    aren't whitelisted.

    If it does, it returns the first LICENSE_FLAG missing from the
    whitelist, or all the LICENSE_FLAGs if there is no whitelist.

    If everything is is properly whitelisted, it returns None.
    """

    def license_flag_matches(flag, whitelist, pn):
        """
        Return True if flag matches something in whitelist, None if not.

        Before we test a flag against the whitelist, we append _${PN}
        to it.  We then try to match that string against the
        whitelist.  This covers the normal case, where we expect
        LICENSE_FLAGS to be a simple string like 'commercial', which
        the user typically matches exactly in the whitelist by
        explicitly appending the package name e.g 'commercial_foo'.
        If we fail the match however, we then split the flag across
        '_' and append each fragment and test until we either match or
        run out of fragments.
        """
        flag_pn = ("%s_%s" % (flag, pn))
        for candidate in whitelist:
            if flag_pn == candidate:
                    return True

        flag_cur = ""
        flagments = flag_pn.split("_")
        flagments.pop() # we've already tested the full string
        for flagment in flagments:
            if flag_cur:
                flag_cur += "_"
            flag_cur += flagment
            for candidate in whitelist:
                if flag_cur == candidate:
                    return True
        return False

    def all_license_flags_match(license_flags, whitelist):
        """ Return first unmatched flag, None if all flags match """
        pn = d.getVar('PN', True)
        split_whitelist = whitelist.split()
        for flag in license_flags.split():
            if not license_flag_matches(flag, split_whitelist, pn):
                return flag
        return None

    license_flags = d.getVar('LICENSE_FLAGS', True)
    if license_flags:
        whitelist = d.getVar('LICENSE_FLAGS_WHITELIST', True)
        if not whitelist:
            return license_flags
        unmatched_flag = all_license_flags_match(license_flags, whitelist)
        if unmatched_flag:
            return unmatched_flag
    return None

SSTATETASKS += "do_populate_lic"
do_populate_lic[sstate-name] = "populate-lic"
do_populate_lic[sstate-inputdirs] = "${LICSSTATEDIR}"
do_populate_lic[sstate-outputdirs] = "${LICENSE_DIRECTORY}/"

ROOTFS_POSTPROCESS_COMMAND_prepend = "license_create_manifest; "

python do_populate_lic_setscene () {
    sstate_setscene(d)
}
addtask do_populate_lic_setscene
