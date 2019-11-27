# Firecracker-demo

## Disclaimer

This demo showcases Firecracker's snapshotting capability.
**It's been run on an EC2 I3.metal host (the defaults start 1000 microVMs)
with an Ubuntu and an Amazon Linux 2 host OS, from an Ubuntu client.**

Deviations from this setup will probably lead to issues and/or sub-par
performance.

## Step-by-Step Instructions

Get this repo on an EC2 i3.metal instance.
Open two terminals/ssh-connections to the instance.

### Terminal window 1

will show a heatmap of network traffic done by each microVM.

```bash
python3 microvm-tiles.py
```

### Terminal window 2

will control the rest of the demo.

Raise the maximum processes and files limits.

# Raise the limits on open files and processes

```bash
sudo tee -a >> /etc/security/limits.conf <<EOL
ec2-user soft nproc 16384
ec2-user hard nproc 16384
ec2-user soft nofile 819200
ec2-user hard nofile 819200
EOL
```

Note: In the above configuration, `ec2-user` is a
placeholder for the ec2 instance logged in user.

Reload the ssh session to have the new limit applied.

Install additional dependencies: `python3` and `iperf3`.

Fix permissions on `/dev/kvm` and the ssh key:

```bash
sudo chmod 777 /dev/kvm
chmod 400 xenial.rootfs.id_rsa
```

Create 1000 TAPs, configure networking for them and start 1k `iperf3` servers
each bound to their respective TAP.

```bash
sudo ./0.initial-setup.sh 1000
```

#### Start 1000 Firecracker microVMs

Use 6 parallel threads to configure and start **1000** microVMs. Each
thread will get an equal slice of the 1k total and sequentially configure
and issue the start command for each microVM.

The script will report **total duration** as well as **mutation rate**.

```bash
# start a total of 1k uVMs from 6 parallel threads
./parallel-start-many.sh 0 1000 6
# ... wait for it ... should take around 60 seconds ... watch the heatmap
```

Each microVM has a workload (iperf client) and will run it in a loop with
a random `sleep` between iterations.

Looking at the heatmap you should see **six** 'snakes' advancing which
are the microVMs that have just been powered up and are doing their first
iteration of the workload. Once that's done, the random sleep will lead
to random lighting of the heatmap.

#### Pick a microVM and play with it

Pick a number `0 <= ID < 1000`. For this example `42` was chosen.

```bash
ID="42"
# get the IP for that microVM
ifconfig fc-$ID-tap0 | grep "inet "
       inet 169.254.0.170  netmask 255.255.255.252  broadcast 0.0.0.0

# IP of microVM on other side is *one less*
ssh -i xenial.rootfs.id_rsa root@169.254.0.169
```

You're now inside the microVM. Do as you please.

Let's make it stand out in the heatmap.

```bash
# stop the workload service
localhost:~# rc-service demo-workload stop
 * Stopping demo-workload ...                                    [ ok ]
# manually run iperf with a higher bandwidth than the rest
localhost:~# iperf3 -c $(./gateway-ip.sh) -b 104857600
# check out the heatmap
```

This microVM should now shine brighter in the heatmap.

Demonstrate the network throughput of this microVM:

```bash
localhost:~# iperf3 -c $(./gateway-ip.sh)
Connecting to host 169.254.0.170, port 5201
[  5] local 169.254.0.169 port 53392 connected to 169.254.0.170 port 5201
[ ID] Interval           Transfer     Bitrate         Retr  Cwnd
[  5]   0.00-1.00   sec  1.72 GBytes  14.8 Gbits/sec    0    952 KBytes
[  5]   1.00-2.00   sec  1.67 GBytes  14.4 Gbits/sec    0    952 KBytes
[  5]   2.00-3.00   sec  1.76 GBytes  15.1 Gbits/sec    0    952 KBytes
[  5]   3.00-4.00   sec  1.69 GBytes  14.5 Gbits/sec    0    952 KBytes
[  5]   4.00-5.00   sec  1.69 GBytes  14.5 Gbits/sec    0    952 KBytes
[  5]   5.00-6.00   sec  1.66 GBytes  14.3 Gbits/sec    0    952 KBytes
[  5]   6.00-7.00   sec  1.67 GBytes  14.4 Gbits/sec    0    952 KBytes
[  5]   7.00-8.00   sec  1.77 GBytes  15.2 Gbits/sec    0    952 KBytes
[  5]   8.00-9.00   sec  1.76 GBytes  15.1 Gbits/sec    0    952 KBytes
[  5]   9.00-10.00  sec  1.42 GBytes  12.2 Gbits/sec    0    952 KBytes
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bitrate         Retr
[  5]   0.00-10.00  sec  16.8 GBytes  14.4 Gbits/sec    0             sender
[  5]   0.00-10.00  sec  16.8 GBytes  14.4 Gbits/sec                  receiver

iperf Done.
```

#### Snapshot the 1000 microVMs

While the microVMs are running, save a snapshot of each. This will also
terminate them.

```bash
./parallel-snapshot-many 0 1000 6
```

The snapshots are saved in the `snapshots` directory. For each microVM, there
are 2 files: one containing the serialized microVM state, and one for the
guest's memory. They are called `fc$ID.bin` and `fc$ID.mem` respectively.

The files are small in size, with little state being saved, and only the
memory that the guest has actually dirtied:

```bash
ls -lh snapshots/fc42.bin 
-rw-rw-r-- 1 ec2-user ec2-user 16K Dec  3 19:18 snapshots/fc42.bin
du -sh snapshots/fc42.bin 
16K	snapshots/fc42.bin

ls -lh snapshots/fc42.mem 
-rw-rw-r-- 1 ec2-user ec2-user 128M Dec  3 19:19 snapshots/fc42.mem
du -sh snapshots/fc42.mem
37M	snapshots/fc42.mem
```

#### Resume the 4000 microVMs

Keep the heatmap in view to observe how the microVMs waking up no longer form
"snakes" - because each of them was snapshotted either while doing traffic, in
which case it will wake up and light its tile with the remaining traffic, or
during a `sleep` invocation. In this case, the tile stays unlit until it
finishes sleeping.

```bash
./parallel-resume-many 0 1000 6
```

You can redo the experiment that logs in to a random microVM and play with it.

#### Plot the 1000 Firecracker microVMs boot and resume times

To plot the boot and resume times, on your local machine or any non-headless
setup:

```bash
scp -i <identity-key> ec2-user@<i3.metal-ip>:firecracker-demo/{data.log,gnuplot.script} .
gnuplot gnuplot.script --persist
```
