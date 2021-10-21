# Singularity Container

`apache2-npg_tracking.def` contains the recipe to build a Singularity to run the tracking server.

## Building

A `token.txt` file must be placed in the same directory as the recipe, containing an access token for the private repository.
Then, build the image from within the same directory: 
- as root: `singularity build apache2-npg_tracking.sif apache2-npg_tracking.def`
- or with fakeroot: `singularity build --fakeroot apache2-npg_tracking.sif apache2-npg_tracking.def` 

## Running

You should place the server SSL certificate and key, and the `config.ini` in a folder.

- starting the instance :
  ```
  singularity instance start \
    -B /path/to/config/folder/:/srv/data/ \
    -B /path/to/logs/folder/:/srv/httpd/ \
    apache2-npg_tracking.sif \
    apache2-npg_tracking
  ```

- stopping the instance:
`singularity instance stop apache2`