"""aarch64 크로스 컴파일용 cc_toolchain_config.

시스템에 설치된 gcc-aarch64-linux-gnu 를 절대 경로로 가리킨다.
빠르게 동작하지만 hermetic 하지 않다 - 호스트에 이 패키지가 깔려 있어야만
빌드가 된다. 그 대가가 무엇인지 보는 것이 exp03 의 A 경로다.
"""

load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "ACTION_NAMES")
load(
    "@bazel_tools//tools/cpp:cc_toolchain_config_lib.bzl",
    "feature",
    "flag_group",
    "flag_set",
    "tool_path",
)

_COMPILE_ACTIONS = [
    ACTION_NAMES.c_compile,
    ACTION_NAMES.cpp_compile,
    ACTION_NAMES.linkstamp_compile,
    ACTION_NAMES.assemble,
    ACTION_NAMES.preprocess_assemble,
    ACTION_NAMES.cpp_header_parsing,
    ACTION_NAMES.cpp_module_compile,
    ACTION_NAMES.cpp_module_codegen,
]

_LINK_ACTIONS = [
    ACTION_NAMES.cpp_link_executable,
    ACTION_NAMES.cpp_link_dynamic_library,
    ACTION_NAMES.cpp_link_nodeps_dynamic_library,
]

_PREFIX = "/usr/bin/aarch64-linux-gnu-"

def _impl(ctx):
    tool_paths = [
        tool_path(name = "gcc", path = _PREFIX + "gcc"),
        tool_path(name = "cpp", path = _PREFIX + "cpp"),
        tool_path(name = "ar", path = _PREFIX + "ar"),
        tool_path(name = "ld", path = _PREFIX + "ld"),
        tool_path(name = "nm", path = _PREFIX + "nm"),
        tool_path(name = "objdump", path = _PREFIX + "objdump"),
        tool_path(name = "strip", path = _PREFIX + "strip"),
        tool_path(name = "gcov", path = _PREFIX + "gcov"),
    ]

    compile_flags = feature(
        name = "default_compile_flags",
        enabled = True,
        flag_sets = [flag_set(
            actions = _COMPILE_ACTIONS,
            flag_groups = [flag_group(flags = [
                "-no-canonical-prefixes",
                "-fno-canonical-system-headers",
                "-Wall",
            ])],
        )],
    )

    # gcc 로 링크하므로 C++ 표준 라이브러리를 명시해준다.
    link_flags = feature(
        name = "default_link_flags",
        enabled = True,
        flag_sets = [flag_set(
            actions = _LINK_ACTIONS,
            flag_groups = [flag_group(flags = ["-lstdc++", "-lm"])],
        )],
    )

    return cc_common.create_cc_toolchain_config_info(
        ctx = ctx,
        toolchain_identifier = "aarch64-linux-gnu",
        host_system_name = "x86_64-unknown-linux-gnu",
        target_system_name = "aarch64-unknown-linux-gnu",
        target_cpu = "aarch64",
        target_libc = "glibc",
        compiler = "gcc",
        abi_version = "unknown",
        abi_libc_version = "unknown",
        tool_paths = tool_paths,
        features = [compile_flags, link_flags],
        # 이 목록을 안 주면 Bazel 이 시스템 헤더를 '선언되지 않은 include' 로
        # 판정해 빌드를 거부한다. 크로스 툴체인 설정에서 가장 흔한 첫 실패.
        cxx_builtin_include_directories = [
            "/usr/lib/gcc-cross/aarch64-linux-gnu",
            "/usr/aarch64-linux-gnu/include",
            "/usr/include",
        ],
    )

cc_toolchain_config = rule(
    implementation = _impl,
    attrs = {},
    provides = [CcToolchainConfigInfo],
)
