# 리버스 오목 (Reverse Omok)

자기 돌을 먼저 이으면 **지는** 오목 iOS 앱입니다. 7줄 판에서 3개를 이으면 패배합니다. SwiftUI로 만들었고 iOS 17 이상을 지원합니다.

## 규칙

- 흑이 먼저 두고 번갈아 한 수씩 둡니다.
- 7줄 판에서 가로·세로·대각선으로 자기 돌을 **3개 이상** 연속으로 놓으면 패배합니다.
- 판이 가득 찰 때까지 아무도 줄을 만들지 않으면 무승부입니다.
- 둘 수 있는 칸이 전부 줄이 완성되는 자리라면 어쩔 수 없이 두어야 하고, 그대로 집니다.

## 기능

- 컴퓨터 대전(쉬움/보통/어려움, 흑·백 선택)과 한 기기에서 둘이 하는 대전
- 직접 두어 보며 배우는 튜토리얼(처음 켤 때 자동으로 시작)
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

## 빌드와 배포

맥 없이 GitHub Actions로 빌드하고 TestFlight에 올립니다. 자세한 내용은 [docs/RELEASE.md](docs/RELEASE.md)를 보세요.

- 푸시할 때마다 `CI`가 테스트와 앱 빌드를 확인합니다.
- Actions 탭 → `TestFlight` → Run workflow를 누르면 아이폰의 TestFlight 앱으로 설치할 수 있습니다.

## 로직 테스트

```sh
cd Packages/OmokCore
swift test
# AI 난이도끼리 대국 (오래 걸림)
OMOK_BENCH=1 OMOK_SIZE=9 OMOK_GAMES=4 swift test -c release --filter StrengthBenchmark
```
