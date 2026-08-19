#include "experiments/exp01_bazel_hello/greeter.h"

namespace exp01 {

std::string Greet(const std::string& name) {
  return "hello, " + (name.empty() ? std::string("world") : name);
}

std::string TargetArch() {
#if defined(__aarch64__)
  return "aarch64";
#elif defined(__x86_64__)
  return "x86_64";
#else
  return "unknown";
#endif
}

}  // namespace exp01
