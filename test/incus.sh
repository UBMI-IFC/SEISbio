#!/bin/bash

# Universal Incus VM/Container Creator - Supports any distro available in images:
# Usage: sudo ./incus.sh [-c] <name> <distro/version> [cpu] [memory] [disk]

set -e

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to print messages
print_info() {
    printf "${GREEN}[INFO]${NC} %s\n" "$1"
}

print_error() {
    printf "${RED}[ERROR]${NC} %s\n" "$1"
}

print_warning() {
    printf "${YELLOW}[WARNING]${NC} %s\n" "$1"
}

print_debug() {
    printf "${BLUE}[DEBUG]${NC} %s\n" "$1"
}

print_title() {
    printf "\n${BLUE}=== %s ===${NC}\n" "$1"
}

# Show usage / help
show_usage() {
    echo "Usage: $0 [-c] <name> <distro/version> [cpu] [memory] [disk]"
    echo ""
    echo "Arguments:"
    echo "  name            Name for the instance"
    echo "  distro/version  Image from images: remote (e.g. debian/12, fedora/41)"
    echo "  cpu             Number of CPU cores (default: 2)"
    echo "  memory          RAM size (default: 2GiB)"
    echo "  disk            Disk size (default: 20GiB)"
    echo ""
    echo "VM Examples (default):"
    echo "  $0 my-vm debian/12"
    echo "  $0 fed-vm fedora/41 4 4GiB 40GiB"
    echo "  $0 arch-vm archlinux/current 2 2GiB 30GiB"
    echo "  $0 ubuntu-vm ubuntu/24.04 2 4GiB 50GiB"
    echo ""
    echo "Container Examples:"
    echo "  $0 -c my-ct debian/12"
    echo "  $0 -c arch-ct archlinux 2 2GiB 30GiB"
    echo "  $0 -c fed-ct fedora/43 4 4GiB 40GiB"
    echo ""
    echo "List available images:"
    echo "  sudo incus image list images: | less"
    echo "  sudo incus image list images: | grep <distro>"
    echo ""
    echo "Flags:"
    echo "  -c, --container  Create a container instead of a VM"
    echo "  -h, --help       Show this help message"
    echo "  -l, --list       List available distros (VM)"
    echo "  -lc, --list-ct   List available distros (Container)"
    exit 0
}

# List available distros
list_distros() {
    local img_type="$1"
    local label="VM"
    local grep_type="VIRTUAL-MACHINE"
    if [ "$img_type" = "container" ]; then
        label="Container"
        grep_type="CONTAINER"
    fi
    print_title "Available Distro Images ($label)"
    echo ""
    print_info "Fetching image list... (this may take a moment)"
    echo ""
    incus image list images: --format csv -c l 2>/dev/null | \
        grep "$grep_type" | \
        sed 's/ (.*//g' | \
        sort -u
    echo ""
    print_info "Use any of the above as the distro/version argument"
    if [ "$img_type" = "container" ]; then
        print_info "Example: sudo $0 -c my-ct debian/12"
    else
        print_info "Example: sudo $0 my-vm debian/12"
    fi
    exit 0
}

# Instance type (default: VM)
INSTANCE_TYPE="vm"
INSTANCE_LABEL="VM"
IMAGE_TYPE="VIRTUAL-MACHINE"

# Parse flags
case "${1:-}" in
    -h|--help)
        show_usage
        ;;
    -l|--list)
        list_distros "vm"
        ;;
    -lc|--list-ct)
        list_distros "container"
        ;;
    -c|--container)
        INSTANCE_TYPE="container"
        INSTANCE_LABEL="Container"
        IMAGE_TYPE="CONTAINER"
        shift
        ;;
esac

