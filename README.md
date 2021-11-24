# Balena Reset REST

This service is designed for devices that run [Balena OS](https://www.balena.io/os/). It will run at startup of the device and check if the configured button is pressed. If so, it will call all configured REST endpoints. When the operations are done, it gives feedback via the configured LED. Success is indicated by 3 flashes in short interval. Failure is indicated by 10 flashes in very short interval.

This service can be used to provide a way to factory-reset a Balena device which is not accessible via network (hence the name). Since you can call any REST endpoint on any device, possible use-cases are not limited to resetting a device.


## Setup

The device will run all endpoints configured in `endpoints.txt`. You have to create this file and add at least one REST endpoint. The information needs to be formatted as follows:

```txt
POST    200     http://example.com/endpoint/to/call
```

The first column defines the http method, the second column the expected http status code that indicates success (all other codes will be considered as failure!) and the third column is the endpoint to call. Columns are separated by whitespaces. The file can contain as many lines as you wish. Blank lines will be ignored.

You can also look into `endpoints-example.txt` to see how it should look like.

If you added the _balena-reset-rest_ repository as a Git submodule to your project and want to commit the endpoints configuration to your project repository, you can create `endpoints.txt` outside of the submodule and make it available via symlink:

```sh
$ cd balena-reset-rest
$ ln -s ../reset-endpoints.txt ./endpoints.txt
```

To integrate this service into your Balena multi-container setup, add this snippet to your `docker-compose.yml`:

```yml
  reset:
    build:
      context: ./balena-reset-rest
    network_mode: "host"
    labels:
      io.balena.features.sysfs: '1'
    devices:
      - "/dev/ttyS0:/dev/ttyS0"
    environment:
      GPIO_RESET_IN: 10
      GPIO_ACK_OUT: 27
      DEBUG_OUT: "/dev/ttyS0"
    depends_on:
      - service-a
      - service-b
    restart: no
```

`GPIO_RESET_IN` is the GPIO pin of the button. `GPIO_ACK_OUT` is the GPIO pin of the LED that indicates success/failure.

`depends_on` should contain all services that provide the reset endpoints that are configured in `endpoints.txt`. Those services need to be up _before_ the reset service tries to call the endpoint!

`restart: no` can be used if the service should only run on startup. If the user should be allowed to run the routine at any time, it can be removed. Be aware that this will put the service in a cycle of restarts that consumes system resources!


## Debugging

The service will write information to the container-internal command line. You can specify an additional target via the `DEBUG_OUT` environment variable.

This path can be the serial interface. In this case you have to add the path to the command line interface in `devices` like in the example above. Depending on your hardware, the path of the serial interface can be vary. The example above works for Raspberry Pi 4.

Another option would be to log to a file. If you want to persist this file, you need to add a docker volume and set `DEBUG_OUT` to a path on this volume.


## Caveats

Booting a _Balena_ devices takes some time. The more endpoints the reset service needs to call, the longer it takes until it is finished. If the list in `depends_on` is long, the reset service has to wait for a lot of services to start up and thus will take even longer. Therefore you should inform your user how long this process is expected to take and that they need to press the button until the LED flashes.