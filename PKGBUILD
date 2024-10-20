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
# sha256sums=('c8e4dca92f68309f62316214192ac36b253edb8c468eadd80e41657b35905d66' 
#            'fdeff443991cf36b8426794bb204f498762b004868df2e9d52b80b92964dfaa2' 
#            '372c7c41a5459c04998b3afa30c43eff19689febbe90db59eac3d836843f56e8' 
#            'dcc2b2f4ec8af1a0549af7031201eb9151711fc3b98807221e2422d8ae97ac05' 
#            'ad3e80c505af1c2eaf659bcede6b2803ced3c4fd137c3d2f892e3caf445249ee')

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

    # Post-install messages (formerly in spm.install)
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
