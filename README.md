# Glow Box 한국어 패치

Steam판 **Glow Box** 비공식 한국어 패치 저장소입니다.

현재 정식 배포 버전은 `v1.0.2`이며 Steam 2026-08-30 빌드에서 확인했습니다.


<img width="850" height="478" alt="image" src="https://github.com/user-attachments/assets/2678d919-3fe1-40e4-9076-085201100ce1" />
<img width="850" height="478" alt="image" src="https://github.com/user-attachments/assets/e0fb3990-a0a2-4e96-9b19-1f7f39678212" />

## 배포본

[최신 릴리스](https://github.com/etashi04/Glow-Box/releases/latest)에서 다운로드할 수 있습니다.

- `GlowBox_Korean_Patch_v1.0.2.zip`: GUI 설치기를 통한 자동 설치·원본 복구
- `GlowBox_Korean_Patch_Manual_v1.0.2.zip`: 게임 설치 폴더에 직접 복사
- `SHA256SUMS.txt`: 배포 ZIP 무결성 확인용 체크섬

게임을 종료한 상태에서 설치하세요. 자동판 ZIP을 풀면 설치 EXE와 사용자용 설치 안내문을 확인할 수 있습니다.

## 자동 설치

1. 자동 설치 ZIP을 모두 압축 해제합니다.
2. `GlowBox_Korean_Patch_v1.0.2.exe`를 실행합니다.
3. 자동으로 찾은 게임 폴더를 확인하고 **한국어 패치 설치**를 누릅니다. 찾지 못하면 Steam의 `GlowMachine` 폴더를 직접 선택합니다.
4. 게임을 실행하고 언어 설정에서 **한국어**를 선택합니다.

## 수동 설치

1. 수동 설치 ZIP을 모두 압축 해제하고 게임과 Steam을 종료합니다.
2. 게임 폴더의 `Glow Box_Data/StreamingAssets/aa/StandaloneWindows64`에서 안내문의 대상 원본 번들 5개를 먼저 백업합니다.
3. ZIP의 `Glow Box_Data` 폴더를 게임 설치 폴더에 복사하여 병합·덮어씁니다.
4. 게임을 실행하고 언어 설정에서 **한국어**를 선택합니다.

## 복구

- 자동판: 같은 설치기에서 **원본 복구**를 선택합니다. `KoreanPatch_Backup` 폴더는 복구 전까지 삭제하지 마세요.
- 수동판: 백업한 원본 번들 5개를 원래 위치에 덮어씁니다. 백업이 없다면 Steam 파일 무결성 검사를 실행합니다.

## 주의

- 비공식 한국어 팬 패치입니다.
- 게임 원본, 추출 데이터, 빌드 산출물 및 외부 도구는 저장소에 포함하지 않습니다.
- 게임 업데이트 후 호환되지 않을 수 있습니다.
- Windows에서 알 수 없는 앱 경고가 표시될 수 있습니다. 배포 파일은 `SHA256SUMS.txt`로 무결성을 확인할 수 있습니다.
- 수동판은 원본 해시 확인이나 실패 시 자동 복구를 제공하지 않습니다.
- Steam 파일 무결성 검사를 실행하면 한국어 패치가 제거될 수 있습니다.