# Validate minimum arguments
if [ $# -lt 2 ]; then
    print_error "Missing arguments"
    echo ""
    show_usage
fi

# Instance Configuration
VM_NAME="$1"
DISTRO_IMAGE="$2"
CPU_CORES="${3:-2}"
MEMORY="${4:-2GiB}"
DISK_SIZE="${5:-20GiB}"
IMAGE="images:${DISTRO_IMAGE}"

# Extract distro name from image path (e.g. debian/12 -> debian)
DISTRO=$(echo "$DISTRO_IMAGE" | cut -d'/' -f1)

# Detect package manager based on distro
detect_pkg_manager() {
    local distro="$1"
    
    case "$distro" in
        debian|ubuntu|devuan|kali|mint)
            PKG_MGR="apt"
            UPDATE_CMD="apt-get update && DEBIAN_FRONTEND=noninteractive apt-get upgrade -y"
            INSTALL_CMD="DEBIAN_FRONTEND=noninteractive apt-get install -y"
            PACKAGES="curl wget vim htop net-tools sudo iputils-ping dnsutils traceroute build-essential git"
            SUDO_GROUP="sudo"
            ;;
        fedora)
            PKG_MGR="dnf"
            UPDATE_CMD="dnf upgrade -y"
            INSTALL_CMD="dnf install -y"
            PACKAGES="vim curl wget git htop net-tools bind-utils gcc make python3 tar gzip unzip sudo"
            EXTRA_CMD="dnf groupinstall -y 'Development Tools' 2>/dev/null || true"
            SUDO_GROUP="wheel"
            ;;
        centos|rockylinux|almalinux|oracle)
            PKG_MGR="dnf"
            UPDATE_CMD="dnf upgrade -y"
            INSTALL_CMD="dnf install -y"
            PACKAGES="vim curl wget git htop net-tools bind-utils gcc make python3 tar gzip unzip sudo"
            EXTRA_CMD="dnf groupinstall -y 'Development Tools' 2>/dev/null || true"
            SUDO_GROUP="wheel"
            ;;
        opensuse|suse)
            PKG_MGR="zypper"
            UPDATE_CMD="zypper refresh && zypper update -y"
            INSTALL_CMD="zypper install -y"
            PACKAGES="vim curl wget git htop net-tools bind-utils gcc make python3 tar gzip unzip sudo"
            SUDO_GROUP="wheel"
            ;;
        archlinux|arch)
            PKG_MGR="pacman"
            UPDATE_CMD="pacman -Syu --noconfirm"
            INSTALL_CMD="pacman -S --noconfirm"
            PACKAGES="vim curl wget git htop net-tools bind-tools gcc make python3 traceroute sudo"
            SUDO_GROUP="wheel"
            ;;
        alpine)
            PKG_MGR="apk"
            UPDATE_CMD="apk update && apk upgrade"
            INSTALL_CMD="apk add"
            # shadow provides useradd/usermod/chpasswd on Alpine
            PACKAGES="vim curl wget git htop net-tools bind-tools gcc make python3 bash sudo shadow"
            SUDO_GROUP="wheel"
            ;;
        voidlinux|void)
            PKG_MGR="xbps"
            UPDATE_CMD="xbps-install -Syu"
            INSTALL_CMD="xbps-install -y"
            PACKAGES="vim curl wget git htop net-tools bind-utils gcc make python3 bash sudo"
            SUDO_GROUP="wheel"
            ;;
        gentoo)
            PKG_MGR="emerge"
            # NOTE: 'emerge --update --deep --newuse @world' is intentionally omitted.
            # A full Gentoo world rebuild downloads several GB of source tarballs and
            # compiles everything from source in parallel, saturating host bandwidth
            # and CPU — which kills the host's internet connection.
            # We only sync the Portage tree here; manual 'emerge @world' can be run later.
            UPDATE_CMD="emaint --auto sync"
            INSTALL_CMD="emerge"
            # Gentoo requires full category/package atoms (e.g. app-editors/vim, not just vim)
            PACKAGES="app-editors/vim net-misc/curl net-misc/wget dev-vcs/git sys-process/htop net-analyzer/nettools app-admin/sudo"
            # Limit parallel compile jobs to avoid saturating host CPU/bandwidth
            EXTRA_CMD="mkdir -p /etc/portage && echo 'MAKEOPTS=\"-j2 -l2\"' >> /etc/portage/make.conf && echo 'EMERGE_DEFAULT_OPTS=\"--jobs=1 --load-average=2\"' >> /etc/portage/make.conf"
            SUDO_GROUP="wheel"
            ;;
        nixos)
            PKG_MGR="nix"
            UPDATE_CMD="nix-channel --update && nixos-rebuild switch"
            INSTALL_CMD="nix-env -iA nixos."
            PACKAGES=""
            SUDO_GROUP="wheel"
            ;;
        *)
            PKG_MGR="unknown"
            UPDATE_CMD=""
            INSTALL_CMD=""
            PACKAGES=""
            SUDO_GROUP="sudo"
            ;;
    esac
}

