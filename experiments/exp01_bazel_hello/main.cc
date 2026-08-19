#include <cstdio>
#include <string>

#include "experiments/exp01_bazel_hello/greeter.h"

// Prints the greeting and the architecture it was built for.
// exp04 runs this exact binary under QEMU and asserts arch == aarch64.
int main(int argc, char** argv) {
  const std::string name = (argc > 1) ? argv[1] : "";
  std::printf("%s\n", exp01::Greet(name).c_str());
  std::printf("arch=%s\n", exp01::TargetArch().c_str());
  return 0;
}
