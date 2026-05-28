class FirestorePaths {
  static const users = 'users';
  static const teams = 'teams';
  static const inviteCodes = 'inviteCodes';
  static const tasks = 'tasks';
  static const comments = 'comments';

  static String user(String userId) => '$users/$userId';
  static String team(String teamId) => '$teams/$teamId';
  static String inviteCode(String code) => '$inviteCodes/$code';
  static String teamTasks(String teamId) => '$teams/$teamId/$tasks';
  static String teamTask(String teamId, String taskId) =>
      '$teams/$teamId/$tasks/$taskId';
  static String taskComments(String teamId, String taskId) =>
      '$teams/$teamId/$tasks/$taskId/$comments';
}
