import '../../git_engine/git_models.dart';

class GraphCommit {
  final CommitEntity commit;
  final int laneIndex;
  final List<GraphConnectionEntity> connections;
  final int colorIndex;

  GraphCommit({
    required this.commit,
    required this.laneIndex,
    required this.connections,
    required this.colorIndex,
  });
}

/// Assigns each commit a lane and the edges needed to paint a Fork-style
/// commit graph.
///
/// [commits] must be newest-first (top of the graph to bottom).
///
/// Connection semantics (match [CommitGraphPainter]):
/// - `straight` — full-height vertical pass-through at [fromLane]
/// - `mergeLeft` / `mergeRight` — enters the row at top/[fromLane], ends at
///   the commit dot (toLane, center). `fromLane == toLane` is the commit's own
///   incoming vertical.
/// - `branchLeft` / `branchRight` — leaves the commit dot (fromLane, center)
///   to the row bottom at [toLane]. `fromLane == toLane` is the first-parent
///   continuation.
///
/// Lanes are reclaimed when the commit they wait for is consumed, so later
/// independent tips can reuse freed lanes instead of growing forever.
class GraphLayoutBuilder {
  static List<GraphCommit> buildLayout(List<CommitEntity> commits) {
    if (commits.isEmpty) return [];

    // Each slot holds the SHA the lane is waiting for; null means free.
    final lanes = <String?>[];
    final layout = <GraphCommit>[];

    int allocateLane() {
      final free = lanes.indexOf(null);
      if (free >= 0) return free;
      lanes.add(null);
      return lanes.length - 1;
    }

    void ensureLane(int index) {
      while (lanes.length <= index) {
        lanes.add(null);
      }
    }

    for (final commit in commits) {
      final connections = <GraphConnectionEntity>[];

      // Lanes waiting for this commit (children above that pointed here).
      final incoming = <int>[];
      for (var i = 0; i < lanes.length; i++) {
        if (lanes[i] == commit.sha) {
          incoming.add(i);
        }
      }

      final int lane;
      if (incoming.isNotEmpty) {
        lane = incoming.first;
      } else {
        lane = allocateLane();
      }
      ensureLane(lane);

      // Free all lanes that were waiting for this commit.
      for (final i in incoming) {
        lanes[i] = null;
      }

      // Incoming merge edges into this commit's dot.
      for (final from in incoming) {
        connections.add(GraphConnectionEntity(
          fromLane: from,
          toLane: lane,
          type: from <= lane ? ConnectionType.mergeLeft : ConnectionType.mergeRight,
          colorIndex: from % 10,
        ));
      }

      // Active pass-through lanes *before* we register parents for this row.
      // Newly allocated parent lanes must not get a spurious full-height straight.
      final activeBeforeParents = <int>{};
      for (var i = 0; i < lanes.length; i++) {
        if (lanes[i] != null) {
          activeBeforeParents.add(i);
        }
      }

      // Outgoing branch edges down to parents.
      for (var j = 0; j < commit.parentShas.length; j++) {
        final parentSha = commit.parentShas[j];
        final existing = lanes.indexOf(parentSha);
        late final int parentLane;

        if (existing >= 0) {
          // Shared parent already waiting on another lane — join it.
          parentLane = existing;
        } else if (j == 0) {
          // First parent continues on this commit's lane.
          parentLane = lane;
          ensureLane(parentLane);
          lanes[parentLane] = parentSha;
        } else {
          // Additional merge parent gets a new (or reclaimed) lane.
          parentLane = allocateLane();
          ensureLane(parentLane);
          lanes[parentLane] = parentSha;
        }

        connections.add(GraphConnectionEntity(
          fromLane: lane,
          toLane: parentLane,
          type: parentLane < lane
              ? ConnectionType.branchLeft
              : ConnectionType.branchRight,
          colorIndex: parentLane % 10,
        ));
      }

      // Full-height verticals for lanes that were already waiting and pass
      // through this row without being this commit's own lane.
      for (final i in activeBeforeParents) {
        if (i == lane) continue;
        connections.add(GraphConnectionEntity(
          fromLane: i,
          toLane: i,
          type: ConnectionType.straight,
          colorIndex: i % 10,
        ));
      }

      layout.add(GraphCommit(
        commit: commit,
        laneIndex: lane,
        connections: connections,
        colorIndex: lane % 10,
      ));
    }

    return layout;
  }
}
