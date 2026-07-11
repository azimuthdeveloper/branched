import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:branched/git_engine/git_models.dart';
import 'package:branched/features/commit_graph/graph_layout.dart';

CommitEntity makeCommit(String sha, List<String> parentShas, {bool isHead = false}) {
  return CommitEntity(
    sha: sha,
    shortSha: sha.substring(0, min(sha.length, 7)),
    message: 'Commit $sha',
    summary: 'Commit $sha',
    author: const AuthorEntity(name: 'Author', email: 'author@test.com'),
    committer: const AuthorEntity(name: 'Committer', email: 'committer@test.com'),
    dateTime: DateTime.now(),
    parentShas: parentShas,
    isHead: isHead,
    isMergeCommit: parentShas.length > 1,
    refs: const [],
  );
}

void main() {
  group('GraphLayoutBuilder Tests', () {
    test('Linear history A -> B -> C', () {
      // Commits list: newest first (C -> B -> A)
      final c = makeCommit('C', ['B']);
      final b = makeCommit('B', ['A']);
      final a = makeCommit('A', []);
      
      final layout = GraphLayoutBuilder.buildLayout([c, b, a]);
      
      expect(layout.length, 3);
      
      // All commits should be on lane 0
      expect(layout[0].laneIndex, 0);
      expect(layout[1].laneIndex, 0);
      expect(layout[2].laneIndex, 0);

      // C (newest/first row):
      // - Emits a branch connection going down to parent B (on lane 0 -> 0)
      final cConnections = layout[0].connections;
      expect(cConnections.any((conn) => conn.type == ConnectionType.branchLeft || conn.type == ConnectionType.branchRight), isTrue);
      expect(cConnections.every((conn) => conn.fromLane == 0 && conn.toLane == 0), isTrue);
      expect(cConnections.any((conn) => conn.type == ConnectionType.straight), isFalse);

      // B (middle row):
      // - Receives a merge connection from child C (on lane 0 -> 0)
      // - Emits a branch connection going down to parent A (on lane 0 -> 0)
      final bConnections = layout[1].connections;
      final bIncoming = bConnections.where((conn) => conn.type == ConnectionType.mergeLeft || conn.type == ConnectionType.mergeRight).toList();
      final bOutgoing = bConnections.where((conn) => conn.type == ConnectionType.branchLeft || conn.type == ConnectionType.branchRight).toList();
      expect(bIncoming.length, 1);
      expect(bIncoming[0].fromLane, 0);
      expect(bIncoming[0].toLane, 0);
      expect(bOutgoing.length, 1);
      expect(bOutgoing[0].fromLane, 0);
      expect(bOutgoing[0].toLane, 0);
      expect(bConnections.any((conn) => conn.type == ConnectionType.straight), isFalse);

      // A (oldest/last row / root commit):
      // - Receives a merge connection from child B (on lane 0 -> 0)
      // - No outgoing branch connections since it has no parents
      final aConnections = layout[2].connections;
      final aIncoming = aConnections.where((conn) => conn.type == ConnectionType.mergeLeft || conn.type == ConnectionType.mergeRight).toList();
      final aOutgoing = aConnections.where((conn) => conn.type == ConnectionType.branchLeft || conn.type == ConnectionType.branchRight).toList();
      expect(aIncoming.length, 1);
      expect(aIncoming[0].fromLane, 0);
      expect(aIncoming[0].toLane, 0);
      expect(aOutgoing.isEmpty, isTrue);
      expect(aConnections.any((conn) => conn.type == ConnectionType.straight), isFalse);
    });

    test('Merge commit M (parents A, B) and lane reclamation', () {
      // Topology:
      // M (parents: A, B)
      // B (parents: A)
      // A (parents: none)
      //
      // Order newest first: M, B, A
      final m = makeCommit('M', ['A', 'B']);
      final b = makeCommit('B', ['A']);
      final a = makeCommit('A', []);

      final layout = GraphLayoutBuilder.buildLayout([m, b, a]);

      expect(layout.length, 3);
      
      // M is tip, lane 0
      expect(layout[0].laneIndex, 0);
      
      // M has two parents: parent A (index 0 continues in lane 0)
      // and parent B (index 1 allocated to lane 1)
      final mConnections = layout[0].connections;
      final mOutgoing = mConnections.where((conn) => conn.type == ConnectionType.branchLeft || conn.type == ConnectionType.branchRight).toList();
      expect(mOutgoing.length, 2);
      expect(mOutgoing.any((conn) => conn.fromLane == 0 && conn.toLane == 0), isTrue); // continues to A
      expect(mOutgoing.any((conn) => conn.fromLane == 0 && conn.toLane == 1), isTrue); // branches out to B on lane 1

      // B (row index 1):
      // - laneIndex is 1 (since it continues parent B on lane 1)
      expect(layout[1].laneIndex, 1);
      
      // B receives merge incoming from lane 1 (from M)
      final bConnections = layout[1].connections;
      final bIncoming = bConnections.where((conn) => conn.type == ConnectionType.mergeLeft || conn.type == ConnectionType.mergeRight).toList();
      expect(bIncoming.length, 1);
      expect(bIncoming[0].fromLane, 1);
      expect(bIncoming[0].toLane, 1);
      
      // B goes down to A, which is already waiting on lane 0.
      // So B emits branch to lane 0.
      final bOutgoing = bConnections.where((conn) => conn.type == ConnectionType.branchLeft || conn.type == ConnectionType.branchRight).toList();
      expect(bOutgoing.length, 1);
      expect(bOutgoing[0].fromLane, 1);
      expect(bOutgoing[0].toLane, 0);

      // A (row index 2):
      // - laneIndex is 0
      expect(layout[2].laneIndex, 0);
      
      // A receives merge incoming from lane 0 and lane 1 (which merged into lane 0 at B)
      // Wait, let's trace incoming for A:
      // At row A, child M (lane 0) and child B (lane 1) are both waiting for A.
      // In the layout code:
      // lanes has ['A', 'A'] before processing A.
      // incoming will be [0, 1].
      // lane is incoming.first which is 0.
      // So lanes[0] and lanes[1] are cleared to null, and merge incoming comes from 0 and 1.
      final aConnections = layout[2].connections;
      final aIncoming = aConnections.where((conn) => conn.type == ConnectionType.mergeLeft || conn.type == ConnectionType.mergeRight).toList();
      expect(aIncoming.length, 1);
      expect(aIncoming[0].fromLane, 0);
      expect(aIncoming[0].toLane, 0);

      // Verify lane reclamation:
      // If we add another separate branch after M merges, it should reuse lane 1.
      // Topology:
      // T2 (parents: A) -- tip 2
      // M (parents: A, B)
      // B (parents: A)
      // A (parents: none)
      // Newest first order: T2, M, B, A
      final t2 = makeCommit('T2', ['A']);
      final layout2 = GraphLayoutBuilder.buildLayout([t2, m, b, a]);
      
      // T2 is first tip, gets lane 0.
      expect(layout2[0].laneIndex, 0);
      // M starts a new lane since lane 0 is occupied (waiting for A).
      // Since lane 0 is occupied, it allocates to lane 1.
      expect(layout2[1].laneIndex, 1);
    });

    test('Branch point (two children, one parent)', () {
      // Topology:
      // C1 (parents: A)
      // C2 (parents: A)
      // A (parents: none)
      // Newest first order: C1, C2, A
      final c1 = makeCommit('C1', ['A']);
      final c2 = makeCommit('C2', ['A']);
      final a = makeCommit('A', []);

      final layout = GraphLayoutBuilder.buildLayout([c1, c2, a]);

      expect(layout.length, 3);
      // C1 starts at lane 0, waiting for A
      expect(layout[0].laneIndex, 0);
      // C2 starts at lane 1 (since lane 0 is occupied waiting for A), waiting for A
      expect(layout[1].laneIndex, 1);

      // C2's outgoing branch edge should go to lane 0 (which is already waiting for A)
      final c2Connections = layout[1].connections;
      final c2Outgoing = c2Connections.where((conn) => conn.type == ConnectionType.branchLeft || conn.type == ConnectionType.branchRight).toList();
      expect(c2Outgoing.length, 1);
      expect(c2Outgoing[0].fromLane, 1);
      expect(c2Outgoing[0].toLane, 0); // pointing to lane 0 waiting for A
    });

    test('No spurious straight lines on newly allocated lanes in the same row', () {
      // A row allocating a new lane should not have a straight line for that lane.
      // Let's check our merge layout (M, B, A):
      // M is on lane 0. It allocates parent B on lane 1.
      // M's row should NOT have a straight connection for lane 1.
      final m = makeCommit('M', ['A', 'B']);
      final b = makeCommit('B', ['A']);
      final a = makeCommit('A', []);

      final layout = GraphLayoutBuilder.buildLayout([m, b, a]);
      final mConnections = layout[0].connections;
      
      final mStraights = mConnections.where((conn) => conn.type == ConnectionType.straight).toList();
      expect(mStraights.isEmpty, isTrue); // no straight lines on row 0
    });

    test('Root commit frees its lane', () {
      // Two unrelated components:
      // A1 (no parent)
      // A2 (no parent)
      // Newest first order: A1, A2
      // Since A1 has no parents, after it is processed, lane 0 should be freed.
      // A2 should then be allocated to lane 0 again.
      final a1 = makeCommit('A1', []);
      final a2 = makeCommit('A2', []);

      final layout = GraphLayoutBuilder.buildLayout([a1, a2]);
      expect(layout.length, 2);
      expect(layout[0].laneIndex, 0);
      expect(layout[1].laneIndex, 0); // Lane 0 reclaimed!
    });
  });
}
