## mirage-seal

Use this tool to seal the contents of a directory into a static unikernel,
serving its contents over HTTPS.

### Install

```
$ opam remote add mirage-dev https://github.com/mirage/mirage-dev.git
$ opam pin add mirage-seal https://github.com/samoht/mirage-seal
```

### Use

You will need `xentropyd` installed and running:

```
$ opam install xentropyd
$ sudo xentropyd --daemon
```

Then, to serve the data in `files/` using the certificates
`secrets/server.key` and `server.pem`, simply do:

```
$ mirage-seal --data=files/ --keys=secrets/ [--ip-address=<IP>]
$ xl create seal.xl -c
```

If `--ip-address` is not specified, the unikernel will use DHCP to
acquire an IP address on boot.

### Test

If you want to test `mirage-seal` locally, you can generate a self-signed
certificate using openSSL:

```
$ mkdir secrets
$ openssl req -x509 -newkey rsa:2048 -keyout secrets/server.key -out secrets/server.pem -subj '/CN=<IP>'
```
