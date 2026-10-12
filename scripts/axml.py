#!/usr/bin/env python3
"""Minimal Android binary XML (AXML) parser.

Extracts, from an APK's AndroidManifest.xml: the package name, versionName,
versionCode, minSdkVersion and the list of <uses-permission> names.
No external dependencies.
"""
import sys, struct, zipfile


def parse_string_pool(data, off):
    typ, hsz, size = struct.unpack_from('<HHI', data, off)
    assert typ == 0x0001, "not a string pool"
    scount, stcount, flags, sstart, tstart = struct.unpack_from('<IIIII', data, off + 8)
    utf8 = (flags & (1 << 8)) != 0
    offs = struct.unpack_from('<%dI' % scount, data, off + 28)
    base = off + sstart
    out = []
    for o in offs:
        p = base + o
        if utf8:
            n = struct.unpack_from('<H', data, p)[0]
            out.append(data[p + 3:p + 3 + n].decode('utf-8', 'replace'))
        else:
            n = struct.unpack_from('<H', data, p)[0]
            out.append(data[p + 2:p + 2 + n * 2].decode('utf-16-le', 'replace'))
    return out, off + size


def parse_axml(data):
    typ, hsz, size = struct.unpack_from('<HHI', data, 0)
    assert typ == 0x0003, "not AXML"
    off = hsz
    strings = []
    while off < len(data):
        ctyp, chsz, csize = struct.unpack_from('<HHI', data, off)
        if csize == 0:
            break
        if ctyp == 0x0001:
            strings, _ = parse_string_pool(data, off)
        elif ctyp == 0x0102:  # start element
            _ln, _cm, ns, name = struct.unpack_from('<IIII', data, off + 8)
            attr_start, attr_size, attr_count = struct.unpack_from('<HHH', data, off + 24)
            abase = off + 16 + attr_start
            attrs = {}
            for i in range(attr_count):
                aoff = abase + i * attr_size
                ans, aname, araw = struct.unpack_from('<III', data, aoff)
                dsize, res0, dtype, ddata = struct.unpack_from('<HBBI', data, aoff + 12)
                an = strings[aname] if aname < len(strings) else None
                if dtype == 0x03:
                    av = strings[ddata] if ddata < len(strings) else None
                elif dtype == 0x12:
                    av = bool(ddata)
                else:
                    av = ddata
                if an:
                    attrs[an] = av
            ename = strings[name] if name < len(strings) else None
            yield ename, attrs
        off += csize


def apk_info(path):
    """Return dict(package, versionName, versionCode, minSdk, targetSdk, permissions)."""
    with zipfile.ZipFile(path) as z:
        data = z.read('AndroidManifest.xml')
    info = dict(package=None, versionName=None, versionCode=None,
                minSdk=None, targetSdk=None, permissions=[])
    perms = []
    for ename, attrs in parse_axml(data):
        if ename == 'manifest':
            info['package'] = attrs.get('package')
            info['versionName'] = attrs.get('versionName')
            info['versionCode'] = attrs.get('versionCode')
            info['targetSdk'] = attrs.get('targetSdkVersion')
        elif ename == 'uses-sdk':
            info['minSdk'] = attrs.get('minSdkVersion')
        elif ename in ('uses-permission', 'uses-permission-sdk-23'):
            p = attrs.get('name')
            if p:
                perms.append(p)
    info['permissions'] = sorted(set(perms))
    return info


if __name__ == '__main__':
    for a in sys.argv[1:]:
        i = apk_info(a)
        print(f"{a}\n  package={i['package']} versionName={i['versionName']} "
              f"versionCode={i['versionCode']} minSdk={i['minSdk']}")
        for p in i['permissions']:
            print("   ", p)
