python multilib_virtclass_handler () {
    if not isinstance(e, bb.event.RecipePreFinalise):
        return

    cls = e.data.getVar("BBEXTENDCURR", True)
    variant = e.data.getVar("BBEXTENDVARIANT", True)
    if cls != "multilib" or not variant:
        return

    e.data.setVar('STAGING_KERNEL_DIR', e.data.getVar('STAGING_KERNEL_DIR', True))

    # There should only be one kernel in multilib configs
    if bb.data.inherits_class('kernel', e.data) or bb.data.inherits_class('module-base', e.data):
        raise bb.parse.SkipPackage("We shouldn't have multilib variants for the kernel")

    if bb.data.inherits_class('image', e.data):
        e.data.setVar("MLPREFIX", variant + "-")
        e.data.setVar("PN", variant + "-" + e.data.getVar("PN", False))
        return

    if bb.data.inherits_class('native', e.data):
        raise bb.parse.SkipPackage("We can't extend native recipes")

    if bb.data.inherits_class('nativesdk', e.data):
        raise bb.parse.SkipPackage("We can't extend nativesdk recipes")

    save_var_name=e.data.getVar("MULTILIB_SAVE_VARNAME", True) or ""
    for name in save_var_name.split():
        val=e.data.getVar(name, True)
        if val:
            e.data.setVar(name + "_MULTILIB_ORIGINAL", val)

    # Expand this since this won't work correctly once we set a multilib into place
    e.data.setVar("ALL_MULTILIB_PACKAGE_ARCHS", e.data.getVar("ALL_MULTILIB_PACKAGE_ARCHS", True))
 
    override = ":virtclass-multilib-" + variant

    e.data.setVar("MLPREFIX", variant + "-")
    e.data.setVar("PN", variant + "-" + e.data.getVar("PN", False))
    e.data.setVar("SHLIBSDIR_virtclass-multilib-" + variant ,e.data.getVar("SHLIBSDIR", False) + "/" + variant)
    e.data.setVar("OVERRIDES", e.data.getVar("OVERRIDES", False) + override)
}

addhandler multilib_virtclass_handler

STAGINGCC_prepend = "${BBEXTENDVARIANT}-"

python __anonymous () {
    variant = d.getVar("BBEXTENDVARIANT", True)

    import oe.classextend

    clsextend = oe.classextend.ClassExtender(variant, d)

    if bb.data.inherits_class('image', d):
        clsextend.map_depends_variable("PACKAGE_INSTALL")
        clsextend.map_depends_variable("LINGUAS_INSTALL")
        clsextend.map_depends_variable("RDEPENDS")
        pinstall = d.getVar("LINGUAS_INSTALL", True) + " " + d.getVar("PACKAGE_INSTALL", True)
        d.setVar("PACKAGE_INSTALL", pinstall)
        d.setVar("LINGUAS_INSTALL", "")
        # FIXME, we need to map this to something, not delete it!
        d.setVar("PACKAGE_INSTALL_ATTEMPTONLY", "")

    if bb.data.inherits_class('populate_sdk_base', d):
        clsextend.map_depends_variable("TOOLCHAIN_TARGET_TASK")
        clsextend.map_depends_variable("TOOLCHAIN_TARGET_TASK_ATTEMPTONLY")

    if bb.data.inherits_class('image', d) or bb.data.inherits_class('populate_sdk_base', d):
        return

    clsextend.rename_packages()
    clsextend.rename_package_variables((d.getVar("PACKAGEVARS", True) or "").split())

    clsextend.map_depends_variable("DEPENDS")
    clsextend.map_packagevars()
    clsextend.map_variable("PROVIDES")
    clsextend.map_variable("PACKAGES_DYNAMIC")
    clsextend.map_variable("PACKAGE_INSTALL")
    clsextend.map_variable("INITSCRIPT_PACKAGES")
}

PACKAGEFUNCS_append = "do_package_qa_multilib"

python do_package_qa_multilib() {

    def check_mlprefix(pkg, var, mlprefix):
        values = bb.utils.explode_deps(d.getVar('%s_%s' % (var, pkg), True) or d.getVar(var, True) or "")
        candidates = []
        for i in values:
            if i.startswith('virtual/'):
                i = i[len('virtual/'):]
            if (not i.startswith('kernel-module')) and (not i.startswith(mlprefix)):
                candidates.append(i)
        if len(candidates) > 0:
            bb.warn("Multilib QA Issue: %s package %s - suspicious values '%s' in %s" 
                   % (d.getVar('PN', True), pkg, ' '.join(candidates), var))

    ml = d.getVar('MLPREFIX', True)
    if not ml:
        return

    packages = d.getVar('PACKAGES', True)
    for pkg in packages.split():
        check_mlprefix(pkg, 'RDEPENDS', ml)
        check_mlprefix(pkg, 'RPROVIDES', ml)
        check_mlprefix(pkg, 'RRECOMMENDS', ml)
        check_mlprefix(pkg, 'RSUGGESTS', ml)
        check_mlprefix(pkg, 'RREPLACES', ml)
        check_mlprefix(pkg, 'RCONFLICTS', ml)
}

