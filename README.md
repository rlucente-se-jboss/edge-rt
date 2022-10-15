# Enable RHEL for Realtime kernel with RHEL for Edge
## Setup
Edit the `demo.conf` file and make sure that the credentials are
correct, the subscription type is correct for your deployment of
image builder, and that the edge user credentials that will be in
the RHEL for Edge image are correct.

Run the scripts in numerical order to prepare the environment.

    cd ~/edge-rt
    sudo ./01-setup-rhel.sh
    reboot

After the system reboots, log in and continue:

    sudo ./02-install-image-builder.sh
    exit

Log in again and then run the remaining script:

    ./03-prep-image-build.sh

## Build the RHEL for Edge image
Enable the RHEL for Realtime package repository for image-builder
using the following command:

    composer-cli sources add rt-source.toml

You can see that this was correctly added using the commands:

    composer-cli sources list
    composer-cli sources info rt

Next, push the blueprint to image-builder and start the build using
the commands:

    composer-cli blueprints push edge-blueprint.toml
    composer-cli compose start-ostree Edge-RT edge-container

This will take around ten minutes (YMMV). You can use the following
command to watch the status change from RUNNING to FINISHED:

    watch composer-cli compose status

Use `CTRL-C` to stop that command once the compose is finished.

## Build the ISO installer image
Next, we'll download the rpm-ostree image packaged inside an OCI
container and then run the container application to support the
creation of the ISO installer.

If there are multiple rpm-ostree image on your host, use the
following command to identify the correct one.

    composer-cli compose status

On my system, the output looks like the following where the UUID
is the first column:

    $ composer-cli compose status
    dde61659-7a12-49e7-bba6-92d08d9a04e7 FINISHED Fri Oct 14 14:43:43 2022 Edge-RT   0.0.1 edge-container

If there's only one rpm-ostree image, you can simply hit TAB on the
following command to autofill the UUID of the image to download.

    composer-cli compose image <TAB>

We'll import the compressed OCI container to our local container
storage and then run the container to provide rpm-ostree content
to support the creation of the ISO installer.

    sudo podman load -i <UUID>-container.tar
    sudo podman images

Note the image identifier and use that to tag the image:

    sudo podman tag <IMAGE ID> localhost/edge-container

Now, run the container to offer the repository content for the
builder:

    sudo podman run --rm -d --name=edge-container -p 8080:8080 localhost/edge-container

Once the container is running, go ahead and kickoff the ISO installer
build.

To start the build, push the blueprint to the image builder service
and then launch the compose as shown below. Make sure to substitute
your server's IP address or DNS name as that will be configured as
a "remote" on the edge device for pulling ostree updates.

    composer-cli blueprints push edge-rt-installer.toml
    composer-cli compose start-ostree Edge-RT-installer edge-installer \
                 --url http://YOUR-SERVER-IP-ADDR-OR-NAME:8080/repo/

The compose for the ISO installer takes around four minutes on my
laptop. Again, your mileage may vary. You can monitor the build
using the command:

    watch composer-cli compose status

When the status is `FINISHED`, use CTRL-C to stop the above command.
In the other terminal window, use CTRL-C to stop the podman instance.

## Download the ISO installer
Identify the ISO installer image using the command:

    composer-cli compose status

On my system, the output looks like the following where the UUID
is the first column:

    $ composer-cli compose status
    dde61659-7a12-49e7-bba6-92d08d9a04e7 FINISHED Fri Oct 14 14:43:43 2022 Edge-RT         0.0.1 edge-conta
iner
    b9e2990c-8456-4a12-80ff-e8e762a00579 FINISHED Fri Oct 14 15:06:05 2022 Edge-RT-installer 0.0.1 edge-ins
taller

Download the ISO installer using the command:

    composer-cli compose image <INSTALLER-UUID>

The ISO can now be used to install an edge device. I subsequently
downloaded this ISO file from the RHEL host VM to my laptop so I
could use it to install a second VM for the edge device. If working
with a physical edge device, put the ISO file onto a USB thumb
drive. There are ample instructions and tools available on how to
do that.

# Test system performance under load
This section will be a very brief synopsis of what to do as the
[Optimizing RHEL 9 for Real Time for low latency operation](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux_for_real_time/9/html-single/optimizing_rhel_9_for_real_time_for_low_latency_operation/index)
contains extensive information on how to optimize and test the
performance of a RHEL for Real Time system.

