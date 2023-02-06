echo "APT REFRESH STARTED: $(date)"
echo "1. Downloading packages information from all configured sources..."
/usr/bin/apt update -y

echo ""
echo "2. Installing available upgrades of all packages currently installed on the system..."
/usr/bin/apt --with-new-pkgs upgrade -y

echo ""
echo "3. Removing unnecessary dependencies..."
/usr/bin/apt autoremove -y
