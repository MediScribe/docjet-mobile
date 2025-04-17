# Job Feature Architecture

```mermaid
graph TD
    subgraph "Presentation Layer (UI, State Management)"
        UI -->|Uses| AppService(Application Service / Use Cases)
    end

    subgraph "Domain Layer (Core Logic, Entities)"
        AppService -->|Uses| JobRepositoryInterface(JobRepository Interface)
        JobEntity((Job Entity\n- Pure Dart\n- Equatable))
        JobRepositoryInterface -- Defines --> JobEntity
    end

    subgraph "Data Layer (Implementation Details)"
        JobRepositoryImpl(JobRepositoryImpl\n- Implements JobRepository\n- Orchestrates Sync) -->|Uses| JobRepositoryInterface
        JobRepositoryImpl -->|Depends on| JobLocalDSInterface(JobLocalDataSource Interface)
        JobRepositoryImpl -->|Depends on| JobRemoteDSInterface(JobRemoteDataSource Interface)

        subgraph "Local Persistence (Hive)"
            HiveJobLocalDS(HiveJobLocalDataSourceImpl\n- Implements JobLocalDSInterface) -->|Uses| JobLocalDSInterface
            HiveJobLocalDS -->|Uses| JobMapper(JobMapper)
            HiveJobLocalDS -->|Uses| HiveBox([Hive Box])
            JobMapper -->|Maps to/from| JobHiveModel((JobHiveModel DTO\n- Hive Annotations))
            JobMapper -->|Maps to/from| JobEntity
            JobHiveModel -- Stored in --> HiveBox
        end

        subgraph "Remote API"
            ApiJobRemoteDS(ApiJobRemoteDataSourceImpl\n- Implements JobRemoteDSInterface) -->|Uses| JobRemoteDSInterface
            ApiJobRemoteDS -->|Uses| HttpClient([HTTP Client\n- dio/http])
            ApiJobRemoteDS -->|Talks to| RestAPI{REST API\n/api/v1/jobs}
            %% ApiJobRemoteDS -->|Maps JSON to/from| JobEntity %% Potentially needs ApiDTO later
        end
    end

    %% Styling for clarity
    classDef domain fill:#f9f,stroke:#333,stroke-width:2px;
    classDef data fill:#ccf,stroke:#333,stroke-width:2px;
    classDef presentation fill:#cfc,stroke:#333,stroke-width:2px;

    class JobEntity,JobRepositoryInterface domain;
    class JobRepositoryImpl,JobLocalDSInterface,JobRemoteDSInterface,HiveJobLocalDS,ApiJobRemoteDS,JobMapper,JobHiveModel,HiveBox,HttpClient,RestAPI data;
    class UI,AppService presentation;

```

# Authentication Architecture

This diagram illustrates the components and their relationships for the authentication system.

```mermaid
graph TD
    subgraph "Presentation Layer"
        UI(Login Screen/Auth UI) -->|Uses| AuthService(Auth Service Interface)
        AuthState(Auth State Management) <-->|Observed by| UI
    end

    subgraph "Domain Layer"
        AuthService -->|Defines| User((User Entity\n- Pure Dart\n- Equatable))
        AuthService -->|Uses| AuthCredProvider(AuthCredentialsProvider Interface)
    end

    subgraph "Data Layer"
        AuthServiceImpl(AuthServiceImpl) -->|Implements| AuthService
        AuthServiceImpl -->|Uses| AuthApiClient(Auth API Client)
        AuthServiceImpl -->|Updates| AuthState
        AuthServiceImpl -->|Uses| AuthCredProviderImpl(SecureStorageAuthCredentialsProvider)
        
        AuthCredProviderImpl -->|Implements| AuthCredProvider
        AuthCredProviderImpl -->|Reads API Key From| DotEnv([.env File via flutter_dotenv])
        AuthCredProviderImpl -->|Stores/Reads JWT| SecureStorage([FlutterSecureStorage])
        
        AuthApiClient -->|Uses| HttpClient([HTTP Client\n- dio/http])
        AuthApiClient -->|Gets API Key from| AuthCredProvider
        HttpClient -->|Makes Requests to| AuthAPI{REST API\n/api/v1/auth/login\n/api/v1/auth/refresh-session}
    end

    %% Styling
    classDef domain fill:#f9f,stroke:#333,stroke-width:2px;
    classDef data fill:#ccf,stroke:#333,stroke-width:2px;
    classDef presentation fill:#cfc,stroke:#333,stroke-width:2px;
    classDef external fill:#eee,stroke:#333,stroke-width:1px;

    class UI,AuthState presentation;
    class AuthService,User,AuthCredProvider domain;
    class AuthServiceImpl,AuthCredProviderImpl,SecureStorage,HttpClient,AuthAPI,AuthApiClient data;
    class DotEnv external;
```

