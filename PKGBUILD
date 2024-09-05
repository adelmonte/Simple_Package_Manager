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
sha256sums=('35a58c9cd924f27181848e0d97d1b2349377647212375b78ab341e2d55782bbf' 
            'fdeff443991cf36b8426794bb204f498762b004868df2e9d52b80b92964dfaa2' 
            '6be8d37376090d2d7a8b3f8399dfa2cedb9df94837354c4ed9e6f899c16ead15' 
            '6be8d37376090d2d7a8b3f8399dfa2cedb9df94837354c4ed9e6f899c16ead15' 
            '0328e51ad3020b160706b3c0b0a29105991dcc58e47a22a9a0caf3f515af0e70')
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
