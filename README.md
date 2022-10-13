# WIP Enable RHEL for Realtime kernel with RHEL for Edge
## Setup
Edit the `demo.conf` file and make sure that the credentials are correct, the subscription type is correct for your deployment of image builder, and that the edge user credentials that will be in the RHEL for Edge image are correct.

Run the scripts in numerical order to prepare the environment.

## Build the RHEL for Edge image
Enable the RHEL for Realtime package repository for image-builder using the following command:

    composer-cli sources add rt-source.toml

You can see that this was correctly added using the commands:

    composer-cli sources list
    composer-cli sources info rt

Next, push the blueprint to image-builder and start the build using the commands:

    composer-cli blueprints push edge-blueprint.toml
    composer-cli compose start-ostree Edge-RT edge-container

This will take around ten minutes (YMMV). You can use the following command to watch the status change from RUNNING to FINISHED:

    watch composer-cli compose status

Use `CTRL-C` to stop that command once the compose is finished.

## Package as an ISO
TODO
