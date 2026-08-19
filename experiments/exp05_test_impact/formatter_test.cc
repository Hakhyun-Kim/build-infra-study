#include <cstdio>
#include <string>

#include "experiments/exp05_test_impact/formatter.h"

int main() {
  const std::string got = exp05::Banner("impact");
  const std::string want = "[[ hello, impact ]]";
  if (got != want) {
    std::printf("FAIL: got '%s', want '%s'\n", got.c_str(), want.c_str());
    return 1;
  }
  std::printf("ok\n");
  return 0;
}
