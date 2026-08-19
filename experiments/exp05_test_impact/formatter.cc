#include "experiments/exp05_test_impact/formatter.h"

#include "experiments/exp01_bazel_hello/greeter.h"

namespace exp05 {

std::string Banner(const std::string& name) {
  return "[[ " + exp01::Greet(name) + " ]]";
}

}  // namespace exp05
