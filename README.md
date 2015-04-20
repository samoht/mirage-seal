## mirage-seal

Use this tool to seal the contents of a directory into a static unikernel,
serving its contents over HTTPS.

To serve the data in `files/` using the certificates
`secrets/server.key` and `server.pem`, do:

```
$ mirage-seal --data=files/ --keys=secrets/ [--ip-address=<IP>]
$ xl create seal.xl -c
```

### Testing

If you want to test `mirage-seal` locally, you can generate a self-signed
certificate using openSSL:

```
$ mkdir secrets
$ openssl req -x509 -newkey rsa:2048 -keyout secrets/server.key -out secrets/server.cert -subj '/CN=<IP>'
```
