# Swift plugin
FROM swift:5.4-focal as swift-builder

RUN apt-get -q update && \
    apt-get -q install -y \
    wget make \
    && rm -r /var/lib/apt/lists/*

ENV SWIFT_PLUGIN_VERSION "1.4.0"
RUN wget -qO- https://github.com/grpc/grpc-swift/archive/$SWIFT_PLUGIN_VERSION.tar.gz | gunzip | tar x -C / \
    && make -C /grpc-swift-$SWIFT_PLUGIN_VERSION plugins \
    && cp /grpc-swift-$SWIFT_PLUGIN_VERSION/protoc*swift /usr/local/bin/ \
	&& rm -rf /grpc-swift-$SWIFT_PLUGIN_VERSION


# Kotlin plugin
FROM openjdk:8 as kotlin-plugin
ENV KOTLIN_PLUGIN_VERSION "0.10.0"
RUN apt-get update && \
    apt-get -y install curl unzip
RUN curl -LO https://github.com/streem/pbandk/archive/v$KOTLIN_PLUGIN_VERSION.zip && unzip -o v$KOTLIN_PLUGIN_VERSION.zip
RUN cd pbandk-$KOTLIN_PLUGIN_VERSION && ./gradlew :protoc-gen-kotlin:protoc-gen-kotlin-jvm:assembleDist
RUN unzip pbandk-$KOTLIN_PLUGIN_VERSION/protoc-gen-kotlin/jvm/build/distributions/protoc-gen-kotlin-$KOTLIN_PLUGIN_VERSION.zip
RUN mkdir -p ./protoc-gen-kotlin/bin/ ./protoc-gen-kotlin/lib/
RUN cp -r ./protoc-gen-kotlin-$KOTLIN_PLUGIN_VERSION/bin/ ./protoc-gen-kotlin/
RUN cp -r ./protoc-gen-kotlin-$KOTLIN_PLUGIN_VERSION/lib/ ./protoc-gen-kotlin/

# Go plugin
FROM golang:1.16 as go-plugin
RUN GOBIN=/usr/local/bin go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
RUN GOBIN=/usr/local/bin go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest

# Scala plugin
FROM ubuntu:focal as scala-plugin
ENV SCALA_PLUGIN_VERSION "0.11.5"
RUN apt-get update && \
    apt-get -y install curl zip
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
COPY --from=swift-builder /usr/lib/x86_64-linux-gnu/libatomic.so.1 /usr/lib/x86_64-linux-gnu/libatomic.so.1
COPY --from=swift-builder /usr/lib/x86_64-linux-gnu/libstdc++.so.6 /usr/lib/x86_64-linux-gnu/libstdc++.so.6

# Java gRPC plugin
ENV JAVA_PLUGIN_VERSION "1.40.0"
RUN curl https://repo1.maven.org/maven2/io/grpc/protoc-gen-grpc-java/$JAVA_PLUGIN_VERSION/protoc-gen-grpc-java-$JAVA_PLUGIN_VERSION-linux-x86_64.exe -o /usr/local/bin/protoc-gen-grpc-java \
    && chmod +x /usr/local/bin/protoc-gen-grpc-java

# kotlin gRPC
# https://github.com/grpc/grpc-kotlin/tree/master/compiler
ENV KOTLIN_GRPC_VERSION "1.1.0"
RUN mkdir /kotlin-grpc && curl https://repo1.maven.org/maven2/io/grpc/protoc-gen-grpc-kotlin/$KOTLIN_GRPC_VERSION/protoc-gen-grpc-kotlin-$KOTLIN_GRPC_VERSION-jdk7.jar -o /kotlin-grpc/protoc-gen-grpc-kotlin.jar
COPY protoc-gen-grpc-kotlin /usr/local/bin/

COPY --from=go-plugin /usr/local/bin/protoc-gen-go /usr/local/bin/
COPY --from=go-plugin /usr/local/bin/protoc-gen-go-grpc /usr/local/bin/
COPY --from=scala-plugin /usr/local/bin/protoc-gen-scala /usr/local/bin/
COPY --from=pseudomuto/protoc-gen-doc /usr/local/bin/protoc-gen-doc /usr/local/bin/

# TypeScript
RUN npm i -g yarn
RUN yarn global add grpc-tools grpc_tools_node_protoc_ts

ENTRYPOINT ["prototool"]
