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
        JobRepositoryImpl(JobRepositoryImpl\n- Implements JobRepository\n- Orchestrates Sync) -->|Implements| JobRepositoryInterface
        JobRepositoryImpl -->|Depends on| JobLocalDSInterface(JobLocalDataSource Interface)
        JobRepositoryImpl -->|Depends on| JobRemoteDSInterface(JobRemoteDataSource Interface)

        subgraph "Local Persistence (Hive)"
            HiveJobLocalDS(HiveJobLocalDataSourceImpl\n- Implements JobLocalDSInterface) -->|Implements| JobLocalDSInterface
            HiveJobLocalDS -->|Uses| JobMapper(JobMapper)
            HiveJobLocalDS -->|Uses| HiveBox([Hive Box])
            JobMapper -->|Maps to/from| JobHiveModel((JobHiveModel DTO\n- Hive Annotations))
            JobMapper -->|Maps to/from| JobEntity
            JobHiveModel -- Stored in --> HiveBox
        end

        subgraph "Remote API"
            ApiJobRemoteDS(ApiJobRemoteDataSourceImpl\n- Implements JobRemoteDSInterface) -->|Implements| JobRemoteDSInterface
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
        AuthServiceImpl -->|Uses| AuthInterceptor(Auth Interceptor)
        
        AuthCredProviderImpl -->|Implements| AuthCredProvider
        AuthCredProviderImpl -->|Reads API Key From| DotEnv([.env File via flutter_dotenv])
        AuthCredProviderImpl -->|Stores/Reads JWT| SecureStorage([FlutterSecureStorage])
        
        AuthApiClient -->|Uses| HttpClient([HTTP Client\n- dio/http])
        AuthApiClient -->|Gets API Key from| AuthCredProvider
        
        AuthInterceptor -->|Intercepts 401 Errors| HttpClient
        AuthInterceptor -->|Triggers| TokenRefresh([Token Refresh Flow])
        AuthInterceptor -->|Retries Original Request| HttpClient
        
        HttpClient -->|Makes Requests to| AuthAPI{REST API /api/v1/auth/login /api/v1/auth/refresh-session}
    end

    %% Styling
    classDef domain fill:#f9f,stroke:#333,stroke-width:2px;
    classDef data fill:#ccf,stroke:#333,stroke-width:2px;
    classDef presentation fill:#cfc,stroke:#333,stroke-width:2px;
    classDef external fill:#eee,stroke:#333,stroke-width:1px;

    class UI,AuthState presentation;
    class AuthService,User,AuthCredProvider domain;
    class AuthServiceImpl,AuthCredProviderImpl,SecureStorage,HttpClient,AuthAPI,AuthApiClient,AuthInterceptor,TokenRefresh data;
    class DotEnv external;
