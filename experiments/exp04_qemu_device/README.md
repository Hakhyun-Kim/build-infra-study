# exp04 — qemu_device

## 질문

크로스 빌드한 바이너리를 **타깃 위에서 실행**하고 결과를 자동으로 수집할 수 있는가.
그리고 QEMU user 모드와 system 모드는 무엇이 다른가 — 어느 쪽이 실기기를 더 잘 흉내내는가.

이게 "가상 regression farm"의 최소 형태다. 실보드 없이 파이프라인 전체를 연습할 수 있고,
동시에 **가상 팜이 실기기를 어디까지 대신할 수 있는가**라는 진짜 질문의 출발점이 된다.

## 방법

```bash
sudo apt install -y qemu-user qemu-system-arm

# user 모드: 바이너리만 에뮬레이션, 커널은 호스트 것
qemu-aarch64 -L /usr/aarch64-linux-gnu \
  bazel-bin/experiments/exp01_bazel_hello/hello qemu

# system 모드: 커널부터 부팅한 진짜 가상 머신 (exp06 이미지 사용)
qemu-system-aarch64 -M virt -cpu cortex-a57 -nographic \
  -kernel <Image> -drive file=<rootfs>,format=raw ...
```

Bazel에 붙이기 — `--run_under`로 테스트를 QEMU 안에서 돌린다:

```bash
bazel test --platforms=//platforms:linux_aarch64 \
  --run_under="qemu-aarch64 -L /usr/aarch64-linux-gnu" \
  //experiments/exp01_bazel_hello:greeter_test
```

## 합격 기준

1. QEMU user 모드에서 `arch=aarch64`가 출력된다.
2. `bazel test --run_under=...`로 **aarch64 테스트가 호스트에서 통과**한다.
3. system 모드로 부팅한 이미지 안에서도 같은 바이너리가 돈다.
4. 세 경로(호스트 / QEMU user / QEMU system)의 **실행 시간을 비교 기록**한다.

## 관찰 (직접 채울 것)

| 실행 경로 | 준비 시간 | 테스트 실행 시간 | 실기기와 다른 점 |
|---|---|---|---|
| 호스트 x86_64 | | | 아키텍처 자체가 다름 |
| QEMU user | | | 커널·드라이버·타이밍 없음 |
| QEMU system | | | 실제 주변장치·타이밍 없음 |
| 실기기 (나중에) | | | - |

## 알아둘 것

- **user 모드로는 못 잡는 것**: 커널 드라이버, 인터럽트, 실시간성, 메모리 대역폭,
  실제 센서/버스. 그래서 가상 팜은 실기기 팜을 대체하지 못하고 **앞단에서 거르는** 역할이다.
- 이 구분이 테스트 계층 사다리의 근거다 → [ch3 노트](../../notes/ch3-regression-farm/README.md).
- `--run_under`는 sanitizer, valgrind, 프로파일러를 붙일 때도 같은 방식으로 쓰인다.

## 결과

미실행.
