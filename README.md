# Simple example using Nginx to validate client certs

## Requirements
- linux (validated on ubuntu 24.04)
  - GNU Make (validated on 4.3)
- docker community (validated on 27.4.1)

## Step by step

First, build the environment:

```bash
make
```

Test the request without certs:

```bash
make test-without-certs
```

Test the request with certs:

```bash
make test-with-certs
```

Test all:

```bash
make test
```
## Additional example

As an additional example, an nginx_local_server was configured to connect to the nginx_remote_server using a pinned certificate. This setup allows the local Nginx to forward requests to the remote server with the pinned certificate, eliminating the need to modify the application.