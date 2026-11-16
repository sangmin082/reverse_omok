#!/usr/bin/env python3
"""App Store Connect API로 배포 준비를 자동화한다.

- 번들 ID가 없으면 등록한다.
- 앱 레코드가 있는지 확인한다(애플이 API로 앱 생성을 막아 두어 이것만은 웹에서 한 번 만들어야 한다).
- TestFlight에 올라간 가장 큰 빌드 번호 + 1을 다음 빌드 번호로 정한다.

환경 변수: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH
"""

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

import jwt

API = "https://api.appstoreconnect.apple.com"


def token():
    with open(os.environ["ASC_KEY_PATH"]) as f:
        key = f.read()
    now = int(time.time())
    return jwt.encode(
        {"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"},
        key,
        algorithm="ES256",
        headers={"kid": os.environ["ASC_KEY_ID"], "typ": "JWT"},
    )


def call(method, path, params=None, body=None, soft=False, empty_ok=False):
    url = API + path
    if params:
        url += "?" + urllib.parse.urlencode(params)
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", "Bearer " + token())
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req) as res:
            raw = res.read()
            if not raw:
                return {} if empty_ok else None
            return json.loads(raw)
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")
        if soft:
            print(f"::warning::App Store Connect API {method} {path} 실패 ({e.code}): {detail}")
            return None
        sys.exit(f"::error::App Store Connect API {method} {path} 실패 ({e.code}): {detail}")


def ensure_bundle_id(identifier, name):
    found = call("GET", "/v1/bundleIds", {"filter[identifier]": identifier, "limit": 200})["data"]
    if any(b["attributes"]["identifier"] == identifier for b in found):
        print(f"번들 ID 있음: {identifier}")
        return
    ascii_name = "".join(ch for ch in name if ch.isascii() and (ch.isalnum() or ch == " ")).strip()
    call("POST", "/v1/bundleIds", body={"data": {"type": "bundleIds", "attributes": {
        "identifier": identifier,
        "name": ascii_name or identifier.split(".")[-1],
        "platform": "IOS",
    }}})
    print(f"번들 ID 등록함: {identifier}")


def report_certificates():
    """이 API 키로 보이는 배포 인증서를 출력한다. match 인증서 문제를 진단하는 용도."""
    certs = call("GET", "/v1/certificates", {"limit": 200})["data"]
    dist = [c for c in certs if c["attributes"]["certificateType"] in ("DISTRIBUTION", "IOS_DISTRIBUTION")]
    print(f"보이는 인증서 {len(certs)}개, 그중 배포 인증서 {len(dist)}개")
    for c in dist:
        a = c["attributes"]
        print(f"  {c['id']}  {a['certificateType']}  {a.get('name')}  만료 {a.get('expirationDate')}")


def find_app(identifier):
    apps = call("GET", "/v1/apps", {"filter[bundleId]": identifier})["data"]
    return next((a for a in apps if a["attributes"]["bundleId"] == identifier), None)


def ensure_game_center(app_id, bundle_id):
    """온라인 대국에 필요한 Game Center를 켠다. 실패해도 배포는 계속한다."""
    capabilities = call("GET", "/v1/bundleIds", {"filter[identifier]": bundle_id, "include": "bundleIdCapabilities"}, soft=True)
    if capabilities is not None:
        bundle = next((b for b in capabilities["data"] if b["attributes"]["identifier"] == bundle_id), None)
        enabled = {c["attributes"]["capabilityType"] for c in capabilities.get("included", [])}
        if bundle and "GAME_CENTER" not in enabled:
            created = call("POST", "/v1/bundleIdCapabilities", body={"data": {
                "type": "bundleIdCapabilities",
                "attributes": {"capabilityType": "GAME_CENTER", "settings": []},
                "relationships": {"bundleId": {"data": {"type": "bundleIds", "id": bundle["id"]}}},
            }}, soft=True)
            print("번들 ID에 Game Center 기능을 켰습니다." if created else "번들 ID의 Game Center 기능을 켜지 못했습니다.")
        else:
            print("번들 ID의 Game Center 기능: 켜져 있음")

    detail = call("GET", f"/v1/apps/{app_id}/gameCenterDetail", soft=True)
    if detail is not None and detail.get("data"):
        print("앱의 Game Center: 켜져 있음")
        return
    created = call("POST", "/v1/gameCenterDetails", body={"data": {
        "type": "gameCenterDetails",
        "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
    }}, soft=True)
    print("앱의 Game Center를 켰습니다." if created else "앱의 Game Center를 켜지 못했습니다. App Store Connect에서 직접 켜야 할 수 있습니다.")


