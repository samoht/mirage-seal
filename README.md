## mirage-seal

Use this tool to seal the contents of a directory into a static unikernel,
serving its contents over HTTPS.

To serve the data in `files/` using the certificates
`secrets/server,key` and `server.pem`, do:

```
$ mirage-seal --data=files/ --keys=secrets/
$ xl create mir-seal.xl -c
```