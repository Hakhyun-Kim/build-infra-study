#ifndef EXP01_GREETER_H_
#define EXP01_GREETER_H_

#include <string>

namespace exp01 {

// Returns a greeting for |name|. Empty name falls back to "world".
std::string Greet(const std::string& name);

// Returns the target architecture this binary was compiled for.
// Used by exp03/exp04 to prove a cross-compiled binary really is aarch64.
std::string TargetArch();

}  // namespace exp01

#endif  // EXP01_GREETER_H_
