FROM avsm/mirage:latest
MAINTAINER Anil Madhavapeddy <anil@recoil.org>
RUN opam install mirage-seal
ENTRYPOINT ["opam-config-exec", "bash"]
