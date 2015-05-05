## mirage-seal

Use this tool to seal the contents of a directory into a static unikernel,
serving its contents over HTTPS.

### Install

For now on, you need to set up few opam pins:

```
opam remote add mirage-dev https://github.com/mirage/mirage-dev.git
opam pin add -n mirage-seal https://github.com/mirage/mirage-seal.git
```

The you can install `mirage-seal` using opam:

```
$ opam install mirage-seal
```

### Use

To serve the data in `files/` using the certificates
`secrets/server.key` and `secrets/server.pem`, simply do:

```
$ mirage-seal --data=files/ --keys=secrets/ [--ip=<IP>]
$ xl create seal.xl -c
```

If `--ip` is not specified, the unikernel will use DHCP to
acquire an IP address on boot.

### Test

If you want to test `mirage-seal` locally, you can generate a self-signed
certificate using openSSL (from [StackOverflow](http://stackoverflow.com/questions/10175812/how-to-create-a-self-signed-certificate-with-openssl)):

```
$ mkdir secrets
$ openssl req -x509 -newkey rsa:2048 -nodes -keyout secrets/server.key -out secrets/server.pem -days 365 -subj '/CN=<IP>'
```
