import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LearnMate Admin',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
      home: const AdminDashboardPage(),
    );
  }
}

class AdminUser {
  AdminUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.profile,
    required this.joinedDate,
    required this.categories,
    required this.isSocialUser,
  });

  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String profile;
  final String joinedDate;
  final List<dynamic> categories;
  final bool isSocialUser;

  factory AdminUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final fullName = data['fullName'] ??
        '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();

    return AdminUser(
      id: doc.id,
      fullName: fullName.isEmpty ? 'Unknown User' : fullName,
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      profile: data['profile'] ?? '',
      joinedDate: data['joinedDate'] ?? '',
      categories: data['categories'] ?? [],
      isSocialUser: data['isSocialUser'] ?? false,
    );
  }
}

class LeaderboardEntry {
  LeaderboardEntry({
    required this.username,
    required this.score,
  });

  final String username;
  final int score;
}

class QuizHistoryModel {
  QuizHistoryModel({
    required this.id,
    required this.type,
    required this.day,
    required this.time,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.uid,
    required this.img,
    required this.level,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String day;
  final String time;
  final int totalQuestions;
  final int correctAnswers;
  final String uid;
  final String img;
  final String level;
  final DateTime? createdAt;

  int get accuracy {
    if (totalQuestions == 0) return 0;
    return ((correctAnswers / totalQuestions) * 100).round();
  }

  factory QuizHistoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final totalQuestions = int.tryParse('${data['totalQuestions'] ?? 0}') ?? 0;
    final correctAnswers = int.tryParse(
            '${data['Correct Answers'] ?? data['correctAns'] ?? 0}') ??
        0;

    DateTime? createdAt;
    final rawCreatedAt = data['createdAt'];
    if (rawCreatedAt is Timestamp) {
      createdAt = rawCreatedAt.toDate();
    } else if (rawCreatedAt is DateTime) {
      createdAt = rawCreatedAt;
    }

    return QuizHistoryModel(
      id: doc.id,
      type: data['type'] ?? '',
      day: data['day'] ?? '',
      time: data['time'] ?? '',
      totalQuestions: totalQuestions,
      correctAnswers: correctAnswers,
      uid: data['uid'] ?? '',
      img: data['img'] ?? '',
      level: data['level'] ?? '',
      createdAt: createdAt,
    );
  }
}

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  late final Stream<QuerySnapshot> _usersStream;
  late final Stream<QuerySnapshot> _historyStream;

  @override
  void initState() {
    super.initState();
    _usersStream = FirebaseFirestore.instance.collection('users').snapshots();
    _historyStream = FirebaseFirestore.instance
        .collection('history')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _deleteUser(String userId, String name) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).delete();
      _showMessage('$name deleted');
    } catch (e) {
      _showMessage('Error deleting user: $e');
    }
  }

  void _deleteHistoryEntry(String historyId, String quizType) async {
    try {
      await FirebaseFirestore.instance.collection('history').doc(historyId).delete();
      _showMessage('Deleted history entry: $quizType');
    } catch (e) {
      _showMessage('Error deleting history item: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LearnMate Admin Panel'),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _usersStream,
        builder: (context, usersSnapshot) {
          if (!usersSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = usersSnapshot.data!.docs
              .map((doc) => AdminUser.fromFirestore(doc))
              .toList();

          return StreamBuilder<QuerySnapshot>(
            stream: _historyStream,
            builder: (context, historySnapshot) {
              if (!historySnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final historyItems = historySnapshot.data!.docs
                  .map((doc) => QuizHistoryModel.fromFirestore(doc))
                  .toList();

              final averageAccuracy = historyItems.isNotEmpty
                  ? historyItems
                          .map((item) => item.accuracy)
                          .reduce((a, b) => a + b) /
                      historyItems.length
                  : 0.0;

              final leaderboard = historyItems
                  .map((item) => LeaderboardEntry(
                        username: item.type.isNotEmpty ? item.type : item.uid,
                        score: item.accuracy,
                      ))
                  .toList()
                ..sort((a, b) => b.score.compareTo(a.score));

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _StatCard(
                          label: 'Total Users',
                          value: users.length.toString(),
                          icon: Icons.people,
                        ),
                        _StatCard(
                          label: 'Quiz Attempts',
                          value: historyItems.length.toString(),
                          icon: Icons.help_center,
                        ),
                        _StatCard(
                          label: 'Avg Accuracy',
                          value: '${averageAccuracy.toStringAsFixed(1)}%',
                          icon: Icons.show_chart,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Current Users',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Card(
                      color: Colors.white,
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: users.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final user = users[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.green.shade100,
                              child: Icon(Icons.person, color: Colors.green.shade700),
                            ),
                            title: Text(user.fullName),
                            subtitle: Text('${user.email} • ${user.joinedDate}'),
                            trailing: IconButton(
                              tooltip: 'Delete user',
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _deleteUser(user.id, user.fullName),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Quiz Leaderboard',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Card(
                      color: Colors.white,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Rank')),
                          DataColumn(label: Text('Quiz')),
                          DataColumn(label: Text('Accuracy')),
                        ],
                        rows: List.generate(
                          min(leaderboard.length, 5),
                          (index) {
                            final entry = leaderboard[index];
                            return DataRow(
                              cells: [
                                DataCell(Text('#${index + 1}')),
                                DataCell(Text(entry.username)),
                                DataCell(Text('${entry.score}%')),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Recent Quiz History',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Card(
                      color: Colors.white,
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: historyItems.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = historyItems[index];
                          return ListTile(
                            title: Text(item.type.isNotEmpty ? item.type : 'Quiz'),
                            subtitle: Text(
                              '${item.level} • ${item.correctAnswers}/${item.totalQuestions} correct • ${item.day} ${item.time}',
                            ),
                            trailing: Wrap(
                              spacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text('${item.accuracy}%'),
                                IconButton(
                                  tooltip: 'Delete history item',
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () => _deleteHistoryEntry(item.id, item.type),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 200),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.green.shade700),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.green.shade900,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: Colors.green.shade800,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

