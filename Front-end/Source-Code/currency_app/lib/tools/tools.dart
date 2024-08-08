import 'dart:core';
import 'dart:math';

/// Generates a unique transaction ID by combining the current time and a random string.
///
/// Args:
/// - None
/// Returns:
/// - String: Unique transaction ID
String generateUniqueId() {
  final random = Random();
  int min = 10000;
  int max = 99999;
  late int randomNumber;

  String randomString = "";

  // Generate a random 4-digit string
  for (int i = 0; i < 4; i++) {
    randomNumber = min + random.nextInt(max - min + 1);
    randomString += randomNumber.toString();
  }

  // Get the current time in seconds and format it as a string
  final double currentTime = DateTime.now().millisecondsSinceEpoch / 1000;
  final String currentTimeString =
      (currentTime * 10000000).toStringAsFixed(0).substring(5);

  // Combine the current time string and the random string to create a unique ID
  final String transactionId = currentTimeString + randomString;

  return transactionId;
}

/// Checks if the given string is a valid hexadecimal string.
///
/// Args:
/// - String input: Input string to be checked
/// Returns:
/// - bool: True if the input is a valid hexadecimal string, false otherwise
bool isHex(String input) {
  // Regular expression pattern for hexadecimal strings
  final RegExp hexPattern = RegExp(r'^[0-9a-fA-F]+$');
  return hexPattern.hasMatch(input);
}

/// Performs a merge sort on a list of Map entries based on their keys.
///
/// Args:
/// - List<MapEntry<String, dynamic>> list: List of Map entries to be sorted
/// Returns:
/// - List<MapEntry<String, dynamic>>: Sorted list of Map entries
List<MapEntry<String, dynamic>> mergeSort(
    List<MapEntry<String, dynamic>> list) {
  // Base case: if the list has 1 or 0 elements, it is already sorted
  if (list.length <= 1) {
    return list;
  }

  // Divide the list into two halves
  int mid = (list.length / 2).floor();
  List<MapEntry<String, dynamic>> left = list.sublist(0, mid);
  List<MapEntry<String, dynamic>> right = list.sublist(mid);

  // Recursively sort the two halves
  left = mergeSort(left);
  right = mergeSort(right);

  // Merge the sorted halves
  return merge(left, right);
}

/// Merges two sorted lists of Map entries into a single sorted list.
///
/// Args:
/// - List<MapEntry<String, dynamic>> left: First sorted list
/// - List<MapEntry<String, dynamic>> right: Second sorted list
/// Returns:
/// - List<MapEntry<String, dynamic>>: Merged and sorted list
List<MapEntry<String, dynamic>> merge(List<MapEntry<String, dynamic>> left,
    List<MapEntry<String, dynamic>> right) {
  List<MapEntry<String, dynamic>> result = [];
  int i = 0, j = 0;

  // Merge the two lists based on the key comparison
  while (i < left.length && j < right.length) {
    if (left[i].key.compareTo(right[j].key) <= 0) {
      result.add(left[i]);
      i++;
    } else {
      result.add(right[j]);
      j++;
    }
  }

  // Add remaining elements from the left list
  while (i < left.length) {
    result.add(left[i]);
    i++;
  }

  // Add remaining elements from the right list
  while (j < right.length) {
    result.add(right[j]);
    j++;
  }

  return result;
}
