#!/usr/bin/python3
# Спецификация ALT плюс наши патчи: mkspec-altmobile.py ALT.spec ВЫХОД.spec ВЫПУСК "запись" патч...
# Патчи становятся Source900, Source901... и накладываются в конце %prep:
# они сделаны на дереве после всего %prep ALT (rpmbuild -bp), а %autopatch
# у некоторых пакетов (kwin) иначе наложил бы их раньше времени.
import re, sys, time

src, out, release, note, *patches = sys.argv[1:]
s = open(src).read()

s, n = re.subn(r'^Release:\s*\S+', 'Release: ' + release, s, count=1, flags=re.M)
assert n == 1, 'нет Release'

# Источники после последней строки Source/Patch шапки
lines = s.split('\n')
last = max(i for i, l in enumerate(lines) if re.match(r'(Source|Patch)\d*:', l))
add = ['# ALT Mobile, OnePlus 6T (oneplus6t repository, packages/)']
add += ['Source%d: %s' % (900 + i, p) for i, p in enumerate(patches)]
lines[last + 1:last + 1] = add
s = '\n'.join(lines)

# Наложение в конце %prep, перед следующей секцией
m = re.search(r'^%prep\b.*?(?=^%(build|install|check)\b)', s, flags=re.M | re.S)
assert m, 'нет %prep'
apply = '# ALT Mobile patches, after the whole ALT %prep\n'
apply += ''.join('patch -p1 -s < %%SOURCE%d\n' % (900 + i) for i in range(len(patches)))
prep = m.group(0).rstrip('\n') + '\n\n' + apply + '\n'
s = s[:m.start()] + prep + s[m.end():]

# Запись в %changelog
ver = re.search(r'^Version:\s*(\S+)', s, flags=re.M).group(1)
epoch = re.search(r'^Epoch:\s*(\S+)', s, flags=re.M)
evr = (epoch.group(1) + ':' if epoch else '') + ver + '-' + release
date = time.strftime('%a %b %d %Y', time.gmtime())
entry = '* %s morgonf <morgonf@altlinux.org> %s\n' % (date, evr)
entry += ''.join('- %s\n' % l for l in note.split('\n')) + '\n'
s = s.replace('%changelog\n', '%changelog\n' + entry, 1)

open(out, 'w').write(s)