## Install the RHEL for Edge ISO to a physical device
At this point you should have the ISO copied to a USB thumb drive.
Insert the thumb drive into your target host device and power on.
You may need to adjust the boot order to select the USB thumb drive
on boot.

After the system boots, you'll be prompted to run through an
abbreviated installation procedure. On my device, I had to specify
the installation disk and enable networking. Once installation is
complete, select `Reboot System` from the lower right of the
Installation Progress screen.

When the edge device gets to the BIOS startup screen, simply remove
the USB thumb drive before the system boots.

## Test system real-time performance under load
The first step is to run hardware and firmware latency tests to
ensure the system is suitable for RHEL for Real Time. Login to the
edge device using the credentials that were set in `demo.conf` for
the edge username/password. Then, run the following command:

    sudo hwlatdetect

This test will take two minutes to complete. The output will resemble
the following:

    hwlatdetect:  test duration 120 seconds
       detector: tracer
       parameters:
            Latency threshold: 10us
            Sample window:     1000000us
            Sample width:      500000us
         Non-sampling period:  500000us
            Output File:       None

    Starting test
    test finished
    Max Latency: Below threshold
    Samples recorded: 0
    Samples exceeding threshold: 0

The output shows that the edge system had max latency below 10 us,
the target we were looking to achieve.

Now, we'll run the `rteval` command to gather some performance
statistics. In the command below, I'm requesting verbose output and
a test duration of ten minutes.

    sudo rteval -v --duration=10m

