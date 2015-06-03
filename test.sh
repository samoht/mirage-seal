#!/bin/sh -ex

eval `opam config env`

mirage-seal -d static --no-tls -t unix
mirage-seal -d static --no-tls
