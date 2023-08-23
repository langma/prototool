# Swift plugin
FROM swift:5.8 as swift-builder

RUN apt-get -q update \
    && apt-get -qy install wget make \
    && rm -r /var/lib/apt/lists/*

ENV SWIFT_PLUGIN_VERSION "1.19.0"
RUN wget -qO- https://github.com/grpc/grpc-swift/archive/$SWIFT_PLUGIN_VERSION.tar.gz | gunzip | tar x -C / \
    && make -C /grpc-swift-$SWIFT_PLUGIN_VERSION plugins \
    && cp /grpc-swift-$SWIFT_PLUGIN_VERSION/protoc*swift /usr/local/bin/ \
    && rm -rf /grpc-swift-$SWIFT_PLUGIN_VERSION

# Go plugin
FROM golang:1.21 as go-plugin
RUN GOBIN=/usr/local/bin go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
RUN GOBIN=/usr/local/bin go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest

# Scala plugin
FROM ubuntu:focal as scala-plugin
ENV SCALA_PLUGIN_VERSION "0.11.13"
RUN apt-get -qy update \
    && apt-get -y install curl zip
RUN curl -LO https://github.com/scalapb/ScalaPB/releases/download/v$SCALA_PLUGIN_VERSION/protoc-gen-scala-$SCALA_PLUGIN_VERSION-linux-x86_64.zip && unzip -o protoc-gen-scala-$SCALA_PLUGIN_VERSION-linux-x86_64.zip
RUN cp ./protoc-gen-scala /usr/local/bin/

# Build on top of prototool
FROM uber/prototool as builder
RUN apk add --update --no-cache \
    make \
    openjdk8-jre \
    # https://gitlab.alpinelinux.org/alpine/aports/-/issues/11615
    nghttp2-dev \
    nodejs \
    nodejs-npm \
    && rm -rf /var/cache/apk/*

ENV PROTOBUF_VERSION "24.1"
RUN mkdir -p /tmp/protoc && \
  curl -sSL \
  https://github.com/protocolbuffers/protobuf/releases/download/v$PROTOBUF_VERSION/protoc-$PROTOBUF_VERSION-linux-x86_64.zip \
  -o /tmp/protoc/protoc.zip && \
  cd /tmp/protoc && \
  unzip protoc.zip && \
  mv /tmp/protoc/include /usr/local/include && \
  mv /tmp/protoc/bin/protoc /usr/local/bin/protoc

COPY --from=swift-builder /usr/local/bin/protoc-gen-swift /usr/local/bin/protoc-gen-swift
COPY --from=swift-builder /usr/local/bin/protoc-gen-grpc-swift /usr/local/bin/protoc-gen-grpc-swift
COPY --from=swift-builder /lib/x86_64-linux-gnu/libc.so.6 /lib/x86_64-linux-gnu/libc.so.6
COPY --from=swift-builder /lib/x86_64-linux-gnu/libdl.so.2 /lib/x86_64-linux-gnu/libdl.so.2
COPY --from=swift-builder /lib/x86_64-linux-gnu/libgcc_s.so.1 /lib/x86_64-linux-gnu/libgcc_s.so.1
COPY --from=swift-builder /lib/x86_64-linux-gnu/libm.so.6 /lib/x86_64-linux-gnu/libm.so.6
COPY --from=swift-builder /lib/x86_64-linux-gnu/libpthread.so.0 /lib/x86_64-linux-gnu/libpthread.so.0
COPY --from=swift-builder /lib/x86_64-linux-gnu/librt.so.1 /lib/x86_64-linux-gnu/librt.so.1
COPY --from=swift-builder /lib/x86_64-linux-gnu/libutil.so.1 /lib/x86_64-linux-gnu/libutil.so.1
COPY --from=swift-builder /lib64/ld-linux-x86-64.so.2 /lib64/ld-linux-x86-64.so.2
COPY --from=swift-builder /usr/lib/swift/linux/libBlocksRuntime.so /usr/lib/swift/linux/libBlocksRuntime.so
COPY --from=swift-builder /usr/lib/swift/linux/libdispatch.so /usr/lib/swift/linux/libdispatch.so
COPY --from=swift-builder /usr/lib/swift/linux/libFoundation.so /usr/lib/swift/linux/libFoundation.so
COPY --from=swift-builder /usr/lib/swift/linux/libicudataswift.so.65 /usr/lib/swift/linux/libicudataswift.so.65
COPY --from=swift-builder /usr/lib/swift/linux/libicui18nswift.so.65 /usr/lib/swift/linux/libicui18nswift.so.65
COPY --from=swift-builder /usr/lib/swift/linux/libicuucswift.so.65 /usr/lib/swift/linux/libicuucswift.so.65
COPY --from=swift-builder /usr/lib/swift/linux/libswiftCore.so /usr/lib/swift/linux/libswiftCore.so
COPY --from=swift-builder /usr/lib/swift/linux/libswiftDispatch.so /usr/lib/swift/linux/libswiftDispatch.so
COPY --from=swift-builder /usr/lib/swift/linux/libswiftGlibc.so /usr/lib/swift/linux/libswiftGlibc.so
COPY --from=swift-builder /usr/lib/swift/linux/libswift_RegexParser.so /usr/lib/swift/linux/libswift_RegexParser.so
COPY --from=swift-builder /usr/lib/swift/linux/libswift_StringProcessing.so /usr/lib/swift/linux/libswift_StringProcessing.so
COPY --from=swift-builder /usr/lib/swift/linux/libswift_Concurrency.so /usr/lib/swift/linux/libswift_Concurrency.so
COPY --from=swift-builder /usr/lib/x86_64-linux-gnu/libatomic.so.1 /usr/lib/x86_64-linux-gnu/libatomic.so.1
COPY --from=swift-builder /usr/lib/x86_64-linux-gnu/libstdc++.so.6 /usr/lib/x86_64-linux-gnu/libstdc++.so.6

# Java gRPC plugin
ENV JAVA_PLUGIN_VERSION "1.57.2"
RUN curl https://repo1.maven.org/maven2/io/grpc/protoc-gen-grpc-java/$JAVA_PLUGIN_VERSION/protoc-gen-grpc-java-$JAVA_PLUGIN_VERSION-linux-x86_64.exe -o /usr/local/bin/protoc-gen-grpc-java \
    && chmod +x /usr/local/bin/protoc-gen-grpc-java

# kotlin
ENV KOTLIN_VERSION "0.14.2"
RUN curl https://repo1.maven.org/maven2/pro/streem/pbandk/protoc-gen-pbandk-jvm/$KOTLIN_VERSION/protoc-gen-pbandk-jvm-$KOTLIN_VERSION-jvm8.jar -o /usr/local/bin/protoc-gen-kotlin \
  && chmod +x /usr/local/bin/protoc-gen-kotlin

# kotlin gRPC
ENV KOTLIN_GRPC_VERSION "1.3.0"
RUN mkdir /kotlin-grpc \
  && curl https://repo1.maven.org/maven2/io/grpc/protoc-gen-grpc-kotlin/$KOTLIN_GRPC_VERSION/protoc-gen-grpc-kotlin-$KOTLIN_GRPC_VERSION-jdk8.jar -o /kotlin-grpc/protoc-gen-grpc-kotlin.jar
COPY protoc-gen-grpc-kotlin /usr/local/bin/

COPY --from=go-plugin /usr/local/bin/protoc-gen-go /usr/local/bin/
COPY --from=go-plugin /usr/local/bin/protoc-gen-go-grpc /usr/local/bin/
COPY --from=scala-plugin /usr/local/bin/protoc-gen-scala /usr/local/bin/
COPY --from=pseudomuto/protoc-gen-doc /usr/bin/protoc-gen-doc /usr/local/bin/

# TypeScript
RUN npm i -g yarn
RUN yarn global add grpc-tools grpc_tools_node_protoc_ts

# dotnet
ENV DOTNET_PLUGIN_VERSION=2.57.0
RUN curl -L https://www.nuget.org/api/v2/package/Grpc.Tools/$DOTNET_PLUGIN_VERSION -o temp.zip \
  && unzip -p temp.zip tools/linux_x64/grpc_csharp_plugin > /usr/local/bin/grpc_csharp_plugin \
  && chmod +x /usr/local/bin/grpc_csharp_plugin \
  && rm temp.zip

# unset static protoc
ENV PROTOTOOL_PROTOC_BIN_PATH=
ENV PROTOTOOL_PROTOC_WKT_PATH=

ENTRYPOINT ["prototool"]
