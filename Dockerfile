# Swift plugin
FROM swift:5.3-focal as swift-builder

RUN apt-get -q update && \
    apt-get -q install -y \
    wget make \
    && rm -r /var/lib/apt/lists/*

RUN wget -qO- https://github.com/grpc/grpc-swift/archive/1.0.0.tar.gz | gunzip | tar x -C / \
    && make -C /grpc-swift-1.0.0 plugins \
    && cp /grpc-swift-1.0.0/protoc*swift /usr/local/bin/ \
	&& rm -rf /grpc-swift-1.0.0

FROM scratch AS swift-plugin
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

# Kotlin plugin
FROM openjdk:8 as kotlin-plugin
ENV KOTLIN_PLUGIN_VERSION "0.9.1"
RUN apt-get update && \
    apt-get -y install curl zip
RUN curl -LO https://github.com/streem/pbandk/archive/v$KOTLIN_PLUGIN_VERSION.zip && unzip -o v$KOTLIN_PLUGIN_VERSION.zip
RUN cd pbandk-$KOTLIN_PLUGIN_VERSION && ./gradlew :protoc-gen-kotlin:protoc-gen-kotlin-jvm:assembleDist
RUN unzip pbandk-$KOTLIN_PLUGIN_VERSION/protoc-gen-kotlin/jvm/build/distributions/protoc-gen-kotlin-$KOTLIN_PLUGIN_VERSION.zip
RUN mkdir -p ./protoc-gen-kotlin/bin/ ./protoc-gen-kotlin/lib/
RUN cp -r ./protoc-gen-kotlin-$KOTLIN_PLUGIN_VERSION/bin/ ./protoc-gen-kotlin/
RUN cp -r ./protoc-gen-kotlin-$KOTLIN_PLUGIN_VERSION/lib/ ./protoc-gen-kotlin/

# Go plugin
FROM golang:1.15 as go-plugin
RUN go get github.com/golang/protobuf/protoc-gen-go
RUN go build -o /usr/local/bin/protoc-gen-go github.com/golang/protobuf/protoc-gen-go

# Scala plugin
FROM ubuntu:16.04 as scala-plugin
ENV SCALA_PLUGIN_VERSION "0.10.11"
RUN apt-get update && \
    apt-get -y install curl zip
RUN curl -LO https://github.com/scalapb/ScalaPB/releases/download/v$SCALA_PLUGIN_VERSION/protoc-gen-scala-$SCALA_PLUGIN_VERSION-linux-x86_64.zip && unzip -o protoc-gen-scala-$SCALA_PLUGIN_VERSION-linux-x86_64.zip
RUN cp ./protoc-gen-scala /usr/local/bin/

# Final builder
FROM uber/prototool as builder
RUN apk add --update --no-cache make openjdk8-jre && \
    rm -rf /var/cache/apk/*
COPY --from=swift-plugin / /
COPY --from=kotlin-plugin ./protoc-gen-kotlin/bin/protoc-gen-kotlin /usr/local/bin/
COPY --from=kotlin-plugin ./protoc-gen-kotlin/lib /usr/local/lib/
COPY --from=go-plugin /usr/local/bin/protoc-gen-go /usr/local/bin/
COPY --from=scala-plugin /usr/local/bin/protoc-gen-scala /usr/local/bin/
COPY --from=pseudomuto/protoc-gen-doc /usr/local/bin/protoc-gen-doc /usr/local/bin/

ENTRYPOINT ["prototool"]
