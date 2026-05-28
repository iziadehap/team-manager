// import 'package:firebase_core/firebase_core.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';

// Future<void> makeCollections() async {
//   // Initialize Firebase
//   await Firebase.initializeApp();
  
//   final firestore = FirebaseFirestore.instance;
  
//   print('📦 Starting Firestore setup...');
  
//   // 1. Create users collection
//   await firestore.collection('users').doc('_setup_temp').set({
//     '_temp': true,
//     'createdAt': FieldValue.serverTimestamp(),
//   });
//   print('✅ users collection created');
  
//   // 2. Create teams collection
//   await firestore.collection('teams').doc('_setup_temp').set({
//     '_temp': true,
//     'createdAt': FieldValue.serverTimestamp(),
//   });
//   print('✅ teams collection created');
  
//   // 3. Create tasks collection
//   await firestore.collection('tasks').doc('_setup_temp').set({
//     '_temp': true,
//     'createdAt': FieldValue.serverTimestamp(),
//   });
//   print('✅ tasks collection created');
  
//   // 4. Create notifications collection
//   await firestore.collection('notifications').doc('_setup_temp').set({
//     '_temp': true,
//     'createdAt': FieldValue.serverTimestamp(),
//   });
//   print('✅ notifications collection created');
  
//   // Wait a moment
//   await Future.delayed(const Duration(seconds: 1));
  
//   // 5. Delete all temp documents
//   await firestore.collection('users').doc('_setup_temp').delete();
//   await firestore.collection('teams').doc('_setup_temp').delete();
//   await firestore.collection('tasks').doc('_setup_temp').delete();
//   await firestore.collection('notifications').doc('_setup_temp').delete();
  
//   print('🧹 Temp data cleaned up');
//   print('✨ Firestore setup complete!');
//   print('\nYour collections are ready:');
//   print('  📁 users');
//   print('  📁 teams');
//   print('  📁 tasks');
//   print('  📁 notifications');
// }