## Authentication Flow

This sequence diagram illustrates the authentication process from login to using authenticated endpoints.

```mermaid
sequenceDiagram
    participant UI as UI
    participant AuthSvc as AuthService
    participant ApiClient as AuthApiClient
    participant CredProvider as AuthCredentialsProvider
    participant API as Auth API

    %% Login Flow
    Note over UI,API: Login Flow
    UI->>AuthSvc: login(email, password)
    AuthSvc->>CredProvider: getApiKey()
    CredProvider-->>AuthSvc: API Key
    AuthSvc->>ApiClient: login(email, password, apiKey)
    ApiClient->>API: POST /api/v1/auth/login
    Note right of API: With API Key in header
    API-->>ApiClient: {access_token, refresh_token, user_id}
    ApiClient-->>AuthSvc: AuthResponse DTO
    AuthSvc->>CredProvider: setAccessToken(token)
    AuthSvc->>AuthSvc: Create User entity
    AuthSvc-->>UI: User entity
    
    %% Using an authenticated endpoint
    Note over UI,API: Using an authenticated endpoint
    UI->>AuthSvc: Some authenticated action
    AuthSvc->>CredProvider: getAccessToken()
    CredProvider-->>AuthSvc: JWT token
    AuthSvc->>ApiClient: makeAuthenticatedRequest(endpoint, token)
    ApiClient->>CredProvider: getApiKey()
    CredProvider-->>ApiClient: API Key
    ApiClient->>API: Request with JWT + API Key
    API-->>ApiClient: Response
    ApiClient-->>AuthSvc: Processed response
    AuthSvc-->>UI: Result
    
    %% Token Refresh Flow
    Note over UI,API: Token Refresh (when JWT expires)
    ApiClient->>API: Request with expired JWT
    API-->>ApiClient: 401 Unauthorized
    ApiClient->>AuthSvc: Token expired
    AuthSvc->>CredProvider: getRefreshToken()
    CredProvider-->>AuthSvc: Refresh token
    AuthSvc->>ApiClient: refreshSession(refreshToken)
    ApiClient->>API: POST /api/v1/auth/refresh-session
    API-->>ApiClient: {new_access_token, new_refresh_token}
    ApiClient-->>AuthSvc: New tokens
    AuthSvc->>CredProvider: setAccessToken(newToken)
    AuthSvc->>CredProvider: setRefreshToken(newRefreshToken)
    AuthSvc->>ApiClient: Retry original request
    
    %% Logout Flow
    Note over UI,API: Logout Flow
    UI->>AuthSvc: logout()
    AuthSvc->>CredProvider: deleteAccessToken()
    AuthSvc->>CredProvider: deleteRefreshToken()
    AuthSvc-->>UI: Logout successful
```

## AuthService Interface

The `AuthService` interface defines the following methods:

- `Future<User> login(String email, String password)` - Authenticates a user and returns user data
- `Future<bool> refreshSession()` - Refreshes the authentication token when it expires
- `Future<void> logout()` - Logs the user out by clearing stored tokens
- `Future<bool> isAuthenticated()` - Checks if the user is currently authenticated 