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
sha256sums=('5af8640d1e2fb4b01d59bcd6ca64016399b56683f96aa9c183084b8f1dde02dc'
            'fdeff443991cf36b8426794bb204f498762b004868df2e9d52b80b92964dfaa2'
            '738e1cbff9cb62526a560976fbb6eba494de0e43f2a946dbaa8aa65ec6123892'
            'dcc2b2f4ec8af1a0549af7031201eb9151711fc3b98807221e2422d8ae97ac05'
            'ed4a96d6b9cb236b537794172cdb4672728ba88a3d8a0b481be64e169f024c28')
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
