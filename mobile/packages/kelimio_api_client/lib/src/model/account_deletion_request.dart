//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'account_deletion_request.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class AccountDeletionRequest {
  /// Returns a new [AccountDeletionRequest] instance.
  AccountDeletionRequest({
    required this.id,

    required this.status,

    required this.requestedAt,

    required this.scheduledFor,

    required this.created,
  });

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'status', required: true, includeIfNull: false)
  final AccountDeletionRequestStatusEnum status;

  @JsonKey(name: r'requestedAt', required: true, includeIfNull: false)
  final DateTime requestedAt;

  @JsonKey(name: r'scheduledFor', required: true, includeIfNull: false)
  final DateTime scheduledFor;

  @JsonKey(name: r'created', required: true, includeIfNull: false)
  final bool created;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccountDeletionRequest &&
          other.id == id &&
          other.status == status &&
          other.requestedAt == requestedAt &&
          other.scheduledFor == scheduledFor &&
          other.created == created;

  @override
  int get hashCode =>
      id.hashCode +
      status.hashCode +
      requestedAt.hashCode +
      scheduledFor.hashCode +
      created.hashCode;

  factory AccountDeletionRequest.fromJson(Map<String, dynamic> json) =>
      _$AccountDeletionRequestFromJson(json);

  Map<String, dynamic> toJson() => _$AccountDeletionRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum AccountDeletionRequestStatusEnum {
  @JsonValue(r'PENDING')
  PENDING(r'PENDING'),
  @JsonValue(r'CANCELLED')
  CANCELLED(r'CANCELLED'),
  @JsonValue(r'COMPLETED')
  COMPLETED(r'COMPLETED');

  const AccountDeletionRequestStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
