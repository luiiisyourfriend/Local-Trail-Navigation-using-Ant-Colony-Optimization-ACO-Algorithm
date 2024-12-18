import 'dart:math';

import 'package:latlong2/latlong.dart';

class ACOAlgorithm {
  List<LatLng> nodes; // List of nodes
  late List<List<double>> distanceMatrix; // Use late for delayed initialization
  late List<List<double>> pheromoneMatrix; // Same for pheromoneMatrix
  int maxIterations = 50; // Number of iterations
  double pheromoneEvaporationRate = 0.2;
  int numberOfAnts = 10;
  double alpha = 1.0; // Pheromone weight
  double beta = 2.0; // Distance weight

  ACOAlgorithm({required this.nodes}) {
    pheromoneMatrix = List.generate(nodes.length, (_) => List.filled(nodes.length, 1.0));
    distanceMatrix = _generateDistanceMatrix(nodes);
  }

  // Generate distance matrix
  List<List<double>> _generateDistanceMatrix(List<LatLng> nodes) {
    List<List<double>> matrix = [];
    for (int i = 0; i < nodes.length; i++) {
      List<double> row = [];
      for (int j = 0; j < nodes.length; j++) {
        row.add(i == j ? 0.0 : _calculateDistance(nodes[i], nodes[j]));
      }
      matrix.add(row);
    }
    return matrix;
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    return const Distance().as(LengthUnit.Meter, point1, point2); // Using latlong2 Distance() class
  }

  // Run the ACO algorithm and return the best path
  List<LatLng> findPathUsingAllNodes() {
    List<Ant> ants = [];
    List<LatLng> bestPath = [];
    double bestDistance = double.infinity;

    for (int iteration = 0; iteration < maxIterations; iteration++) {
      ants = List.generate(numberOfAnts, (_) => Ant(startNode: nodes[0], nodes: nodes));
      for (var ant in ants) {
        ant.explore(distanceMatrix, pheromoneMatrix, alpha, beta);
        // For now, we'll just consider the path created by the ants even if it's not optimal
        if (ant.totalDistance < bestDistance) {
          bestDistance = ant.totalDistance;
          bestPath = List.from(ant.path);
        }
      }
      _updatePheromones(ants);
    }
    return bestPath; // Path that uses all nodes
  }

  // Update pheromone levels based on ants' paths
  void _updatePheromones(List<Ant> ants) {
    for (int i = 0; i < pheromoneMatrix.length; i++) {
      for (int j = 0; j < pheromoneMatrix[i].length; j++) {
        pheromoneMatrix[i][j] *= (1 - pheromoneEvaporationRate);
      }
    }
    for (var ant in ants) {
      for (int i = 0; i < ant.path.length - 1; i++) {
        int from = nodes.indexOf(ant.path[i]);
        int to = nodes.indexOf(ant.path[i + 1]);
        pheromoneMatrix[from][to] += 1.0 / ant.totalDistance;
        pheromoneMatrix[to][from] += 1.0 / ant.totalDistance;
      }
    }
  }

  List<LatLng> findShortestPath(List<LatLng> checkpoints) {
  // Return the list of checkpoints as the path for now
  return checkpoints;
}

}

class Ant {
  LatLng startNode;
  List<LatLng> nodes;
  List<LatLng> path = [];
  double totalDistance = 0.0;

  Ant({required this.startNode, required this.nodes}) {
    path.add(startNode);
  }

  void explore(List<List<double>> distanceMatrix, List<List<double>> pheromoneMatrix,
      double alpha, double beta) {
    Set<int> visited = {};
    int current = 0; // Start at node 0
    visited.add(current);

    while (visited.length < nodes.length) {
      int nextNode = _selectNextNode(current, visited, distanceMatrix, pheromoneMatrix, alpha, beta);
      path.add(nodes[nextNode]);
      totalDistance += distanceMatrix[current][nextNode];
      visited.add(nextNode);
      current = nextNode;
    }
    // The path now visits all nodes, but doesn't need to return to start
    totalDistance += distanceMatrix[current][0]; // Optional if you want to loop back to start
  }

  int _selectNextNode(int current, Set<int> visited, List<List<double>> distanceMatrix,
      List<List<double>> pheromoneMatrix, double alpha, double beta) {
    List<double> probabilities = [];
    for (int i = 0; i < nodes.length; i++) {
      if (visited.contains(i)) {
        probabilities.add(0.0);
      } else {
        double pheromone = pheromoneMatrix[current][i];
        double distance = distanceMatrix[current][i];
        probabilities.add((pheromone * alpha) / (distance * beta));
      }
    }

    double sum = probabilities.reduce((a, b) => a + b);
    double randomValue = sum * (Random().nextDouble());
    double cumulative = 0.0;
    for (int i = 0; i < probabilities.length; i++) {
      cumulative += probabilities[i];
      if (randomValue <= cumulative) {
        return i;
      }
    }
    return 0; // Fallback (should not happen)
  }
}
