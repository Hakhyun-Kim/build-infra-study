#ifndef EXP05_FORMATTER_H_
#define EXP05_FORMATTER_H_

#include <string>

namespace exp05 {

// Wraps exp01's greeting in a banner. Exists so that this package genuinely
// depends on //experiments/exp01_bazel_hello:greeter - without a real edge in
// the graph there is nothing for impact analysis to analyse.
std::string Banner(const std::string& name);

}  // namespace exp05

#endif  // EXP05_FORMATTER_H_