detect_pkg_manager "$DISTRO"

print_title "$INSTANCE_LABEL Configuration"
echo "  Name:    $VM_NAME"
echo "  Type:    $INSTANCE_LABEL"
echo "  Image:   $IMAGE"
echo "  Distro:  $DISTRO"
echo "  CPU:     $CPU_CORES cores"
echo "  Memory:  $MEMORY"
echo "  Disk:    $DISK_SIZE"
echo "  Pkg Mgr: $PKG_MGR"
echo ""

# Check if running with sudo
if [ "$EUID" -ne 0 ]; then
    print_error "Please run with sudo"
    exit 1
fi

# Check if Incus is installed
if ! command -v incus &> /dev/null; then
    print_error "Incus is not installed. Please install it first."
    exit 1
fi

# ========================================
# Configure Host Networking
# ========================================
print_title "Configuring Host Networking"

# Enable IP forwarding
if [ "$(cat /proc/sys/net/ipv4/ip_forward)" != "1" ]; then
    print_info "Enabling IP forwarding..."
    sysctl -w net.ipv4.ip_forward=1
    if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf 2>/dev/null; then
        echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    fi
else
    print_info "IP forwarding already enabled"
fi

# Get main network interface
MAIN_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
print_info "Main network interface: $MAIN_INTERFACE"

# Configure incusbr0
print_info "Configuring incusbr0 network bridge..."
if incus network list | grep -q incusbr0; then
    incus network set incusbr0 ipv4.address=10.191.94.1/24 2>/dev/null || true
    incus network set incusbr0 ipv4.nat=true
    incus network set incusbr0 ipv4.routing=true
    incus network set incusbr0 ipv4.dhcp=true
    incus network set incusbr0 ipv6.address=none 2>/dev/null || true
    incus network set incusbr0 ipv6.nat=false 2>/dev/null || true
    incus network set incusbr0 dns.mode=managed 2>/dev/null || true
    incus network set incusbr0 bridge.mtu=1450 2>/dev/null || true
    incus network set incusbr0 bridge.driver=native 2>/dev/null || true
    print_info " incusbr0 updated"
else
    print_info "Creating incusbr0..."
    incus network create incusbr0 \
        ipv4.address=10.191.94.1/24 \
        ipv4.nat=true \
        ipv4.routing=true \
        ipv4.dhcp=true \
        ipv6.address=none \
        ipv6.nat=false \
        dns.mode=managed \
        bridge.mtu=1450 \
        bridge.driver=native
    print_info " incusbr0 created"
fi

# Configure iptables
print_info "Configuring iptables..."

# Clean up duplicate NAT rules
while iptables -t nat -D POSTROUTING -s 10.191.94.0/24 -o "$MAIN_INTERFACE" -j MASQUERADE 2>/dev/null; do
    :
done

# Add NAT rule
iptables -t nat -A POSTROUTING -s 10.191.94.0/24 -o "$MAIN_INTERFACE" -j MASQUERADE
print_info " NAT MASQUERADE rule added"

# Configure FORWARD chain
iptables -A FORWARD -i incusbr0 -o "$MAIN_INTERFACE" -j ACCEPT 2>/dev/null || true
iptables -A FORWARD -i "$MAIN_INTERFACE" -o incusbr0 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
iptables -A FORWARD -i incusbr0 -j ACCEPT 2>/dev/null || true
iptables -A FORWARD -o incusbr0 -j ACCEPT 2>/dev/null || true
print_info " iptables FORWARD chain configured"

