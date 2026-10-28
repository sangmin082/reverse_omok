# 리버스 오목 (Reverse Omok)

자기 돌 5개를 먼저 이으면 **지는** 오목 iOS 앱입니다. SwiftUI로 만들었고 iOS 17 이상을 지원합니다.

## 규칙

- 흑이 먼저 두고 번갈아 한 수씩 둡니다.
- 가로·세로·대각선으로 자기 돌을 **5개 이상** 연속으로 놓으면 패배합니다(6목 이상 포함).
- 판이 가득 찰 때까지 아무도 5목을 만들지 않으면 무승부입니다.
- 둘 수 있는 칸이 전부 5목 자리라면 어쩔 수 없이 두어야 하고, 그대로 집니다.

## 기능

- 컴퓨터 대전(쉬움/보통/어려움, 흑·백 선택)과 한 기기에서 둘이 하는 대전
- 판 크기 9/11/13/15줄
- 두면 지는 칸 표시, 착수 확인(두 번 탭), 무르기
- 진행 중인 판 자동 저장과 이어하기
- 난이도별 전적, 진동 피드백, 다크 모드

## 구조

```
App/ReverseOmok/          SwiftUI 앱 (화면, 뷰모델, 저장)
Packages/OmokCore/        UI 없는 게임 로직과 AI (Swift 패키지, 리눅스에서도 테스트 가능)
ReverseOmok.xcodeproj     Xcode 프로젝트
project.yml               XcodeGen 예비 설정
docs/PLAN.md              개발 계획과 설계 메모
```

## 실행

1. 맥에서 Xcode 16 이상으로 `ReverseOmok.xcodeproj`를 엽니다.
2. 타깃 **ReverseOmok** → Signing & Capabilities에서 팀을 고릅니다(개인 Apple ID도 가능).
3. 시뮬레이터나 아이폰을 골라 실행(⌘R)합니다.

프로젝트 파일이 열리지 않으면 `brew install xcodegen && xcodegen`으로 다시 만들면 됩니다.

## 로직 테스트

```sh
cd Packages/OmokCore
swift test
# AI 난이도끼리 대국 (오래 걸림)
OMOK_BENCH=1 OMOK_SIZE=9 OMOK_GAMES=4 swift test -c release --filter StrengthBenchmark
```
