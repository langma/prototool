# Prototool docker image

Contains `uber/prototool` as base image, and builds the following language support on top of it:

- [Swift](https://github.com/grpc/grpc-swift)
- [Kotlin](https://github.com/streem/pbandk)
- [Go](https://github.com/golang/protobuf)
- [Scala](https://github.com/scalapb/ScalaPB)

The `Dockerimage` is mostly a copy of [moia-dev/prototool](https://github.com/moia-dev/prototool-docker), biggest change being the `grpc-swift` library
instead of the plain [Apple one](https://github.com/apple/swift-protobuf) to support gRPC generation.

JS and TS copied and modified to work from [here](https://github.com/citilinkru/prototool).
