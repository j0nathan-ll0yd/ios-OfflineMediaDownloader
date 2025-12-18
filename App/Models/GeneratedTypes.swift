import APITypes

// MARK: - Type Aliases for Generated API Types
// Maps generated types from swift-openapi-generator to more convenient names.
// Generated types follow the pattern: Components.Schemas.{SchemaName}
// where dots in schema names become underscores (e.g., Models.File -> Models_File)

// MARK: - File Types
public typealias APIFile = Components.Schemas.Models_period_File
public typealias APIFileStatus = Components.Schemas.Models_period_FileStatus
public typealias APIFileListResponse = Components.Schemas.Models_period_FileListResponse

// MARK: - Device Types
public typealias APIDevice = Components.Schemas.Models_period_Device
public typealias APIDeviceRegistrationRequest = Components.Schemas.Models_period_DeviceRegistrationRequest
public typealias APIDeviceRegistrationResponse = Components.Schemas.Models_period_DeviceRegistrationResponse

// MARK: - User/Auth Types
public typealias APIUserLogin = Components.Schemas.Models_period_UserLogin
public typealias APIUserLoginResponse = Components.Schemas.Models_period_UserLoginResponse
public typealias APIUserRegistration = Components.Schemas.Models_period_UserRegistration
public typealias APIUserRegistrationResponse = Components.Schemas.Models_period_UserRegistrationResponse

// MARK: - Webhook Types
public typealias APIFeedlyWebhook = Components.Schemas.Models_period_FeedlyWebhook
public typealias APIWebhookResponse = Components.Schemas.Models_period_WebhookResponse

// MARK: - Error Types
public typealias APIErrorResponse = Components.Schemas.ErrorResponse
public typealias APIForbiddenError = Components.Schemas.ForbiddenError
public typealias APIUnauthorizedError = Components.Schemas.UnauthorizedError
public typealias APIInternalServerError = Components.Schemas.InternalServerError