def prepare_review(app_id):
    """심사 제출 전 준비: 최신 빌드 연결, 버전의 Game Center 사용, 연령 등급. 실패해도 계속한다."""
    versions = call("GET", f"/v1/apps/{app_id}/appStoreVersions", {"filter[platform]": "IOS", "limit": 10}, soft=True)
    editable = ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED", "INVALID_BINARY")
    version = next((v for v in (versions or {}).get("data", []) if v["attributes"].get("appStoreState") in editable), None)
    if version is None:
        summary("- 수정할 수 있는 App Store 버전을 찾지 못했습니다.")
        return
    version_id = version["id"]
    summary(f"- App Store 버전: {version['attributes'].get('versionString')} ({version['attributes'].get('appStoreState')})")

    builds = call("GET", "/v1/builds", {
        "filter[app]": app_id, "filter[processingState]": "VALID", "filter[expired]": "false",
        "sort": "-uploadedDate", "limit": 1,
    }, soft=True)
    build = ((builds or {}).get("data") or [None])[0]
    if build:
        linked = call("PATCH", f"/v1/appStoreVersions/{version_id}/relationships/build",
                      body={"data": {"type": "builds", "id": build["id"]}}, soft=True, empty_ok=True)
        summary(f"- 빌드 {build['attributes']['version']} 연결: {'완료' if linked is not None else '실패'}")
    else:
        summary("- 연결할 수 있는 처리 완료 빌드가 없습니다.")

    detail = call("GET", f"/v1/apps/{app_id}/gameCenterDetail", soft=True)
    if detail and detail.get("data"):
        existing = call("GET", f"/v1/appStoreVersions/{version_id}/gameCenterAppVersion", soft=True)
        if existing and existing.get("data"):
            enabled = existing["data"]["attributes"].get("enabled")
            if not enabled:
                call("PATCH", f"/v1/gameCenterAppVersions/{existing['data']['id']}", body={"data": {
                    "type": "gameCenterAppVersions", "id": existing["data"]["id"], "attributes": {"enabled": True},
                }}, soft=True)
            summary("- 이 버전의 Game Center: 켜짐")
        else:
            created = call("POST", "/v1/gameCenterAppVersions", body={"data": {
                "type": "gameCenterAppVersions",
                "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}}},
            }}, soft=True)
            summary(f"- 이 버전의 Game Center 켜기: {'완료' if created else '실패 (웹에서 직접 켜야 합니다)'}")

    infos = call("GET", f"/v1/apps/{app_id}/appInfos", soft=True)
    info = next((i for i in (infos or {}).get("data", []) if i["attributes"].get("appStoreState") in editable + (None,)), None)
    info = info or ((infos or {}).get("data") or [None])[0]
    if info:
        rating = call("GET", f"/v1/appInfos/{info['id']}/ageRatingDeclaration", soft=True)
        if rating and rating.get("data"):
            attrs = rating["data"]["attributes"]
            # 폭력, 도박, 채팅, 광고 등 해당 사항이 전혀 없는 보드게임이다.
            booleans = {"gambling", "unrestrictedWebAccess", "lootBox", "advertising", "messagingAndChat",
                        "userGeneratedContent", "parentalControls", "ageAssurance", "healthOrWellnessTopics",
                        "seventeenPlus", "socialNetworking"}
            skip = {"kidsAgeBand", "ageRatingOverride", "ageRatingOverrideV2", "koreaAgeRatingOverride",
                    "developerAgeRatingInfoUrl"}
            wanted = {k: (False if k in booleans else "NONE") for k in attrs if k not in skip}
            patched = call("PATCH", f"/v1/ageRatingDeclarations/{rating['data']['id']}", body={"data": {
                "type": "ageRatingDeclarations", "id": rating["data"]["id"], "attributes": wanted,
            }}, soft=True)
            summary(f"- 연령 등급(해당 사항 없음으로 응답): {'완료' if patched else '실패 (웹에서 직접 답해야 합니다)'}")


def next_build_number(app_id, minimum):
    builds = call("GET", "/v1/builds", {"filter[app]": app_id, "sort": "-version", "limit": 1})["data"]
    latest = max((int(b["attributes"]["version"]) for b in builds if b["attributes"]["version"].isdigit()), default=0)
    return max(latest + 1, minimum)


def summary(text):
    path = os.environ.get("GITHUB_STEP_SUMMARY")
    if path:
        with open(path, "a") as f:
            f.write(text + "\n")
    print(text)


def output(name, value):
    path = os.environ.get("GITHUB_OUTPUT")
    if path:
        with open(path, "a") as f:
            f.write(f"{name}={value}\n")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--bundle-id", required=True)
    parser.add_argument("--name", required=True)
    parser.add_argument("--min-build", type=int, default=1)
    parser.add_argument("--prepare-review", action="store_true", help="빌드 연결 등 심사 제출 준비만 한다")
    args = parser.parse_args()

    if args.prepare_review:
        app = find_app(args.bundle_id)
        if app is None:
            sys.exit(f"::error::App Store Connect에 {args.bundle_id} 앱이 없습니다.")
        summary("## 심사 제출 준비")
        prepare_review(app["id"])
        return

    ensure_bundle_id(args.bundle_id, args.name)
    report_certificates()

    app = find_app(args.bundle_id)
    if app is None:
        summary(
            "## App Store Connect에 앱을 한 번 만들어 주세요\n\n"
            "애플이 API로 앱 생성을 허용하지 않아 이 단계만 웹에서 해야 합니다(약 1분).\n\n"
            "1. https://appstoreconnect.apple.com/apps 에서 **+ → 신규 앱**\n"
            "2. 아래 값을 그대로 입력\n\n"
            f"| 항목 | 값 |\n|---|---|\n| 플랫폼 | iOS |\n| 이름 | {args.name} |\n"
            f"| 기본 언어 | 한국어 |\n| 번들 ID | {args.bundle_id} |\n| SKU | {args.bundle_id} |\n"
            "| 사용자 액세스 | 전체 액세스 |\n\n"
            "3. 이 워크플로를 다시 실행하세요."
        )
        sys.exit(f"::error::App Store Connect에 {args.bundle_id} 앱이 없습니다. 실행 요약(Summary)의 안내를 따라 주세요.")

    ensure_game_center(app["id"], args.bundle_id)
    build = next_build_number(app["id"], args.min_build)
    print(f"앱 ID {app['id']}, 다음 빌드 번호 {build}")
    output("app_id", app["id"])
    output("build_number", build)


if __name__ == "__main__":
    main()
