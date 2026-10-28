# 빌드와 배포 (맥 없이 GitHub Actions로)

## 구성

| 워크플로 | 언제 | 하는 일 | 시크릿 |
|---|---|---|---|
| `CI` | 모든 푸시와 PR | 코어 테스트, 시뮬레이터용 앱 빌드 | 필요 없음 |
| `TestFlight` | Actions 탭에서 Run workflow, 또는 `v*` 태그 푸시 | 번들 ID 등록, 빌드 번호 결정, 아카이브, 서명, 업로드 | 4개 (조직에 한 번만) |

서명 방식:
- 애플의 **클라우드 서명**(`-allowProvisioningUpdates` + API 키)을 씁니다.
- 인증서(.p12)나 프로비저닝 프로파일을 만들거나 시크릿에 넣을 필요가 없습니다. 인증서와 프로파일은 애플이 알아서 관리합니다.

## 평생 한 번만 하는 설정 (약 10분)

모든 앱 저장소가 같은 시크릿을 쓰도록 **GitHub 조직(무료)**에 시크릿을 한 번만 등록합니다.

### 1. App Store Connect API 키 만들기
1. https://appstoreconnect.apple.com/access/integrations/api 로 갑니다.
   - 메뉴 경로: 사용자 및 액세스 → 통합 → App Store Connect API → **팀 키**
2. 키를 생성합니다.
   - 이름: `GitHub Actions`
   - 액세스: **관리(Admin)**. 클라우드 서명 인증서를 쓰려면 관리 권한이 필요합니다.
3. 아래 세 가지를 적어 둡니다.
   - **발급자 ID**(Issuer ID): 페이지 위쪽에 있습니다.
   - **키 ID**
   - `AuthKey_XXXX.p8` 파일: **한 번만** 다운로드할 수 있습니다.
4. 팀 ID를 확인합니다. https://developer.apple.com/account → 멤버십 세부 사항 → **팀 ID** (10자리)

### 2. GitHub 조직 만들고 시크릿 등록
1. https://github.com/organizations/plan 에서 **Free**를 골라 조직을 만듭니다. 예: `sangmin082-apps`
2. 조직 **Settings → Secrets and variables → Actions → New organization secret**에서 4개를 추가합니다. 각 시크릿의 Repository access는 **All repositories**로 둡니다.

   | 이름 | 값 |
   |---|---|
   | `ASC_KEY_ID` | 키 ID |
   | `ASC_ISSUER_ID` | 발급자 ID |
   | `ASC_KEY_P8` | `.p8` 파일을 메모장으로 열어 `-----BEGIN PRIVATE KEY-----`부터 끝까지 전체 |
   | `APPLE_TEAM_ID` | 팀 ID |

3. 이 저장소를 조직으로 옮깁니다: 저장소 **Settings → General → Danger Zone → Transfer**
4. Claude GitHub 앱을 조직에도 설치합니다: https://github.com/apps/claude/installations/select_target

> 무료 조직의 시크릿은 **공개 저장소**에서만 쓸 수 있습니다. 비공개 앱 저장소를 쓰려면 조직을 Team 요금제로 올리거나, 저장소마다 같은 4개를 저장소 시크릿으로 넣어야 합니다.

## 앱마다 하는 일 (약 1~2분)

1. Actions 탭 → **TestFlight → Run workflow**를 누릅니다.
2. 처음 실행하면 번들 ID를 자동으로 등록한 뒤 "App Store Connect에 앱을 만들어 주세요"라며 멈춥니다.
   - 애플이 API로 앱 생성을 막아 두어서, 이 단계만 사람이 해야 합니다.
   - 실행 요약(Summary)에 이름, 번들 ID, SKU가 표로 나오므로 그대로 입력하면 됩니다.
3. 다시 **Run workflow**를 누르면 업로드됩니다.
4. 처음 한 번만: App Store Connect → 앱 → TestFlight → **내부 테스트 그룹**을 만들고 나를 추가합니다.
5. 아이폰의 TestFlight 앱에서 설치합니다.

빌드 번호는 TestFlight에 있는 가장 큰 번호 + 1로 자동으로 정해집니다. 버전(1.0 등)은 프로젝트의 `MARKETING_VERSION`을 따릅니다.
