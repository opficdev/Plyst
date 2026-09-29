# Plyst

> 복사한 내용을 모아 정리하고 필요한 항목을 검색하거나 차례로 붙여넣기 위한 UIKit 기반 앱<br>
> 텍스트와 이미지를 하나의 클립 기록으로 관리하도록 개발 중인 프로젝트

## 프로젝트 개요

복사한 텍스트와 이미지를 모으고 이름과 메모, 고정 여부로 정리해 다시 사용할 수 있도록 만드는 앱

현재는 UIKit 프로젝트 기반, ReactorKit 화면 상태 흐름, 클립 모델과 SQLiteData 기반 로컬 저장소를 구성한 단계

- 텍스트와 이미지 클립을 하나의 기록 모델로 표현
- 클립 원문과 이미지 파일 메타데이터를 화면과 분리
- 이름과 메모, 고정 여부의 편집과 마지막 사용 시각 갱신을 구분

## 아키텍처

- `Plyst.xcodeproj`의 앱 타깃 안에서 역할별 폴더와 화면별 폴더로 코드 구분
- `App`, `Model`, `Service`, `Feature`, `Shared`를 단수형 폴더 이름으로 사용
- `Feature`는 화면 단위로 나누고 해당 ViewController와 Reactor를 같은 폴더에 배치
- ViewController는 사용자 입력을 Action으로 전달하고 State를 화면에 표시하며, Reactor는 요청 처리와 상태 변경을 담당
- 외부 자원 접근과 저장은 `Service`, 클립 값과 검증, 변경과 정렬 규칙은 `Model`로 구분
- UIKit 코드로 화면을 구성하고 `SceneDelegate`에서 `UIWindow`와 초기 `UINavigationController` 연결
- ReactorKit의 `Action`, `Mutation`, `State`로 화면 상태를 관리하고 ViewController는 상태를 비동기로 구독
- 서비스의 `async/await`와 `AsyncStream`을 `ReactorEffect`에서 RxSwift로 연결
- 클립 모델은 `Foundation` 값 타입으로 구성하고 저장 서비스 계약과 SQLite 구현은 `Service/Clip/Storage`에 배치
- `ClipStorageService`가 저장과 조회, 변경 관찰 계약을 정의하고 `SQLiteClipStorageService`가 SQLiteData로 구현
- 이미지 원본 파일의 저장과 삭제를 담당하는 코드는 `Service/Clip/Image`에 배치
- 클립보드 읽기와 텍스트 클립 저장을 담당하는 코드는 `Service/Clip/Clipboard`에 배치

## 주요 기능

### 클립 모델

- `ClipContent`로 텍스트와 이미지 구분
- URL을 별도 유형으로 나누지 않고 텍스트 원문으로 표현
- 식별자, 이름, 고정 여부, 메모, 저장 시각, 마지막 사용 시각 정의
- 이미지 파일 식별자, 콘텐츠 형식, 해상도, 바이트 크기 표현
- 공백뿐인 텍스트와 유효하지 않은 이미지 메타데이터 검사

### 클립 저장 서비스 계약

- 목록 조회, 단건 조회, 추가, 수정, 삭제를 위한 비동기 인터페이스 정의
- 추가, 수정, 삭제 결과를 전달하는 `AsyncStream` 이벤트 계약 정의
- 상세 정보 편집 시 마지막 사용 시각을 유지하는 `ClipUpdate` 제공
- 저장 시각 또는 마지막 사용 시각을 기준으로 정렬하고 동률 순서 고정
- 화면과 저장 방식에 의존하지 않는 오류 모델 정의

### 로컬 저장소

- 주입받은 파일 경로에서 SQLiteData로 텍스트와 이미지 메타데이터 저장
- 기존 `ClipUpdate`와 `ClipSortOrder`를 적용해 수정 규칙과 정렬 순서 보존
- 트랜잭션 확정 후에만 추가, 수정, 삭제 이벤트 발행
- 저장 실패와 손상 데이터는 `ClipStorageError`로 전달

### 화면 상태 관리

- ViewController 하나가 Reactor 하나의 상태를 비동기로 구독
- UIKit의 `UIAction`에서 Reactor의 Action 전달
- 화면 해제 시 상태 구독 `Task` 취소
- 비동기 요청과 스트림을 Reactor의 Mutation 흐름으로 연결

---

## 기술 스택

| 구분 | 스택 |
| --- | --- |
| 최소 지원 버전 | iOS 17.0+ |
| 지원 기기 | iPhone |
| 코드 구성 | 역할별 폴더, 화면별 Feature |
| 화면 | UIKit |
| 상태와 비동기 처리 | ReactorKit, RxSwift, async/await, AsyncStream |
| Apple 프레임워크 | UIKit, Foundation |
| 외부 패키지 | ReactorKit, RxSwift, SQLiteData, GRDB, swift-structured-queries |
| 테스트 | XCTest |
| 개발 도구 | Xcode, Swift Package Manager, SwiftLint, mise, Make, GitHub Actions |

