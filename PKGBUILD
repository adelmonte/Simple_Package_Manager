pkgname=spm-arch
pkgver=1.0.0
pkgrel=1
pkgdesc="Simple Package Manager Wrapper for Arch Linux"
arch=('any')
url="https://github.com/adelmonte/Simple_Package_Manager"
license=('GPL v3.0')
depends=('bash' 'fzf' 'yay')
optdepends=('fish: for fish shell integration')
provides=('spm')
conflicts=('spm')
source=("$pkgname-$pkgver.tar.gz::$url/releases/download/v.$pkgver/spm-$pkgver.tar.gz")
sha256sums=('1babf186ec12315adec9631185cd502667c807c19ff8de7dc79184def193719c')

package() {
    cd "$srcdir"
    
    # Install main script
    install -Dm755 spm.sh "$pkgdir/usr/bin/spm"
    # Install systemd service and timer
    install -Dm644 spm_updates.timer "$pkgdir/usr/lib/systemd/system/spm_updates.timer"
    install -Dm644 spm_updates.service "$pkgdir/usr/lib/systemd/system/spm_updates.service"
    # Install Fish wrapper
    install -Dm755 spm.fish "$pkgdir/usr/share/fish/vendor_functions.d/spm.fish"
    # Install update script
    install -Dm755 spm_updates.sh "$pkgdir/usr/bin/spm_updates"
    
    # Post-install messages
    echo "To complete the setup, run the following commands as needed:"
    echo
    echo "Enable Optional Shell Sources for standalone arguments:"
    echo "↳ See 'spm --help' for more information"
    echo
    echo "1. For Bash users:"
    echo "echo 'source /usr/bin/spm' >> ~/.bashrc"
    echo
    echo "2. For Fish users:"
    echo "echo 'source /usr/share/fish/vendor_functions.d/spm.fish' >> ~/.config/fish/config.fish"
    echo
    echo "To enable (Required) available update checking:"
    echo "systemctl enable --now spm_updates.timer"
    echo
}
