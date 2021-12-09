# Singularity Container

`apache2-npg_tracking.def` contains the recipe to build a Singularity
container to run the tracking web server. The recipe is using dynamic
labels to assign some of the metadata to the image. For this reason
the image cannot be built with singularity versions below 3.7.

## Building

A `token.txt` file must be placed in the same directory as the recipe,
containing an access token for the private repository.

Build the image from within the same directory: 

```
# as root
singularity build apache2-npg_tracking.sif apache2-npg_tracking.def

# or with fakeroot
singularity build --fakeroot apache2-npg_tracking.sif apache2-npg_tracking.def
```

Customisable environment variables:

- `TRACKING_PORT`: defaults to 9000
- `TRACKING_SSL_PORT`: defaults to 12443
- `TRACKING_GIT`: defaults to `https://github.com/wtsi-npg/npg_tracking`
- `DEV_BUILD`: set this to any value to build a development server image

By default the master branches of all git repositories will be used.
If `DEV_BUILD` is set, the `devel` branches will be used

## Running

You should place the server SSL certificate `server.pem` and key `key.pem`
and the application configuration file `config.ini` in the `config` directory
specified below.

- starting the instance :
  ```
  singularity instance start \
    -B /path/to/config/:/srv/data/ \
    -B /path/to/logs/:/srv/httpd/ \
    apache2-npg_tracking.sif \
    apache2-npg_tracking
  ```

- stopping the instance:
`singularity instance stop apache2-npg_tracking`