## 개발 환경 구성

- Xcode 프로젝트와 Shared Scheme을 Git에서 추적
- Swift Package 의존성은 프로젝트에서 선언하고 `Package.resolved`에서 해석된 버전 고정
- 테스트 코드 빌드에 필요한 `StructuredQueriesCore`와 `GRDB`를 사용하는 타깃에 명시적으로 연결
- 로컬에서는 Xcode의 `Trust & Enable`로 외부 패키지의 Swift Macro 승인
- CI에서는 `XCODEBUILD_FLAGS=-skipMacroValidation`을 전달해 해당 빌드의 모든 Swift Macro 신뢰 검증 생략
- SwiftLint 버전은 `.mise.toml`에서 고정하고 로컬과 CI에서 같은 버전 사용
- 화면은 UIKit 코드로 구성하고 `LaunchScreen.storyboard`는 시스템 시작 화면에만 사용
- `xcuserdata`와 빌드 산출물은 Git 추적 대상에서 제외

### 환경 버전

| 항목 | 버전 |
| --- | --- |
| Xcode | 27.0 |
| iOS Deployment Target | 17.0 |
| Swift | 5.0 |

### 1. 도구 설치

[공식 설치 안내](https://mise.jdx.dev/getting-started.html)에 따라 mise를 설치한 뒤 프로젝트의 도구 설치

```bash
mise trust .mise.toml
mise install
```

### 2. Xcode 프로젝트 열기

- [Plyst.xcodeproj](Plyst/Plyst.xcodeproj) 열기
- `Plyst` Shared Scheme 선택
- Swift Package 의존성 확인

### 3. 린트 구성

저장소에 포함된 설정 파일을 기준으로 앱 코드와 테스트 코드를 나누어 검사

| 파일 | 역할 |
| --- | --- |
| [.mise.toml](.mise.toml) | SwiftLint 버전 고정 |
| [.swiftlint.yml](.swiftlint.yml) | 공통 규칙과 앱 코드 검사 설정 |
| [.swiftlint-tests.yml](.swiftlint-tests.yml) | 공통 설정을 상속하고 테스트 코드의 `identifier_name` 검사 제외 |
| [Makefile](Makefile) | mise 환경에서 앱 코드와 테스트 코드의 린트 실행 |

프로젝트 루트에서 린트 실행

```bash
make lint
```

[CI](.github/workflows/ci.yml)에서도 `.mise.toml`의 SwiftLint를 설치한 뒤 같은 명령 사용

### 4. 빌드 확인

로컬과 GitHub Actions에서 같은 검증 명령 사용

```bash
make verify
```

| 명령 | 확인 내용 |
| --- | --- |
| `make lint` | 앱 코드와 테스트 코드의 SwiftLint 검사 |
| `make build` | `Plyst` 앱 빌드 |
| `make test-build` | 테스트를 실행하지 않는 `PlystTests` 컴파일 |
| `make verify` | SwiftLint, 앱 빌드, 테스트 타깃 컴파일 |

## 프로젝트 구조

```text
Plyst/
├── .github/workflows/ci.yml
├── .mise.toml
├── .swiftlint.yml
├── .swiftlint-tests.yml
├── Makefile
├── Plyst/
│	├── Plyst.xcodeproj/
│	├── Plyst/
│	│	├── App/
│	│	│	├── AppDelegate.swift
│	│	│	└── SceneDelegate.swift
│	│	├── Model/
│	│	│	├── Clip.swift
│	│	│	├── ClipContent.swift
│	│	│	├── ClipImageMetadata.swift
│	│	│	├── ClipSortOrder.swift
│	│	│	└── ClipUpdate.swift
│	│	├── Service/
│	│	│	├── Clip/
│	│	│	│	├── Storage/
│	│	│	│	├── Clipboard/
│	│	│	│	└── Image/
│	│	│	└── SQLite/
│	│	│		└── SQLiteSynchronousMode.swift
│	│	├── Feature/
│	│	│	└── Root/
│	│	│		├── AppReactor.swift
│	│	│		└── ViewController.swift
│	│	├── Shared/
│	│	│	└── State/
│	│	│		├── Reactorable.swift
│	│	│		├── ReactorEffect.swift
│	│	│		└── ReactorViewController.swift
│	│	└── Base.lproj/LaunchScreen.storyboard
│	└── PlystTests/
│		├── Model/
│		└── Service/
│			└── Clip/
│				├── Storage/
│				├── Clipboard/
│				└── Image/
└── README.md
```
