class UserModel {
  final int? id;
  final String username;
  final String createdAt;

  UserModel({this.id, required this.username, required this.createdAt});

  Map<String, dynamic> toMap() {
    return {'id': id, 'username': username, 'created_at': createdAt};
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'],
      username: map['username'],
      createdAt: map['created_at'],
    );
  }
}
