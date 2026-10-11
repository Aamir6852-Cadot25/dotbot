import 'dart:math';

/// Offline, LLM-free practice problems (Java + DSA).
class Challenge {
  const Challenge(this.topic, this.prompt, this.answerHint);
  final String topic;
  final String prompt;
  final String answerHint;
}

const challenges = <Challenge>[
  Challenge('arrays', 'Given int[] a, return the second largest distinct value without sorting.', 'Track max and second max in one pass.'),
  Challenge('arrays', 'Reverse an int[] in place. What is the time and space complexity?', 'Two pointers swapping from both ends.'),
  Challenge('strings', 'Check whether two Strings are anagrams in O(n).', 'Count characters in an int[26] or a HashMap.'),
  Challenge('strings', 'Find the first non-repeating character of a String.', 'Two passes: count, then scan.'),
  Challenge('hashing', 'Two Sum: indices of two numbers adding to target in O(n).', 'Store value->index in a HashMap while scanning.'),
  Challenge('linked-list', 'Detect a cycle in a singly linked list using O(1) extra space.', "Floyd's slow/fast pointers."),
  Challenge('linked-list', 'Reverse a singly linked list iteratively.', 'Keep prev, curr, next pointers.'),
  Challenge('recursion', 'Write fib(n) recursively, then explain why it is slow and fix it.', 'Memoize or iterate.'),
  Challenge('trees', 'Compute the height of a binary tree.', '1 + max(height(left), height(right)); null is 0.'),
  Challenge('trees', 'In-order traversal of a BST yields what order? Why?', 'Sorted ascending: left, node, right.'),
  Challenge('sorting', 'Explain how merge sort works and why it is O(n log n).', 'Halve log n times; merge is O(n) per level.'),
  Challenge('binary-search', 'Binary search a sorted array. What bug appears with (lo+hi)/2?', 'Overflow; use lo + (hi-lo)/2.'),
  Challenge('stack', 'Validate balanced brackets in a String.', 'Push openers, pop and match on closers.'),
  Challenge('dp', 'Climbing stairs with 1 or 2 steps: count ways to reach step n.', 'dp[i] = dp[i-1] + dp[i-2].'),
  Challenge('oop-java', 'Explain overriding vs overloading in Java with one example each.', 'Runtime vs compile-time polymorphism.'),
  Challenge('collections-java', 'ArrayList vs LinkedList: when would you pick each?', 'Random access vs frequent middle inserts.'),
];

/// Prefer [weakTopics]; fall back to any challenge.
Challenge pickChallenge({List<String> weakTopics = const [], Random? rng}) {
  final r = rng ?? Random();
  final pool = challenges.where((c) => weakTopics.contains(c.topic)).toList();
  final src = pool.isEmpty ? challenges : pool;
  return src[r.nextInt(src.length)];
}
