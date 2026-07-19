import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'api_exception.dart';

class WorkspaceSummary {
  const WorkspaceSummary({
    required this.workspaceId,
    required this.versionCounter,
    required this.updatedAt,
  });

  final String workspaceId;
  final int versionCounter;
  final DateTime updatedAt;
}

class WorkspaceSnapshotResult {
  const WorkspaceSnapshotResult({
    required this.workspaceId,
    required this.versionCounter,
    required this.snapshot,
  });

  final String workspaceId;
  final int versionCounter;
  final Map<String, Object?> snapshot;
}

class PushResult {
  const PushResult({required this.versionCounter, required this.conflict});

  final int versionCounter;
  final bool conflict;
}

abstract class SyncApiClient {
  Future<List<WorkspaceSummary>> listWorkspaces(String accessToken);
  Future<WorkspaceSnapshotResult> pull(String accessToken, String workspaceId);
  Future<PushResult> push(
    String accessToken,
    String workspaceId, {
    required int baseVersion,
    required Map<String, Object?> snapshot,
  });
}

class HttpSyncApiClient implements SyncApiClient {
  HttpSyncApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Map<String, String> _headers(String accessToken) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $accessToken',
  };

  @override
  Future<List<WorkspaceSummary>> listWorkspaces(String accessToken) async {
    final response = await _client.get(
      Uri.parse('$apiBaseUrl/sync/workspaces'),
      headers: _headers(accessToken),
    );
    final body = _decodeList(response);
    return body
        .map(
          (row) => WorkspaceSummary(
            workspaceId: row['workspaceId'] as String,
            versionCounter: int.parse(row['versionCounter'].toString()),
            updatedAt: DateTime.parse(row['updatedAt'] as String),
          ),
        )
        .toList();
  }

  @override
  Future<WorkspaceSnapshotResult> pull(
    String accessToken,
    String workspaceId,
  ) async {
    final response = await _client.get(
      Uri.parse('$apiBaseUrl/sync/workspaces/$workspaceId'),
      headers: _headers(accessToken),
    );
    final body = _decodeMap(response);
    return WorkspaceSnapshotResult(
      workspaceId: body['workspaceId'] as String,
      versionCounter: int.parse(body['versionCounter'].toString()),
      snapshot: Map<String, Object?>.from(body['snapshot'] as Map),
    );
  }

  @override
  Future<PushResult> push(
    String accessToken,
    String workspaceId, {
    required int baseVersion,
    required Map<String, Object?> snapshot,
  }) async {
    final response = await _client.put(
      Uri.parse('$apiBaseUrl/sync/workspaces/$workspaceId'),
      headers: _headers(accessToken),
      body: jsonEncode({'baseVersion': baseVersion, 'snapshot': snapshot}),
    );
    final body = _decodeMap(response);
    return PushResult(
      versionCounter: int.parse(body['versionCounter'].toString()),
      conflict: body['conflict'] as bool? ?? false,
    );
  }

  Map<String, dynamic> _decodeMap(http.Response response) {
    _checkStatus(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  List<Map<String, dynamic>> _decodeList(http.Response response) {
    _checkStatus(response);
    return (jsonDecode(response.body) as List).cast<Map<String, dynamic>>();
  }

  void _checkStatus(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    Map<String, dynamic> body = const {};
    if (response.body.isNotEmpty) {
      try {
        body = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        // ignore
      }
    }
    final message =
        body['error'] as String? ?? 'Request failed (${response.statusCode}).';
    throw ApiException(message, statusCode: response.statusCode);
  }
}