Upon completion, the test will output a performance summary. For
my test, the results are below which show event response times
mean/median/mode around 5 microseconds.

    got system topology: 1 node system (8 cores per node)
    [INFO] importing module stressng
    [INFO] importing module hackbench
    [INFO] importing module kcompile
    [INFO] importing module cyclictest
    [INFO] Preparing load modules
    [INFO] Preparing measurement modules
    [INFO] Using measurement profile [loads: True  parallel: True]
    [INFO] Preparing load modules
    rteval run on 5.14.0-70.26.1.rt21.98.el9_0.x86_64 started at Sat Oct 15 10:14:08 2022
    started 3 loads on 8 cores
    started measurement threads on 8 cores
    Run duration: 600.0 seconds
    [INFO] Preparing measurement modules
    [INFO] Sending start event to all load modules
    [INFO] Waiting 30 seconds to let load modules settle down
    [INFO] [kcompile] Starting load on node 0
    [INFO] [kcompile node0] starting workload on node 0
    [INFO] Sending start event to all measurement modules
    [INFO] waiting for duration (600.0)
    [INFO] Stopping measurement modules
    [INFO] Stopping load modules
    [INFO] [cyclictest] reducing 0
    [INFO] [cyclictest] reducing 1
    [INFO] [hackbench] cleaning up hackbench on node 0
    [INFO] [cyclictest] reducing 2
    [INFO] [cyclictest] reducing 3
    [INFO] [cyclictest] reducing 4
    [INFO] [cyclictest] reducing 5
    [INFO] [cyclictest] reducing 6
    [INFO] [cyclictest] reducing 7
    [INFO] [cyclictest] reducing system
    stopping run at Sat Oct 15 10:24:43 2022
    [INFO] Waiting for measurement modules to complete
      ===================================================================
       rteval (v3.3) report
      -------------------------------------------------------------------
       Test run:     2022-10-15 10:13:44
       Run time:     0 days 0h 10m 4s


       Tested node:  my.edge.device
       Model:        Seco - C40
       BIOS version: American Megatrends Inc. (ver: 1.08, rev :5.13, release date: 04/23/2020)

       CPU cores:    8 (online: 8)
       NUMA Nodes:   1
       Memory:       30659.227 MB
       Kernel:       5.14.0-70.26.1.rt21.98.el9_0.x86_64  (RT enabled)
       Base OS:      Red Hat Enterprise Linux release 9.0 (Plow)
       Architecture: x86_64
       Clocksource:  tsc
       Available:    tsc hpet acpi_pm

       System load:
           Load average: 53.73

           Executed loads:
             - kcompile: numactl --cpunodebind 0 make O=/var/home/core/rteval-build/node0 -C /var/home/core/rteval-build/linux-5.13.2 -j24;
             - hackbench: hackbench -P -g 24 -l 1000 -s 1000

     Cmdline:        BOOT_IMAGE=(hd1,gpt2)/ostree/rhel-4328b11bd0722fdef83ce2fac40793df3575697101322940af76efcc287f07fd/vmlinuz-5.14.0-70.26.1.rt21.98.el9_0.x86_64 crashkernel=1G-4G:192M,4G-64G:256M,64G-:512M resume=/dev/mapper/rhel-swap rd.lvm.lv=rhel/root rd.lvm.lv=rhel/swap root=/dev/mapper/rhel-root ostree=/ostree/boot.0/rhel/4328b11bd0722fdef83ce2fac40793df3575697101322940af76efcc287f07fd/0

       Measurement profile 1: With loads, measurements in parallel
           Latency test
              Started: 2022-10-15 10:14:38.474422
              Stopped: 2022-10-15 10:24:39.102624
              Command: cyclictest -i100 -qmu -h 3500 -p95 -t -a

              System:
              Statistics:
                Samples:           48045005
                Mean:              5.551286840328147us
                Median:            5us
                Mode:              5us
                Range:             254us
                Min:               2us
                Max:               256us
                Mean Absolute Dev: 0.8499550012434576us
                Std.dev:           1.1967909777622785us

              CPU core 0       Priority: 95
              Statistics:
                Samples:           6005785
                Mean:              5.122747817312807us
                Median:            0.0us
                Mode:              5us
                Range:             75us
                Min:               2us
                Max:               77us
                Mean Absolute Dev: 0.6260134638501131us
                Std.dev:           1.0871353626245233us

              CPU core 1       Priority: 95
              Statistics:
                Samples:           6005735
                Mean:              5.901237900107148us
                Median:            5us
                Mode:              6us
                Range:             38us
                Min:               2us
                Max:               40us
                Mean Absolute Dev: 0.8235561693859761us
                Std.dev:           1.1829657040801762us

              CPU core 2       Priority: 95
              Statistics:
                Samples:           6005693
                Mean:              5.2380717762296545us
                Median:            0.0us
                Mode:              5us
                Range:             180us
                Min:               2us
                Max:               182us
                Mean Absolute Dev: 0.6650359407810875us
                Std.dev:           1.0766084703817709us

              CPU core 3       Priority: 95
              Statistics:
                Samples:           6005753
                Mean:              5.92799787137433us
                Median:            5us
                Mode:              6us
                Range:             37us
                Min:               2us
                Max:               39us
                Mean Absolute Dev: 0.8227966357217958us
                Std.dev:           1.2177048247238063us

              CPU core 4       Priority: 95
              Statistics:
                Samples:           6005772
                Mean:              5.213310128989246us
                Median:            0.0us
                Mode:              5us
                Range:             80us
                Min:               2us
                Max:               82us
                Mean Absolute Dev: 0.6589856232485785us
                Std.dev:           1.073806918048002us

              CPU core 5       Priority: 95
              Statistics:
                Samples:           6004851
                Mean:              5.905758694095823us
                Median:            5us
                Mode:              6us
                Range:             41us
                Min:               2us
                Max:               43us
                Mean Absolute Dev: 0.8067465974721906us
                Std.dev:           1.186609200833346us

              CPU core 6       Priority: 95
              Statistics:
                Samples:           6005673
                Mean:              5.8937985801091735us
                Median:            5us
                Mode:              6us
                Range:             254us
                Min:               2us
                Max:               256us
                Mean Absolute Dev: 0.799369713849035us
                Std.dev:           1.2006684100055962us

              CPU core 7       Priority: 95
              Statistics:
                Samples:           6005743
                Mean:              5.207430454483317us
                Median:            0.0us
                Mode:              5us
                Range:             71us
                Min:               2us
                Max:               73us
                Mean Absolute Dev: 0.6747429788425584us
                Std.dev:           1.100482214012038us


      ===================================================================

    ** COLLECTED WARNINGS **
    # SMBIOS implementations newer than version 2.7 are not
    # fully supported by this version of dmidecode.

    ** END OF WARNINGS **