# Fix TCP MSS clamping for MTU 1450 bridge (prevents large downloads from hanging)
# Without this, Path MTU Discovery fails silently inside VMs: small packets work
# but large transfers (e.g. miniforge/miniconda installers ~100MB) stall forever.
# MSS = MTU(1450) - IP header(20) - TCP header(20) = 1410
iptables -t mangle -C FORWARD -p tcp --tcp-flags SYN,RST SYN \
    -j TCPMSS --set-mss 1410 2>/dev/null || \
iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN \
    -j TCPMSS --set-mss 1410
print_info " TCP MSS clamped to 1410 (MTU 1450 fix)"

# Verify default profile
if ! incus profile device list default | grep -q eth0; then
    incus profile device add default eth0 nic \
        nictype=bridged \
        parent=incusbr0 \
        name=eth0 2>/dev/null || true
fi

# ========================================
# Check Existing Instance
# ========================================
if incus info "$VM_NAME" &>/dev/null; then
    print_warning "$INSTANCE_LABEL '$VM_NAME' already exists."
    read -p "Do you want to delete it and create a new one? (y/N): " response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        print_info "Stopping and deleting existing $INSTANCE_LABEL..."
        incus stop "$VM_NAME" --force 2>/dev/null || true
        incus delete "$VM_NAME" --force
    else
        print_info "Operation cancelled."
        exit 0
    fi
fi

# ========================================
# Verify Image Exists
# ========================================
print_title "Verifying Image"
print_info "Checking if '$DISTRO_IMAGE' is available as $INSTANCE_LABEL..."

# Try to find the image
VM_FINGERPRINT=""

# Method 1: Try the image alias directly (works for most distros like debian/12)
VM_FINGERPRINT=$(incus image list images:"$DISTRO_IMAGE" --format csv -c lft 2>/dev/null | grep "$IMAGE_TYPE" | head -1 | awk -F',' '{print $2}')

# Method 2: If not found, try without the version part (e.g. archlinux instead of archlinux/current)
if [ -z "$VM_FINGERPRINT" ]; then
    VM_FINGERPRINT=$(incus image list images:"$DISTRO" --format csv -c lft 2>/dev/null | grep "$IMAGE_TYPE" | grep -v "cloud\|desktop\|arm64\|riscv" | head -1 | awk -F',' '{print $2}')
fi

if [ -z "$VM_FINGERPRINT" ]; then
    print_error "Image '$DISTRO_IMAGE' not found as a $INSTANCE_LABEL image in remote images"
    echo ""
    print_info "Available $INSTANCE_LABEL images for '$DISTRO':"
    echo ""
    incus image list images:"$DISTRO" --format csv -c lft 2>/dev/null | grep "$IMAGE_TYPE"
    echo ""
    print_info "Try using the distro name without version for rolling releases:"
    if [ "$INSTANCE_TYPE" = "container" ]; then
        echo "  sudo $0 -c my-ct archlinux 2 2GiB 30GiB"
    else
        echo "  sudo $0 my-vm archlinux 2 2GiB 30GiB"
    fi
    exit 1
fi

print_info " Image found (fingerprint: ${VM_FINGERPRINT:0:12})"

# ========================================
# Create Instance
# ========================================
print_title "Creating $INSTANCE_LABEL"
print_info "Creating $DISTRO_IMAGE $INSTANCE_LABEL '$VM_NAME'..."
print_info "Using image: $IMAGE (verified fingerprint: ${VM_FINGERPRINT:0:12})"

if [ "$INSTANCE_TYPE" = "vm" ]; then
    incus init "$IMAGE" "$VM_NAME" --vm \
        -c limits.cpu="$CPU_CORES" \
        -c limits.memory="$MEMORY"

    # Disable secureboot for distros that don't support it
    case "$DISTRO" in
        archlinux|arch|voidlinux|void|gentoo|alpine|nixos)
            print_info "Disabling secureboot (not supported by $DISTRO)..."
            incus config set "$VM_NAME" security.secureboot=false
            ;;
    esac
else
    incus init "$IMAGE" "$VM_NAME" \
        -c limits.cpu="$CPU_CORES" \
        -c limits.memory="$MEMORY"
fi

# Add network device
print_info "Configuring VM network device..."
incus config device add "$VM_NAME" eth0 nic \
    nictype=bridged \
    parent=incusbr0 \
    name=eth0

