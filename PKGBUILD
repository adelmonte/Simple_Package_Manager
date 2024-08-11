# Maintainer: adelmonte <https://github.com/adelmonte>
pkgname=spm
pkgver=1.0.0
pkgrel=1
pkgdesc="Simple Package Manager Wrapper for Arch Linux"
arch=('any')
url="https://github.com/adelmonte/Simple_Package_Manager"
license=('GPL v3.0')
depends=('bash' 'fzf' 'yay')
optdepends=('fish: for fish shell integration')
source=(
    "spm.sh"
    "spm_updates.timer"
    "spm_updates.service"
    "spm.fish"
    "spm_updates.sh"
)
sha256sums=('SKIP' 'SKIP' 'SKIP' 'SKIP' 'SKIP')
install=spm.install

package() {
    # Install main script
    install -Dm755 "$srcdir/spm.sh" "$pkgdir/usr/bin/spm"
    
    # Install systemd service and timer
    install -Dm644 "$srcdir/spm_updates.timer" "$pkgdir/usr/lib/systemd/system/spm_updates.timer"
    install -Dm644 "$srcdir/spm_updates.service" "$pkgdir/usr/lib/systemd/system/spm_updates.service"
    
    # Install Fish wrapper
    install -Dm755 "$srcdir/spm.fish" "$pkgdir/usr/share/fish/vendor_functions.d/spm.fish"
    
    # Install update script
    install -Dm755 "$srcdir/spm_updates.sh" "$pkgdir/usr/bin/spm_updates"
}
