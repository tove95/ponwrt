#!/usr/bin/env python3
"""Connect autocore's Airoha temperature helper to the existing LuCI status page."""
import json
import pathlib
import re
import sys

CI_DIR = pathlib.Path(__file__).resolve().parent.parent
MAKEFILE = pathlib.Path("package/emortal/autocore/Makefile")
RPC = pathlib.Path("feeds/luci/modules/luci-base/root/usr/share/rpcd/ucode/luci")
PAGE = pathlib.Path("feeds/luci/modules/luci-mod-status/htdocs/luci-static/resources/view/status/include/10_system.js")
ACL = pathlib.Path("feeds/luci/modules/luci-mod-status/root/usr/share/rpcd/acl.d/luci-mod-status-index.json")
ZH_HANS = pathlib.Path("feeds/luci/modules/luci-base/po/zh_Hans/base.po")
MARKER = "// PonWrt-CI temperature integration."


def replace_once(text, old, new, description):
    if text.count(old) != 1:
        print(f"Notice: Upstream {description} did not match exactly once; skipping replacement")
        return text
    return text.replace(old, new, 1)


def integrate(source):
    # 1. Update autocore makefile if airoha is not yet there
    if (source / MAKEFILE).exists():
        makefile = (source / MAKEFILE).read_text()
        rule = re.search(r"\$\(filter ([^,]+), \$\(TARGETID\)\)", makefile)
        if rule and "airoha%" not in rule[1].split():
            makefile = makefile[:rule.start(1)] + "airoha% " + rule[1] + makefile[rule.end(1):]
            (source / MAKEFILE).write_text(makefile)
            print("Patched autocore Makefile with airoha%")

    # 2. Patch LuCI RPC if present
    if (source / RPC).exists():
        rpc = (source / RPC).read_text()
        if MARKER not in rpc:
            if not re.search(r"\bgetTempInfo\s*:", rpc):
                fragment_file = CI_DIR / "configs/temperature-rpc.uc"
                if not fragment_file.exists():
                    fragment_file = CI_DIR / "config/temperature-rpc.uc"
                if fragment_file.exists():
                    fragment = fragment_file.read_text()
                    rpc = replace_once(rpc, "const methods = {\n", "const methods = {\n" + fragment, "LuCI RPC methods")
                    (source / RPC).write_text(rpc)
                    print("Patched LuCI RPC getTempInfo method.")

    # 3. Patch Status page if present
    if (source / PAGE).exists():
        page = (source / PAGE).read_text()
        if MARKER not in page:
            if "getTempInfo" in page:
                native_row = ("\t\tif (tempinfo.tempinfo) {\n"
                              "\t\t\tfields.splice(6, 0, _('Temperature'));\n"
                              "\t\t\tfields.splice(7, 0, tempinfo.tempinfo);\n"
                              "\t\t}\n")
                patched_row = ("\t\t" + MARKER + "\n"
                               "\t\tfields.splice(6, 0, _('Temperature'), "
                               "tempinfo.tempinfo || _('Unavailable'));\n")
                page = replace_once(page, native_row, patched_row, "native LuCI temperature row")
                (source / PAGE).write_text(page)
                print("Patched existing LuCI temperature row.")
            else:
                declaration = """
// PonWrt-CI temperature integration.
var callGetTempInfo = rpc.declare({
    object: 'luci',
    method: 'getTempInfo',
    expect: { tempinfo: '' }
});

"""
                page = replace_once(page, "return baseclass.extend({", declaration + "return baseclass.extend({", "status include")
                page = replace_once(page, "uci.load('system')", "uci.load('system'),\n\t\t\tL.resolveDefault(callGetTempInfo(), '')", "status load")
                page = replace_once(page, "_('Kernel Version'),   boardinfo.kernel,",
                                    "_('Kernel Version'),   boardinfo.kernel,\n\t\t\t_('Temperature'),      data[5] || _('Unavailable'),",
                                    "status fields")
                (source / PAGE).write_text(page)
                print("Injected LuCI status temperature row.")

    # 4. Patch ACL
    if (source / ACL).exists():
        try:
            acl = json.loads((source / ACL).read_text())
            methods = acl.get("luci-mod-status-index", {}).get("read", {}).get("ubus", {}).get("luci", [])
            if "getTempInfo" not in methods:
                methods.append("getTempInfo")
                (source / ACL).write_text(json.dumps(acl, indent="\t") + "\n")
                print("Added getTempInfo to ACL.")
        except Exception as e:
            print(f"Notice: Failed to update ACL: {e}")

    # 5. Patch Chinese translations
    if (source / ZH_HANS).exists():
        translations = (source / ZH_HANS).read_text()
        for label, translated in [("Temperature", "温度"), ("Unavailable", "不可用")]:
            if not re.search(r'^msgid "' + label + r'"$', translations, re.MULTILINE):
                translations = translations.rstrip() + f'\n\nmsgid "{label}"\nmsgstr "{translated}"\n'
        (source / ZH_HANS).write_text(translations)
        print("Updated Chinese translations for Temperature.")


if __name__ == "__main__":
    target_dir = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else pathlib.Path(".").resolve()
    integrate(target_dir)