# Configure disk size
print_info "Configuring storage ($DISK_SIZE)..."
incus config device override "$VM_NAME" root size="$DISK_SIZE"

# Start the VM
print_info "Starting VM..."
incus start "$VM_NAME"

# ========================================
# Wait for Boot
# ========================================
print_title "Waiting for $INSTANCE_LABEL Boot"
timeout=90
counter=0
while [ $counter -lt $timeout ]; do
    STATUS=$(incus list "$VM_NAME" --format csv -c s)
    if [ "$STATUS" = "RUNNING" ]; then
        break
    fi
    sleep 2
    counter=$((counter + 2))
done

if [ $counter -ge $timeout ]; then
    print_error "$INSTANCE_LABEL did not start within expected time."
    exit 1
fi

if [ "$INSTANCE_TYPE" = "vm" ]; then
    print_info "$INSTANCE_LABEL is running. Waiting for system initialization..."
    sleep 25
else
    print_info "$INSTANCE_LABEL is running. Waiting for system initialization..."
    sleep 5
fi

# ========================================
# Wait for Network
# ========================================
print_title "Waiting for Network"
max_attempts=60
attempt=0
network_ready=false

while [ $attempt -lt $max_attempts ]; do
    INTERFACES=$(incus exec "$VM_NAME" -- ip -o link show 2>/dev/null | grep -v "lo:" | wc -l)

    if [ "$INTERFACES" -gt 0 ]; then
        if incus exec "$VM_NAME" -- ip addr show 2>/dev/null | grep -q "inet.*scope global"; then
            print_info " Network interface is up with IP address"
            network_ready=true
            break
        fi
    fi

    sleep 2
    attempt=$((attempt + 2))

    if [ $((attempt % 10)) -eq 0 ]; then
        print_debug "Waiting for network... ($attempt/$max_attempts)"
    fi
done

# Display network info
echo ""
print_info "Network interfaces in VM:"
incus exec "$VM_NAME" -- ip addr show

echo ""
print_info "Routes in VM:"
incus exec "$VM_NAME" -- ip route

# ========================================
# Test Connectivity
# ========================================
print_title "Testing Connectivity"
sleep 5

# Test gateway
if incus exec "$VM_NAME" -- timeout 5 ping -c 2 10.191.94.1 &>/dev/null; then
    print_info " Can reach gateway (10.191.94.1)"
else
    print_error " Cannot reach gateway"
fi

# Test external IP
internet_ok=false
if incus exec "$VM_NAME" -- timeout 5 ping -c 2 8.8.8.8 &>/dev/null; then
    print_info " Can reach external IP (8.8.8.8)"
    internet_ok=true
else
    print_error " Cannot reach external IP"
    print_warning "Attempting network fix..."

    iptables -A FORWARD -i incusbr0 -j ACCEPT 2>/dev/null || true
    iptables -A FORWARD -o incusbr0 -j ACCEPT 2>/dev/null || true
    sleep 3

    if incus exec "$VM_NAME" -- timeout 5 ping -c 2 8.8.8.8 &>/dev/null; then
        print_info " Fix applied - Internet now working!"
        internet_ok=true
    else
        print_error " Still cannot reach external IP"
    fi
fi

# Test DNS
if incus exec "$VM_NAME" -- timeout 5 ping -c 2 google.com &>/dev/null; then
    print_info " DNS resolution working"
else
    print_warning " DNS resolution not working"
fi

# ========================================
# Install Packages
# ========================================
set +e
if [ "$internet_ok" = true ] && [ "$PKG_MGR" != "unknown" ]; then
    print_title "Configuring System ($PKG_MGR)"

    print_info "Updating system packages..."
    incus exec "$VM_NAME" -- bash -c "$UPDATE_CMD"
    if [ $? -ne 0 ]; then
        print_warning "System update had issues"
    fi

    if [ -n "$PACKAGES" ]; then
        print_info "Installing essential tools..."
        incus exec "$VM_NAME" -- bash -c "$INSTALL_CMD $PACKAGES"
        if [ $? -ne 0 ]; then
            print_warning "Some packages could not be installed"
        fi
    fi

    # Run distro-specific extra commands
    if [ -n "${EXTRA_CMD:-}" ]; then
        print_info "Running distro-specific configuration..."
        incus exec "$VM_NAME" -- bash -c "$EXTRA_CMD"
    fi

    print_info " System configured"

