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

class GraphLayoutBuilder {
  static List<GraphCommit> buildLayout(List<CommitEntity> commits) {
    if (commits.isEmpty) return [];

    final Map<String, int> activeLanes = {}; // commit SHA -> lane index
    final List<GraphCommit> layout = [];
    int nextAvailableLane = 0;

    // First pass: assign lanes to each commit topologically (top to bottom is newest to oldest)
    for (var i = 0; i < commits.length; i++) {
      final commit = commits[i];
      int lane;

      if (activeLanes.containsKey(commit.sha)) {
        lane = activeLanes[commit.sha]!;
        activeLanes.remove(commit.sha);
      } else {
        lane = nextAvailableLane;
        nextAvailableLane++;
      }

      final List<GraphConnectionEntity> connections = [];

      // Calculate connections for parents
      for (var j = 0; j < commit.parentShas.length; j++) {
        final parentSha = commit.parentShas[j];
        int parentLane;

        if (activeLanes.containsKey(parentSha)) {
          parentLane = activeLanes[parentSha]!;
          // Connection to an already active lane (merge or branch junction)
          connections.add(GraphConnectionEntity(
            fromLane: lane,
            toLane: parentLane,
            type: parentLane < lane ? ConnectionType.mergeLeft : ConnectionType.mergeRight,
            colorIndex: parentLane % 10,
          ));
        } else {
          if (j == 0) {
            // First parent continues on the current lane
            parentLane = lane;
            activeLanes[parentSha] = parentLane;
          } else {
            // Additional parents (merges) branch out to new lanes
            parentLane = nextAvailableLane;
            nextAvailableLane++;
            activeLanes[parentSha] = parentLane;

            connections.add(GraphConnectionEntity(
              fromLane: lane,
              toLane: parentLane,
              type: ConnectionType.branchRight,
              colorIndex: parentLane % 10,
            ));
          }
        }
      }

      // Also create continuous vertical lines for active lanes passing through this row
      // We check what lanes are active in the background
      activeLanes.forEach((activeSha, activeLane) {
        if (activeLane != lane) {
          connections.add(GraphConnectionEntity(
            fromLane: activeLane,
            toLane: activeLane,
            type: ConnectionType.straight,
            colorIndex: activeLane % 10,
          ));
        }
      });

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
