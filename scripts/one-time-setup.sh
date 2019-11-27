# Load kernel module
sudo modprobe kvm_intel

# Configure packet forwarding
sudo sysctl -w net.ipv4.conf.all.forwarding=1

# Avoid "neighbour: arp_cache: neighbor table overflow!"
sudo sysctl -w net.ipv4.neigh.default.gc_thresh1=1024
sudo sysctl -w net.ipv4.neigh.default.gc_thresh2=2048
sudo sysctl -w net.ipv4.neigh.default.gc_thresh3=4096

sudo chmod 777 /dev/kvm

# Add CAP_NET_ADMIN to firecracker (for TUNSETIFF ioctl)
sudo setcap cap_net_admin=eip ../firecracker_snapshotting_wip

# Dedicate more RAM to the page cache
sudo sysctl -w vm.dirty_background_ratio=90
sudo sysctl -w vm.dirty_expire_centisecs=10000

# Install dependencies if necessary
for dep in iperf3 python3; do
    command -v "$dep" &>/dev/null
    if [ "$?" != "0" ]; then
        sudo yum install -y "$dep"
    else echo "$dep is already installed"
    fi
done

# Download kernel and rootfs for demo image
img_dir="../images/alpine_demo"
image_bucket_url="https://s3.amazonaws.com/spec.ccfc.min/img/alpine_demo"

mkdir -p "$img_dir"/kernel
mkdir -p "$img_dir"/fsfiles

kernel="$image_bucket_url/kernel/vmlinux"
rootfs="$image_bucket_url/fsfiles/xenial.rootfs.ext4"
key="$image_bucket_url/fsfiles/xenial.rootfs.id_rsa"

dest_kernel="$img_dir/kernel/vmlinux"
dest_rootfs="$img_dir/fsfiles/xenial.rootfs.ext4"
dest_key="$img_dir/fsfiles/xenial.rootfs.id_rsa"

[ -e "$dest_kernel" ] || curl -fsSL -o "$dest_kernel" "$kernel"
[ -e "$dest_rootfs" ] || curl -fsSL -o "$dest_rootfs" "$rootfs"
[ -e "$dest_key" ] || curl -fsSL -o "$dest_key" "$key"

chown -R ec2-user:ec2-user "$img_dir/"
chmod 400 "$dest_key"
chmod +x "$dest_kernel"