elif [ "$internet_ok" = true ] && [ "$PKG_MGR" = "unknown" ]; then
    print_warning "Unknown package manager for '$DISTRO'"
    print_warning "Skipping package installation. You can install packages manually."
else
    print_error "Skipping system update due to connectivity issues"
    echo ""
    print_warning "To fix connectivity, run:"
    echo "  sudo iptables -A FORWARD -i incusbr0 -j ACCEPT"
    echo "  sudo iptables -A FORWARD -o incusbr0 -j ACCEPT"
fi
set -e

# ========================================
# User Setup
# ========================================
print_title "User Setup"

# Ensure sudo is installed (for distros that may not ship it)
if [ "$internet_ok" = true ] && [ "$PKG_MGR" != "unknown" ] && [ "$PKG_MGR" != "nix" ]; then
    if ! incus exec "$VM_NAME" -- which sudo &>/dev/null 2>&1; then
        print_info "Installing sudo..."
        incus exec "$VM_NAME" -- bash -c "$INSTALL_CMD sudo" 2>/dev/null || true
    else
        print_info "sudo already present"
    fi
fi

# Uncomment wheel group in sudoers for distros that use wheel
if [ "$SUDO_GROUP" = "wheel" ]; then
    print_info "Enabling %wheel in /etc/sudoers..."
    incus exec "$VM_NAME" -- bash -c \
        "sed -i 's/^#[[:space:]]*%wheel[[:space:]]\+ALL=(ALL:ALL)[[:space:]]\+ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers 2>/dev/null; \
         sed -i 's/^#[[:space:]]*%wheel[[:space:]]\+ALL=(ALL)[[:space:]]\+ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers 2>/dev/null" || true
fi

# Create user (Alpine uses busybox adduser; all others use useradd)
print_info "Creating user 'user'..."
if [ "$DISTRO" = "alpine" ]; then
    incus exec "$VM_NAME" -- adduser -D -s /bin/bash user 2>/dev/null || true
    incus exec "$VM_NAME" -- addgroup user wheel 2>/dev/null || true
else
    incus exec "$VM_NAME" -- useradd -m -s /bin/bash user 2>/dev/null || true
    incus exec "$VM_NAME" -- usermod -a -G "$SUDO_GROUP" user 2>/dev/null || true
fi

# Set password via chpasswd (portable across all distros with shadow-utils)
print_info "Setting password for 'user'..."
incus exec "$VM_NAME" -- bash -c "echo 'user:yomerengues' | chpasswd" 2>/dev/null || \
    incus exec "$VM_NAME" -- bash -c "echo 'yomerengues' | passwd --stdin user" 2>/dev/null || true

print_info " User 'user' created (sudo group: $SUDO_GROUP, password: yomerengues)"

# ========================================
# Create Snapshot
# ========================================
print_title "Creating Snapshot"
print_info "Creating 'clean' snapshot..."
if incus snapshot create "$VM_NAME" clean 2>/dev/null; then
    print_info " Snapshot 'clean' created"
else
    print_warning "Could not create snapshot 'clean' (may already exist)"
fi

# ========================================
# Final Summary
# ========================================
echo ""
print_title "$INSTANCE_LABEL Setup Complete"
echo ""

incus list "$VM_NAME"

echo ""
IP_ADDRESS=$(incus exec "$VM_NAME" -- hostname -I 2>/dev/null | awk '{print $1}')
if [ -n "$IP_ADDRESS" ]; then
    echo "  $INSTANCE_LABEL IP: $IP_ADDRESS"
    echo "  Gateway:       10.191.94.1"
    echo "  Network:       incusbr0 (10.191.94.0/24)"
    echo "  Host IF:       $MAIN_INTERFACE"
fi

echo ""
print_info "OS Information:"
incus exec "$VM_NAME" -- cat /etc/os-release 2>/dev/null | grep -E "^(PRETTY_NAME|VERSION)" | head -3 || echo "  $DISTRO_IMAGE"

