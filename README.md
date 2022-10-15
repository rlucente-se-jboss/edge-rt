# WIP Enable RHEL for Realtime kernel with RHEL for Edge
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

# TODO Use cyclictest to generate the kernel-rt graphs
https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux_for_real_time/9/html-single/optimizing_rhel_9_for_real_time_for_low_latency_operation/index#assembly_creating-and-running-containers_optimizing-RHEL9-for-real-time-for-low-latency-operation
