# 빌드 실행 환경을 고정한다.
#
# exp03 B 경로가 막힌 이유가 이것 때문이었다: 다운로드한 LLVM 의 ld.lld 가
# libxml2.so.2 를 요구하는데 Ubuntu 26.04 는 libxml2.so.16 만 제공한다.
# 툴체인을 고정해도 그것이 도는 바닥을 고정하지 않으면 여전히 호스트를 탄다.
# 22.04 는 libxml2.so.2 를 제공한다.
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential \
      ca-certificates curl git file python3 unzip \
      gcc-aarch64-linux-gnu g++-aarch64-linux-gnu \
      qemu-user \
      libxml2 \
      libtinfo5 \
      zlib1g \
 && rm -rf /var/lib/apt/lists/*

# bazelisk 가 .bazelversion 을 읽어 해당 Bazel 을 받아온다.
ARG BAZELISK_VERSION=v1.25.0
RUN curl -fsSL -o /usr/local/bin/bazelisk \
      "https://github.com/bazelbuild/bazelisk/releases/download/${BAZELISK_VERSION}/bazelisk-linux-amd64" \
 && chmod +x /usr/local/bin/bazelisk \
 && ln -s /usr/local/bin/bazelisk /usr/local/bin/bazel

WORKDIR /workspace