echo ""
print_info "User Account:"
echo "  Username:  user"
echo "  Password:  yomerengues"
echo "  Group:     $SUDO_GROUP"
echo "  Snapshot:  clean  (restore: incus restore $VM_NAME clean)"

echo ""
print_info "Quick Access:"
echo "  incus shell $VM_NAME"
echo "  incus exec $VM_NAME -- <command>"
echo "  incus exec $VM_NAME -- su - user"

echo ""
print_info "Package Management ($PKG_MGR):"
case "$PKG_MGR" in
    apt)
        echo "  Search:   incus exec $VM_NAME -- apt search <pkg>"
        echo "  Install:  incus exec $VM_NAME -- apt install -y <pkg>"
        echo "  Update:   incus exec $VM_NAME -- apt update && apt upgrade -y"
        ;;
    dnf)
        echo "  Search:   incus exec $VM_NAME -- dnf search <pkg>"
        echo "  Install:  incus exec $VM_NAME -- dnf install -y <pkg>"
        echo "  Update:   incus exec $VM_NAME -- dnf upgrade -y"
        ;;
    zypper)
        echo "  Search:   incus exec $VM_NAME -- zypper search <pkg>"
        echo "  Install:  incus exec $VM_NAME -- zypper install -y <pkg>"
        echo "  Update:   incus exec $VM_NAME -- zypper update -y"
        ;;
    pacman)
        echo "  Search:   incus exec $VM_NAME -- pacman -Ss <pkg>"
        echo "  Install:  incus exec $VM_NAME -- pacman -S --noconfirm <pkg>"
        echo "  Update:   incus exec $VM_NAME -- pacman -Syu --noconfirm"
        ;;
    apk)
        echo "  Search:   incus exec $VM_NAME -- apk search <pkg>"
        echo "  Install:  incus exec $VM_NAME -- apk add <pkg>"
        echo "  Update:   incus exec $VM_NAME -- apk update && apk upgrade"
        ;;
    xbps)
        echo "  Search:   incus exec $VM_NAME -- xbps-query -Rs <pkg>"
        echo "  Install:  incus exec $VM_NAME -- xbps-install -y <pkg>"
        echo "  Update:   incus exec $VM_NAME -- xbps-install -Syu"
        ;;
    emerge)
        echo "  Search:   incus exec $VM_NAME -- emerge --search <pkg>"
        echo "  Install:  incus exec $VM_NAME -- emerge <pkg>"
        echo "  Update:   incus exec $VM_NAME -- emerge --update --deep @world"
        ;;
    nix)
        echo "  Search:   incus exec $VM_NAME -- nix search nixpkgs <pkg>"
        echo "  Install:  incus exec $VM_NAME -- nix-env -iA nixos.<pkg>"
        echo "  Update:   incus exec $VM_NAME -- nixos-rebuild switch"
        ;;
    *)
        echo "  (Package manager not auto-detected for '$DISTRO')"
        echo "  Access VM and install manually: incus shell $VM_NAME"
        ;;
esac

echo ""
print_info "$INSTANCE_LABEL Management:"
echo "  Stop:      incus stop $VM_NAME"
echo "  Start:     incus start $VM_NAME"
echo "  Restart:   incus restart $VM_NAME"
echo "  Delete:    incus delete $VM_NAME --force"
echo "  Info:      incus info $VM_NAME"
echo "  Console:   incus console $VM_NAME"
echo "  Snapshot:  incus snapshot $VM_NAME <name>"
echo "  Restore:   incus restore $VM_NAME <name>"

echo ""
print_info "Test connectivity:"
echo "  incus exec $VM_NAME -- ping -c 3 8.8.8.8"
echo "  incus exec $VM_NAME -- ping -c 3 google.com"
echo "  incus exec $VM_NAME -- curl -I https://www.google.com"
echo ""

# Save iptables rules
if command -v iptables-save &> /dev/null; then
    mkdir -p /etc/iptables-rules
    iptables-save > /etc/iptables-rules/rules.v4
    print_info " iptables rules saved"
fi

print_info "Done! Enjoy your new $DISTRO_IMAGE $INSTANCE_LABEL"
