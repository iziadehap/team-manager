import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';

class UserService {
  final FirebaseFirestore _firestore;

  UserService({FirebaseFirestore? firestore}) 
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<AppUser> getUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      
      if (!doc.exists) {
        // Return a fallback user with required fields
        return AppUser(
          id: userId,
          name: userId.split('@').first, // Use email prefix as name
          email: userId,
          createdAt: DateTime.now(),
          teamIds: [],
        );
      }
      
      return AppUser.fromFirestore(doc);
    } catch (e) {
      print('Error fetching user $userId: $e');
      // Return a fallback user with required fields
      return AppUser(
        id: userId,
        name: userId.split('@').first,
        email: userId,
        createdAt: DateTime.now(),
        teamIds: [],
      );
    }
  }
}