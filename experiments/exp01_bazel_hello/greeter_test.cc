// Deliberately dependency-free: no gtest.
// exp01 is about Bazel mechanics, and every external dependency added here is
// one more thing that can fail for reasons unrelated to what is being learned.
// A cc_test target is simply "a binary whose exit code is the verdict".

#include <cstdio>
#include <string>

#include "experiments/exp01_bazel_hello/greeter.h"

namespace {

int failures = 0;

void Expect(const std::string& actual, const std::string& expected,
            const char* label) {
  if (actual != expected) {
    std::printf("FAIL %s: got '%s', want '%s'\n", label, actual.c_str(),
                expected.c_str());
    ++failures;
  }
}

}  // namespace

int main() {
  Expect(exp01::Greet("bazel"), "hello, bazel", "Greet(name)");
  Expect(exp01::Greet(""), "hello, world", "Greet(empty)");

  const std::string arch = exp01::TargetArch();
  if (arch == "unknown") {
    std::printf("FAIL TargetArch: unknown architecture\n");
    ++failures;
  }

  std::printf("arch=%s failures=%d\n", arch.c_str(), failures);
  return failures == 0 ? 0 : 1;
}