```

## Authentication Flow

This sequence diagram illustrates the authentication process from login to using authenticated endpoints.

```mermaid
sequenceDiagram
    participant UI as UI
    participant AuthSvc as AuthService
    participant ApiClient as AuthApiClient
    participant Interceptor as AuthInterceptor
    participant CredProvider as AuthCredentialsProvider
    participant API as Auth API

    %% Login Flow
    Note over UI,API: Login Flow
    UI->>AuthSvc: login(email, password)
    AuthSvc->>ApiClient: login(email, password)
    ApiClient->>CredProvider: getApiKey()
    CredProvider-->>ApiClient: API Key
    ApiClient->>API: POST /api/v1/auth/login
    Note right of API: With API Key in header
    API-->>ApiClient: {access_token, refresh_token, user_id}
    ApiClient-->>AuthSvc: AuthResponse DTO
    AuthSvc->>CredProvider: setAccessToken(token)
    AuthSvc->>CredProvider: setRefreshToken(token)
    AuthSvc->>AuthSvc: Create User entity
    AuthSvc-->>UI: User entity
    
    %% Using an authenticated endpoint (success)
    Note over UI,API: Using an authenticated endpoint (success case)
    UI->>AuthSvc: Some authenticated action
    AuthSvc->>ApiClient: makeAuthenticatedRequest()
    ApiClient->>CredProvider: getAccessToken()
    CredProvider-->>ApiClient: JWT token
    ApiClient->>CredProvider: getApiKey()
    CredProvider-->>ApiClient: API Key
    ApiClient->>API: Request with JWT + API Key
    API-->>ApiClient: Successful Response
    ApiClient-->>AuthSvc: Processed response
    AuthSvc-->>UI: Result
    
    %% Token Refresh Flow (automatic)
    Note over UI,API: Automatic Token Refresh (when JWT expires)
    UI->>AuthSvc: Some authenticated action
    AuthSvc->>ApiClient: makeAuthenticatedRequest()
    ApiClient->>CredProvider: getAccessToken()
    CredProvider-->>ApiClient: JWT token (expired)
    ApiClient->>API: Request with expired JWT
    API-->>ApiClient: 401 Unauthorized
    ApiClient->>Interceptor: Receives 401 error
    Interceptor->>CredProvider: getRefreshToken()
    CredProvider-->>Interceptor: Refresh token
    Interceptor->>ApiClient: refreshToken(refreshToken)
    ApiClient->>CredProvider: getApiKey()
    CredProvider-->>ApiClient: API Key
    ApiClient->>API: POST /api/v1/auth/refresh-session
    API-->>ApiClient: {new_access_token, new_refresh_token}
    ApiClient-->>Interceptor: New tokens
    Interceptor->>CredProvider: setAccessToken(newToken)
    Interceptor->>CredProvider: setRefreshToken(newRefreshToken)
    Interceptor->>API: Retry original request with new token
    API-->>ApiClient: Successful Response
    ApiClient-->>AuthSvc: Processed response
    AuthSvc-->>UI: Result
    
    %% Logout Flow
    Note over UI,API: Logout Flow
    UI->>AuthSvc: logout()
    AuthSvc->>CredProvider: deleteAccessToken()
    AuthSvc->>CredProvider: deleteRefreshToken()
    AuthSvc-->>UI: Logout successful
```

## Authentication Components

### Domain Layer

#### AuthService Interface
The `AuthService` interface defines the following methods:
- `Future<User> login(String email, String password)` - Authenticates a user and returns user data
- `Future<bool> refreshSession()` - Manually refreshes the authentication token (used on startup)
- `Future<void> logout()` - Logs the user out by clearing stored tokens
- `Future<bool> isAuthenticated()` - Checks if stored credentials exist (basic check for initial app state)

#### AuthCredentialsProvider Interface
Manages secure storage and retrieval of authentication credentials:
- API key from environment variables
- Access and refresh tokens in secure storage

### Data Layer

#### AuthServiceImpl
Implements the `AuthService` interface, orchestrating the authentication flow.

#### AuthApiClient
Responsible for communication with authentication endpoints:
- `login()` - Authenticates with email/password
- `refreshToken()` - Refreshes tokens when expired
- Maps API errors to domain-specific exceptions

#### AuthInterceptor
A Dio interceptor that:
1. Automatically detects 401 (Unauthorized) errors
2. Initiates token refresh flow
3. Retries the original request with the new token
4. Handles failure cases (like invalid refresh tokens)

This approach provides seamless token refresh without UI layer awareness of expired tokens. The authentication flow is handled at the data layer where it belongs, maintaining clean separation of concerns.

#### SecureStorageAuthCredentialsProvider
Concrete implementation of `AuthCredentialsProvider` using:
- `flutter_secure_storage` for token storage
- `flutter_dotenv` for environment variables (API key)

### Presentation Layer

#### AuthState
Immutable state object representing the current authentication state:
- `user` - The authenticated user entity
- `status` - Current status (authenticated, unauthenticated, loading, error)
- `errorMessage` - Error message if authentication failed

#### AuthNotifier
State management for authentication, connecting UI to domain services:
- `login()` - Authenticates a user
- `logout()` - Logs out the current user
- `checkAuthStatus()` - Verifies authentication on app startup

The UI components observe the `AuthNotifier` state to render the appropriate screens based on authentication status. 