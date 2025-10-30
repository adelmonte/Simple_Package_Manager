pkgname=spm-arch
pkgver=2.0
pkgrel=1
pkgdesc="Simple Package Manager FZF Wrapper for Arch Linux"
arch=('any')
url="https://github.com/adelmonte/Simple_Package_Manager"
license=('GPL-3.0-or-later')
depends=('fzf' 'yay')
provides=('spm')
conflicts=('spm')
install=spm.install

package() {
    install -Dm755 "${startdir}/spm.sh" "$pkgdir/usr/bin/spm"
    install -Dm755 "${startdir}/spm_updates.sh" "$pkgdir/usr/bin/spm_updates"
    install -Dm644 "${startdir}/spm_updates.timer" "$pkgdir/usr/lib/systemd/system/spm_updates.timer"
    install -Dm644 "${startdir}/spm_updates.service" "$pkgdir/usr/lib/systemd/system/spm_updates.service"
}